//
//  NotificationSettingsTab.swift
//  watchify
//

import SwiftUI
import UserNotifications

struct NotificationSettingsTab: View {
    @AppStorage("notificationsEnabled") private var enabled = true
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @AppStorage("notifyPriceDropped") private var priceDropped = true
    @AppStorage("notifyPriceIncreased") private var priceIncreased = true
    @AppStorage("notifyBackInStock") private var backInStock = true
    @AppStorage("notifyOutOfStock") private var outOfStock = true
    @AppStorage("notifyNewProduct") private var newProduct = true
    @AppStorage("notifyProductRemoved") private var productRemoved = true
    @AppStorage("notifyImagesChanged") private var imagesChanged = false
    @AppStorage("priceDropThreshold") private var priceDropThreshold = PriceThreshold.any.rawValue
    @AppStorage("priceIncreaseThreshold") private var priceIncreaseThreshold = PriceThreshold.any.rawValue

    var body: some View {
        Form {
            Section {
                HStack {
                    authorizationStatusIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authorizationStatusTitle)
                        if let hint = authorizationStatusHint {
                            Text(hint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(authorizationStatusAccessibilityLabel)
            }

            Section {
                Toggle("Enable notifications", isOn: $enabled)
                    .accessibilityHint("Enable or disable all notifications")
                    .disabled(authorizationStatus == .denied)
            }

            Section("Notify me about") {
                Toggle("Price drops", isOn: $priceDropped)
                    .accessibilityHint("Notify when a product's price decreases")
                if priceDropped {
                    Picker("Minimum drop", selection: $priceDropThreshold) {
                        ForEach(PriceThreshold.allCases, id: \.rawValue) { threshold in
                            Text(threshold.rawValue).tag(threshold.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 20)
                    .accessibilityLabel("Minimum price drop threshold")
                }

                Toggle("Price increases", isOn: $priceIncreased)
                    .accessibilityHint("Notify when a product's price increases")
                if priceIncreased {
                    Picker("Minimum increase", selection: $priceIncreaseThreshold) {
                        ForEach(PriceThreshold.allCases, id: \.rawValue) { threshold in
                            Text(threshold.rawValue).tag(threshold.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 20)
                    .accessibilityLabel("Minimum price increase threshold")
                }

                Toggle("Back in stock", isOn: $backInStock)
                    .accessibilityHint("Notify when a product becomes available")
                Toggle("Out of stock", isOn: $outOfStock)
                    .accessibilityHint("Notify when a product sells out")
                Toggle("New products", isOn: $newProduct)
                    .accessibilityHint("Notify when a store adds new products")
                Toggle("Removed products", isOn: $productRemoved)
                    .accessibilityHint("Notify when a store removes products")
                Toggle("Image changes", isOn: $imagesChanged)
                    .accessibilityHint("Notify when product images are updated")
            }
            .disabled(!enabled || authorizationStatus == .denied)

            Section {
                Button("Open System Notification Settings") {
                    openNotificationSettings()
                }
                .accessibilityHint("Opens macOS System Settings")
            }
        }
        .formStyle(.grouped)
        .task {
            await checkAuthorizationStatus()
        }
        .onChange(of: enabled) { _, newValue in
            if newValue && authorizationStatus == .notDetermined {
                Task {
                    _ = await NotificationService.shared.requestPermission()
                    await checkAuthorizationStatus()
                }
            }
        }
    }

    // MARK: - Authorization Status UI

    private var authorizationStatusIcon: some View {
        Group {
            switch authorizationStatus {
            case .authorized:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            case .notDetermined:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
            default:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .imageScale(.large)
        .accessibilityHidden(true)
    }

    private var authorizationStatusTitle: String {
        switch authorizationStatus {
        case .authorized:
            return "System notifications enabled"
        case .denied:
            return "System notifications blocked"
        case .notDetermined:
            return "Permission not yet requested"
        default:
            return "Unknown status"
        }
    }

    private var authorizationStatusHint: String? {
        switch authorizationStatus {
        case .denied:
            return "Enable in System Settings to receive notifications"
        default:
            return nil
        }
    }

    private var authorizationStatusAccessibilityLabel: String {
        var label = authorizationStatusTitle
        if let hint = authorizationStatusHint {
            label += ". \(hint)"
        }
        return label
    }

    // MARK: - Helpers

    private func checkAuthorizationStatus() async {
        authorizationStatus = await NotificationService.shared.authorizationStatus()
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    NotificationSettingsTab()
}
