//
//  NotificationSettingsTab.swift
//  watchify
//

import SwiftUI

struct NotificationSettingsTab: View {
    @AppStorage("notificationsEnabled") private var enabled = true
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
                Toggle("Enable notifications", isOn: $enabled)
                    .accessibilityHint("Enable or disable all notifications")
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
            .disabled(!enabled)

            Section {
                Button("Open System Notification Settings") {
                    openNotificationSettings()
                }
                .accessibilityHint("Opens macOS System Settings")
            }
        }
        .formStyle(.grouped)
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
