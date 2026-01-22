//
//  Diagnostics.swift
//  watchify
//
//  Unified logging + signposts for performance debugging.
//  Produces both Instruments-visible intervals AND AI-readable text logs.
//
//  Usage:
//    Log.db.span("fetchProducts", meta: "storeId=\(id)") { ... }
//
//  AI access:
//    log stream --predicate 'subsystem == "cjpher.watchify"' --level debug > /tmp/app.log
//    # Or export .trace to XML: xctrace export --input file.trace --output file.xml
//
//  For SwiftData SQL debugging (separate):
//    defaults write cjpher.watchify com.apple.CoreData.SQLDebug 3
//    ~/bin/xcede buildrun 2>&1 | tee /tmp/perf.log
//    ./scripts/analyze-perf.sh /tmp/perf.log
//

import Foundation
import OSLog
import SwiftData

// MARK: - Thread Info

/// Thread diagnostic info for logging. Captures thread state at call time.
struct ThreadInfo: CustomStringConvertible, Sendable {
    let isMain: Bool
    let number: Int
    let queueLabel: String

    nonisolated static var current: ThreadInfo {
        let label = String(validatingUTF8: __dispatch_queue_get_label(nil)) ?? "unknown"
        // Extract thread number from description like "<NSThread: 0x123>{number = 5, name = }"
        let desc = Thread.current.description
        let number: Int
        if let range = desc.range(of: "number = "),
           let endRange = desc[range.upperBound...].firstIndex(of: ",") {
            number = Int(desc[range.upperBound..<endRange]) ?? -1
        } else {
            number = -1
        }
        return ThreadInfo(isMain: Thread.isMainThread, number: number, queueLabel: label)
    }

    nonisolated var description: String {
        "isMain=\(isMain ? 1 : 0) thread=\(number) queue=\(queueLabel)"
    }
}

// MARK: - Loggers

/// Categorized loggers for unified logging (Console.app, `log stream`).
/// Logger is Sendable so these can be used from any actor.
enum Log: Sendable {
    static nonisolated let subsystem = Bundle.main.bundleIdentifier ?? "cjpher.watchify"

    static nonisolated let nav = Logger(subsystem: subsystem, category: "nav")
    // swiftlint:disable:next identifier_name
    static nonisolated let db = Logger(subsystem: subsystem, category: "db")
    static nonisolated let sync = Logger(subsystem: subsystem, category: "sync")
    // swiftlint:disable:next identifier_name
    static nonisolated let ui = Logger(subsystem: subsystem, category: "ui")
    static nonisolated let perf = Logger(subsystem: subsystem, category: "perf")
}

// MARK: - Trace (Signposts + Text Logs)

/// Unified tracing: emits both Instruments signpost intervals AND text log lines.
///
/// NOTE: Signposts are ONLY used in synchronous spans. Async spans use text logging only
/// because OSSignpostIntervalState cannot safely cross await suspension points (causes crashes).
enum Trace: Sendable {
    static nonisolated let subsystem = Bundle.main.bundleIdentifier ?? "cjpher.watchify"
    static nonisolated let signposter = OSSignposter(subsystem: subsystem, category: "PointsOfInterest")

    /// Set to false to disable signposts entirely (useful if still crashing).
    /// Text logging (SPAN_BEGIN/END) will still work.
    nonisolated(unsafe) static var signpostsEnabled = true

    /// Emit a span visible in Instruments + AI-readable BEGIN/END log lines.
    /// Signposts only work in sync spans - async uses text logging only.
    @discardableResult
    nonisolated static func span<T>(
        _ logger: Logger,
        _ name: StaticString,
        meta: @autoclosure () -> String = "",
        _ body: () throws -> T
    ) rethrows -> T {
        let spanId = UInt64.random(in: 0...UInt64.max)
        let metaStr = meta()
        let start = CFAbsoluteTimeGetCurrent()

        logger.debug("SPAN_BEGIN \(name, privacy: .public) id=\(spanId) \(metaStr, privacy: .public)")

        // Signposts are safe in sync context (no suspension points)
        let state: OSSignpostIntervalState?
        if signpostsEnabled {
            let signpostId = signposter.makeSignpostID()
            state = signposter.beginInterval(name, id: signpostId)
        } else {
            state = nil
        }

        defer {
            if let state, signpostsEnabled {
                signposter.endInterval(name, state)
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logger.debug("SPAN_END \(name, privacy: .public) id=\(spanId) dt=\(elapsed, format: .fixed(precision: 4))s")
        }

        return try body()
    }

    /// Async version of span - TEXT LOGGING ONLY, no signposts.
    /// OSSignpostIntervalState cannot safely cross await suspension points.
    @discardableResult
    nonisolated static func span<T>(
        _ logger: Logger,
        _ name: StaticString,
        meta: @autoclosure () -> String = "",
        _ body: () async throws -> T
    ) async rethrows -> T {
        let spanId = UInt64.random(in: 0...UInt64.max)
        let metaStr = meta()
        let start = CFAbsoluteTimeGetCurrent()

        logger.debug("SPAN_BEGIN \(name, privacy: .public) id=\(spanId) \(metaStr, privacy: .public)")

        // NO signposts in async - they crash when state crosses suspension points
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            logger.debug("SPAN_END \(name, privacy: .public) id=\(spanId) dt=\(elapsed, format: .fixed(precision: 4))s")
        }

        return try await body()
    }
}

// MARK: - Logger Extension

extension Logger {
    /// Convenience: `Log.db.span("name") { ... }` instead of `Trace.span(Log.db, "name") { ... }`
    @discardableResult
    nonisolated func span<T>(
        _ name: StaticString,
        meta: @autoclosure () -> String = "",
        _ body: () throws -> T
    ) rethrows -> T {
        try Trace.span(self, name, meta: meta(), body)
    }

    @discardableResult
    nonisolated func span<T>(
        _ name: StaticString,
        meta: @autoclosure () -> String = "",
        _ body: () async throws -> T
    ) async rethrows -> T {
        try await Trace.span(self, name, meta: meta(), body)
    }
}

// MARK: - SwiftData Telemetry

extension ModelContext {
    /// Fetch with signpost span + structured log line.
    func fetchLogged<T: PersistentModel>(
        _ descriptor: FetchDescriptor<T>,
        label: StaticString,
        file: String = #fileID,
        line: UInt = #line
    ) throws -> [T] {
        try Log.db.span(label, meta: "@\(file):\(line)") {
            let start = CFAbsoluteTimeGetCurrent()
            let results = try fetch(descriptor)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            // swiftlint:disable:next line_length
            Log.db.info("DB_FETCH \(label, privacy: .public) count=\(results.count) dt=\(elapsed, format: .fixed(precision: 4))s @\(file, privacy: .public):\(line)")
            return results
        }
    }

    /// Save with signpost span + structured log line.
    func saveLogged(
        label: StaticString,
        file: String = #fileID,
        line: UInt = #line
    ) throws {
        try Log.db.span(label, meta: "@\(file):\(line)") {
            let start = CFAbsoluteTimeGetCurrent()
            try save()
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            // swiftlint:disable:next line_length
            Log.db.info("DB_SAVE \(label, privacy: .public) dt=\(elapsed, format: .fixed(precision: 4))s @\(file, privacy: .public):\(line)")
        }
    }

    /// Log current context state for debugging.
    nonisolated func logState(_ label: StaticString, file: String = #fileID, line: UInt = #line) {
        let hasChanges = hasChanges
        let inserted = insertedModelsArray.count
        let changed = changedModelsArray.count
        let deleted = deletedModelsArray.count
        // swiftlint:disable:next line_length
        Log.db.debug("CTX_STATE \(label, privacy: .public) hasChanges=\(hasChanges) ins=\(inserted) chg=\(changed) del=\(deleted) @\(file, privacy: .public):\(line)")
    }
}

// MARK: - Actor Operation Signposts

/// Separate signposter for actor operations (distinct from general PointsOfInterest).
enum ActorTrace: Sendable {
    nonisolated static let signposter = OSSignposter(subsystem: Log.subsystem, category: "ActorOps")

    /// Wraps a ModelContext operation with signpost + logging.
    /// Use for fetch/save operations to see them in Instruments.
    @discardableResult
    nonisolated static func contextOp<T>(
        _ name: StaticString,
        context: ModelContext,
        _ body: () throws -> T
    ) rethrows -> T {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: id)
        let start = CFAbsoluteTimeGetCurrent()

        defer {
            signposter.endInterval(name, state)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            Log.db.debug("CTX_OP \(name, privacy: .public) dt=\(elapsed, format: .fixed(precision: 4))s")
        }

        _ = context // keep context in signature for call-site clarity
        return try body()
    }
}

// MARK: - Main Thread Heartbeat Monitor

/// Monitors main thread responsiveness using GCD timer.
/// Logs warnings when main thread doesn't respond within threshold.
final class MainThreadMonitor: @unchecked Sendable {
    static let shared = MainThreadMonitor()

    private var source: DispatchSourceTimer?
    private var lastBeat: CFAbsoluteTime = 0
    private let threshold: CFAbsoluteTime = 0.1  // 100ms threshold
    private let lock = NSLock()

    private init() {}

    /// Start monitoring. Logs warning if main thread doesn't respond within threshold.
    func start() {
        lock.lock()
        defer { lock.unlock() }

        guard source == nil else { return }
        lastBeat = CFAbsoluteTimeGetCurrent()
        Log.perf.info("MainThreadMonitor START")

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let now = CFAbsoluteTimeGetCurrent()

            self.lock.lock()
            let gap = now - self.lastBeat
            self.lastBeat = now
            self.lock.unlock()

            if gap > self.threshold {
                Log.perf.warning("MAIN_THREAD_BLOCKED gap=\(gap, format: .fixed(precision: 3))s")
            }
        }
        timer.resume()
        source = timer
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }

        source?.cancel()
        source = nil
        Log.perf.info("MainThreadMonitor STOP")
    }
}

// MARK: - ModelContext Change Observer

/// Observes ModelContext save notifications and logs insert/update/delete counts.
@MainActor
final class DBChangeObserver {
    static let shared = DBChangeObserver()
    private var observer: NSObjectProtocol?

    private init() {}

    func startObserving(context: ModelContext) {
        guard observer == nil else { return }

        observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: context,
            queue: .main
        ) { note in
            let start = CFAbsoluteTimeGetCurrent()
            let info = note.userInfo ?? [:]
            let inserted = (info["inserted"] as? Set<AnyHashable>)?.count ?? 0
            let updated = (info["updated"] as? Set<AnyHashable>)?.count ?? 0
            let deleted = (info["deleted"] as? Set<AnyHashable>)?.count ?? 0

            let observerElapsed = CFAbsoluteTimeGetCurrent() - start
            // swiftlint:disable:next line_length
            Log.db.info("DB_SAVE_MAIN ins=\(inserted) upd=\(updated) del=\(deleted) t=\(observerElapsed, format: .fixed(precision: 4))s")
        }
    }

    func stopObserving() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }
}
