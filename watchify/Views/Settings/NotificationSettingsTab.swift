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
            }

            Section("Notify me about") {
                Toggle("Price drops", isOn: $priceDropped)
                if priceDropped {
                    Picker("Minimum drop", selection: $priceDropThreshold) {
                        ForEach(PriceThreshold.allCases, id: \.rawValue) { threshold in
                            Text(threshold.rawValue).tag(threshold.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 20)
                }

                Toggle("Price increases", isOn: $priceIncreased)
                if priceIncreased {
                    Picker("Minimum increase", selection: $priceIncreaseThreshold) {
                        ForEach(PriceThreshold.allCases, id: \.rawValue) { threshold in
                            Text(threshold.rawValue).tag(threshold.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.leading, 20)
                }

                Toggle("Back in stock", isOn: $backInStock)
                Toggle("Out of stock", isOn: $outOfStock)
                Toggle("New products", isOn: $newProduct)
                Toggle("Removed products", isOn: $productRemoved)
                Toggle("Image changes", isOn: $imagesChanged)
            }
            .disabled(!enabled)

            Section {
                Button("Open System Notification Settings") {
                    openNotificationSettings()
                }
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
