//
//  SyncStatusView.swift
//  watchify
//

import AppKit
import SwiftUI

struct SyncStatusView: View {
    let retryAfter: TimeInterval
    let onRetry: () -> Void
    let onDismiss: () -> Void

    enum Status: Equatable {
        case waiting(seconds: Int)
        case ready
    }

    @State private var status: Status = .waiting(seconds: 0)
    @State private var timer: Timer?

    private var isReady: Bool {
        if case .ready = status { return true }
        return false
    }

    private var remainingSeconds: Int {
        if case .waiting(let seconds) = status { return seconds }
        return 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isReady ? "checkmark.circle" : "clock")
                .foregroundStyle(isReady ? .green : .secondary)
                .contentTransition(.symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 2) {
                Text(isReady ? "Ready to sync" : "Sync limited")
                    .font(.subheadline.weight(.medium))
                Text(isReady ? "You can sync now." : "Wait \(remainingSeconds)s before syncing again")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .animation(.default, value: isReady)

            Spacer()

            Button("Retry") { onRetry() }
                .disabled(!isReady)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { startCountdown() }
        .onDisappear { timer?.invalidate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isReady
                ? "Ready to sync. You can sync now."
                : "Sync limited. Wait \(remainingSeconds) seconds."
        )
    }

    private func startCountdown() {
        let seconds = Int(retryAfter.rounded(.up))
        status = .waiting(seconds: seconds)

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard case .waiting(let current) = status else {
                timer?.invalidate()
                return
            }

            if current > 1 {
                status = .waiting(seconds: current - 1)
            } else {
                status = .ready
                timer?.invalidate()
                announceReadyForAccessibility()
                scheduleAutoDismiss()
            }
        }
    }

    private func announceReadyForAccessibility() {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: "You can sync now.",
                .priority: NSAccessibilityPriorityLevel.high.rawValue
            ]
        )
    }

    private func scheduleAutoDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            if case .ready = status {
                withAnimation { onDismiss() }
            }
        }
    }
}

#Preview {
    SyncStatusView(
        retryAfter: 5,
        onRetry: { print("Retry tapped") },
        onDismiss: { print("Dismiss tapped") }
    )
    .padding()
}
