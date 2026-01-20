//
//  SettingsView.swift
//  watchify
//

import SwiftUI

enum SettingsTab: Int {
    case general
    case notifications
    case data
}

struct SettingsView: View {
    @AppStorage("selectedSettingsTab") private var selectedTab = SettingsTab.general.rawValue

    var body: some View {
        TabView(selection: Binding(
            get: { SettingsTab(rawValue: selectedTab) ?? .general },
            set: { selectedTab = $0.rawValue }
        )) {
            Tab("General", systemImage: "gear", value: .general) {
                GeneralSettingsTab()
            }
            Tab("Notifications", systemImage: "bell", value: .notifications) {
                NotificationSettingsTab()
            }
            Tab("Data", systemImage: "externaldrive", value: .data) {
                DataSettingsTab()
            }
        }
        .scenePadding()
        .frame(maxWidth: 450, minHeight: 250)
    }
}

#Preview {
    SettingsView()
}
