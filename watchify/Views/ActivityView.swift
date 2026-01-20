//
//  ActivityView.swift
//  watchify
//

import SwiftData
import SwiftUI

struct ActivityView: View {
    @Query(sort: \ChangeEvent.occurredAt, order: .reverse)
    private var changeEvents: [ChangeEvent]

    var body: some View {
        List(changeEvents) { event in
            ActivityRow(event: event)
        }
        .listStyle(.plain)
        .navigationTitle("Activity")
        .overlay {
            if changeEvents.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "clock.badge.exclamationmark",
                    description: Text("Changes to products will appear here")
                )
            }
        }
    }
}

#Preview {
    NavigationStack {
        ActivityView()
    }
    .modelContainer(for: ChangeEvent.self, inMemory: true)
}
