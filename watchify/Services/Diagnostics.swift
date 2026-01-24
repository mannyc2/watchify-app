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
