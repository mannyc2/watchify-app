//
//  ErrorBannerView.swift
//  watchify
//
//  Inline error banner for displaying sync errors.
//

import Accessibility
import SwiftUI

struct ErrorBannerView: View {
    let error: SyncError
    let lastSyncedAt: Date?
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: error.iconName)
                .font(.title2)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                if let title = error.errorDescription {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                }

                if let reason = error.failureReason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastSync = lastSyncedAt {
                    Text("Last synced \(lastSync, format: .relative(presentation: .named))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button("Try Again") { onRetry() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isStaticText)
    }

    private var accessibilityLabel: String {
        var parts: [String] = []

        if let title = error.errorDescription {
            parts.append(title)
        }
        if let reason = error.failureReason {
            parts.append(reason)
        }
        if let suggestion = error.recoverySuggestion {
            parts.append(suggestion)
        }

        return parts.joined(separator: ". ")
    }
}

// MARK: - Compact Variant

struct CompactErrorBannerView: View {
    let message: String
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let dismiss = onDismiss {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Previews

#Preview("Network Unavailable") {
    ErrorBannerView(
        error: .networkUnavailable,
        lastSyncedAt: Date().addingTimeInterval(-3600),
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}

#Preview("Server Error") {
    ErrorBannerView(
        error: .serverError(statusCode: 503),
        lastSyncedAt: Date().addingTimeInterval(-1800),
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}

#Preview("Network Timeout") {
    ErrorBannerView(
        error: .networkTimeout,
        lastSyncedAt: nil,
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}

#Preview("Invalid Response") {
    ErrorBannerView(
        error: .invalidResponse,
        lastSyncedAt: Date().addingTimeInterval(-7200),
        onRetry: {},
        onDismiss: {}
    )
    .padding()
}

#Preview("Compact Banner") {
    CompactErrorBannerView(
        message: "2 stores failed to sync",
        onDismiss: {}
    )
    .padding()
}
