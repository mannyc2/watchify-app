//
//  watchifyApp.swift
//  watchify
//
//  Created by cjpher on 1/19/26.
//

import SwiftData
import SwiftUI

@main
struct WatchifyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Store.self, Product.self, Variant.self, VariantSnapshot.self, ChangeEvent.self])
    }
}
