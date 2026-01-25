//
//  GeneralSettingsTab.swift
//  watchify
//

import SwiftUI

struct GeneralSettingsTab: View {
    @AppStorage("syncIntervalMinutes") private var syncInterval = 30
    @AppStorage("activityGroupDisplayMode") private var groupDisplayMode: EventGroupDisplayMode = .collapsible
    @AppStorage("activityGroupingWindowMinutes") private var groupingWindowMinutes = 5
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
                .accessibilityHint("Select how often to check for changes")

                if useCustom {
                    HStack {
                        Text("Custom interval")
                        Spacer()
                        TextField("", value: $syncInterval, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Custom interval in minutes")
                        Stepper("", value: $syncInterval, in: 5...1440, step: 5)
                            .labelsHidden()
                            .accessibilityLabel("Adjust interval")
                            .accessibilityValue("\(syncInterval) minutes")
                        Text("minutes")
                    }
                    .accessibilityElement(children: .combine)
                }
            } footer: {
                if useCustom {
                    Text("Valid range: 5-1440 minutes")
                }
            }

            Section {
                Picker("Group display", selection: $groupDisplayMode) {
                    ForEach(EventGroupDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .accessibilityHint("Choose how grouped events are displayed")

                Stepper(
                    "Group within \(groupingWindowMinutes) min",
                    value: $groupingWindowMinutes,
                    in: 1...60
                )
                .accessibilityLabel("Grouping time window")
                .accessibilityValue("\(groupingWindowMinutes) minutes")
                .accessibilityHint("Events within this time window are grouped together")
            } header: {
                Text("Activity Feed")
            } footer: {
                Text("Events for the same product within the time window are grouped together.")
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
