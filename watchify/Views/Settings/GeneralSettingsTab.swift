//
//  GeneralSettingsTab.swift
//  watchify
//

import SwiftUI

struct GeneralSettingsTab: View {
    @AppStorage("syncIntervalMinutes") private var syncInterval = 30
    @State private var useCustom = false

    private let presets = [15, 30, 60, 120, 240, 480]

    var body: some View {
        Form {
            Section {
                Picker("Check for changes", selection: Binding(
                    get: { useCustom ? -1 : syncInterval },
                    set: { newValue in
                        if newValue == -1 {
                            useCustom = true
                        } else {
                            useCustom = false
                            syncInterval = newValue
                        }
                    }
                )) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("2 hours").tag(120)
                    Text("4 hours").tag(240)
                    Text("8 hours").tag(480)
                    Divider()
                    Text("Custom...").tag(-1)
                }

                if useCustom {
                    HStack {
                        Text("Custom interval")
                        Spacer()
                        TextField("", value: $syncInterval, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: $syncInterval, in: 5...1440, step: 5)
                            .labelsHidden()
                        Text("minutes")
                    }
                }
            } footer: {
                if useCustom {
                    Text("Valid range: 5-1440 minutes")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            useCustom = !presets.contains(syncInterval)
        }
    }
}

#Preview("Preset") {
    GeneralSettingsTab()
}

#Preview("Custom") {
    struct CustomPreview: View {
        @AppStorage("syncIntervalMinutes") var interval = 45
        var body: some View {
            GeneralSettingsTab()
        }
    }
    return CustomPreview()
}
