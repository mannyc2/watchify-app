//
//  AppTips.swift
//  watchify
//

import TipKit

// MARK: - Add Store Tip

/// Shown on first launch to guide users to add their first store.
struct AddStoreTip: Tip {
    var title: Text {
        Text("Add a Shopify Store")
    }

    var message: Text? {
        Text("Enter any Shopify store URL to start tracking prices and stock.")
    }

    var image: Image? {
        Image(systemName: "storefront.fill")
    }

    // Only show if user hasn't added a store yet
    @Parameter
    static var hasAddedStore: Bool = false

    var rules: [Rule] {
        [
            #Rule(Self.$hasAddedStore) { $0 == false }
        ]
    }
}

// MARK: - Sync Tip

/// Shown after adding first store to explain manual sync.
struct SyncTip: Tip {
    var title: Text {
        Text("Sync Products")
    }

    var message: Text? {
        Text("Tap to fetch the latest products. Watchify also syncs automatically in the background.")
    }

    var image: Image? {
        Image(systemName: "arrow.trianglehead.2.clockwise")
    }

    // Show after first store is added
    @Parameter
    static var hasAddedStore: Bool = false

    // Only show once
    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }

    var rules: [Rule] {
        [
            #Rule(Self.$hasAddedStore) { $0 == true }
        ]
    }
}

// MARK: - Activity Tip

/// Shown when viewing activity to explain what appears there.
struct ActivityTip: Tip {
    var title: Text {
        Text("Track Changes")
    }

    var message: Text? {
        Text("Price drops, restocks, and new products appear here as Watchify syncs your stores.")
    }

    var image: Image? {
        Image(systemName: "clock.arrow.circlepath")
    }

    // Only show once per user
    var options: [any TipOption] {
        [MaxDisplayCount(1)]
    }
}
