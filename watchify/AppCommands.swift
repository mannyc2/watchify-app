//
//  AppCommands.swift
//  watchify
//

import SwiftUI

// MARK: - Focused Value Keys

extension FocusedValues {
    @Entry var storeId: UUID?
    @Entry var sidebarSelection: Binding<SidebarSelection?>?
    @Entry var showAddStore: Binding<Bool>?
    @Entry var storeList: [StoreDTO]?
}

// MARK: - App Commands

struct AppCommands: Commands {
    @FocusedValue(\.storeId) var storeId
    @FocusedValue(\.sidebarSelection) var selection
    @FocusedValue(\.showAddStore) var showAddStore
    @FocusedValue(\.storeList) var storeList

    var body: some Commands {
        // Standard sidebar toggle (⌘⌥S)
        SidebarCommands()

        // Standard toolbar commands
        ToolbarCommands()

        // File menu: Add Store (⌘N) - replaces default New Window
        CommandGroup(replacing: .newItem) {
            Button("Add Store...") {
                showAddStore?.wrappedValue = true
            }
            .keyboardShortcut("n", modifiers: .command)
            // Note: Don't disable based on showAddStore == nil
            // FocusedValues can briefly become nil during menu interaction,
            // and the action safely uses optional chaining anyway.
        }

        // File menu: Sync commands
        CommandGroup(after: .saveItem) {
            Button("Sync All Stores") {
                Task.detached {
                    await syncAllStoresWithErrorTracking()
                }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Sync Current Store") {
                guard let id = storeId else { return }
                Task.detached {
                    try? await StoreService.shared.syncStore(storeId: id)
                }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(storeId == nil)
        }

        // Replace default Help menu (removes "Help isn't available" message)
        CommandGroup(replacing: .help) {
            Link("Shopify Products API", destination: URL(string: "https://shopify.dev/docs/api/storefront")!)
        }

        // View menu: Navigation shortcuts
        CommandMenu("Navigate") {
            Button("Overview") {
                selection?.wrappedValue = .overview
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(selection == nil)

            Button("Activity") {
                selection?.wrappedValue = .activity
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(selection == nil)

            Divider()

            // Dynamic store navigation (⌘3-9)
            ForEach(Array((storeList ?? []).prefix(7).enumerated()), id: \.element.id) { index, store in
                Button(store.name) {
                    selection?.wrappedValue = .store(store.id)
                }
                .keyboardShortcut(KeyEquivalent(Character("\(index + 3)")), modifiers: .command)
                .disabled(selection == nil)
            }
        }
    }
}
