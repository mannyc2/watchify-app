//
//  ContentView.swift
//  watchify
//
//  Created by cjpher on 1/19/26.
//

import OSLog
import SwiftData
import SwiftUI

struct ContentView: View {
    let container: ModelContainer

    @State private var viewModel = StoreListViewModel()
    @State private var showingAddStore = false
    @State private var selection: SidebarSelection? = .overview

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel,
                selection: $selection,
                onAddStore: { showingAddStore = true }
            )
        } detail: {
            switch selection {
            case .overview:
                OverviewView(
                    viewModel: viewModel,
                    selection: $selection,
                    onAddStore: { showingAddStore = true }
                )
            case .activity:
                ActivityView()
            case .store(let id):
                if let storeDTO = viewModel.store(byId: id) {
                    // swiftlint:disable:next redundant_discardable_let
                    let _ = Log.nav.debug("Store lookup hit id=\(id)")
                    NavigationStack {
                        StoreDetailView(storeDTO: storeDTO, container: container)
                    }
                    .id(id)
                } else {
                    // swiftlint:disable:next redundant_discardable_let
                    let _ = Log.nav.warning("Store lookup miss id=\(id)")
                    ContentUnavailableView(
                        "Store Not Found",
                        systemImage: "storefront",
                        description: Text("The selected store could not be found")
                    )
                }
            case nil:
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.left",
                    description: Text("Select an item from the sidebar")
                )
            }
        }
        .task { viewModel.configure() }
        .sheet(isPresented: $showingAddStore) {
            AddStoreSheet(selection: $selection)
        }
        .focusedSceneValue(\.sidebarSelection, $selection)
        .focusedSceneValue(\.showAddStore, $showingAddStore)
        .focusedSceneValue(\.storeList, viewModel.stores)
        .frame(
            minWidth: WatchifyApp.isScreenshotMode ? 1280 : nil,
            maxWidth: WatchifyApp.isScreenshotMode ? 1280 : .infinity,
            minHeight: WatchifyApp.isScreenshotMode ? 800 : nil,
            maxHeight: WatchifyApp.isScreenshotMode ? 800 : .infinity
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Watchify main window")
    }
}

#Preview {
    let container = makePreviewContainer()
    return ContentView(container: container)
}
