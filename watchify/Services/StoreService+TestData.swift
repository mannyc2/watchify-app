//
//  StoreService+TestData.swift
//  watchify
//
//  Test data seeding for UI tests.
//

import Foundation
import SwiftData

// MARK: - Test Data Seeding

extension StoreService {

    /// Seeds test data based on launch arguments.
    /// Call this when `-UITesting` is present to check for seed scenarios.
    func seedTestDataIfNeeded() {
        let args = ProcessInfo.processInfo.arguments

        if args.contains("-SeedMultipleStores") {
            seedMultipleStores()
        } else if args.contains("-SeedPriceHistory") {
            seedPriceHistory()
        } else if args.contains("-SeedManyEvents") {
            seedManyEvents()
        } else if args.contains("-SeedEmptyStore") {
            seedEmptyStore()
        } else if args.contains("-SeedTestData") {
            seedTestData()
        }
    }

    /// Seeds mock data for UI testing. Only call when using in-memory store.
    /// Creates: 1 store, 5 products, 1 change event
    func seedTestData() {
        let store = Store(name: "Test Store", domain: "test-store.myshopify.com")
        modelContext.insert(store)

        // Add some products with variants
        for idx in 1...5 {
            let product = Product(
                shopifyId: Int64(idx),
                handle: "test-product-\(idx)",
                title: "Test Product \(idx)"
            )
            product.store = store
            modelContext.insert(product)

            let variant = Variant(
                shopifyId: Int64(idx * 100),
                title: "Default",
                price: Decimal(19.99 + Double(idx)),
                available: idx % 2 == 0,
                position: idx
            )
            variant.product = product
            modelContext.insert(variant)
        }

        // Add a change event so Activity has something to show
        let event = ChangeEvent(
            changeType: .priceDropped,
            productTitle: "Test Product 1",
            variantTitle: "Default",
            oldValue: "$29.99",
            newValue: "$19.99",
            store: store
        )
        modelContext.insert(event)

        try? modelContext.save()
    }

    /// Seeds multiple stores with varied product counts.
    /// Creates: 3 stores (Allbirds: 8 products, Gymshark: 5 products, MVMT: 3 products)
    private func seedMultipleStores() {
        let names = ["Allbirds", "Gymshark", "MVMT Watches"]
        let domains = ["allbirds.myshopify.com", "gymshark.myshopify.com", "mvmt.myshopify.com"]
        let productCounts = [8, 5, 3]

        var productId: Int64 = 1
        for idx in 0..<names.count {
            let name = names[idx]
            let domain = domains[idx]
            let productCount = productCounts[idx]
            let store = Store(name: name, domain: domain)
            modelContext.insert(store)

            for productIdx in 1...productCount {
                let product = Product(
                    shopifyId: productId,
                    handle: "\(name.lowercased())-product-\(productIdx)",
                    title: "\(name) Product \(productIdx)"
                )
                product.store = store
                modelContext.insert(product)

                let variant = Variant(
                    shopifyId: productId * 100,
                    title: "Default",
                    price: Decimal(29.99 + Double(productIdx * 10)),
                    available: productIdx % 3 != 0,  // 2/3 in stock
                    position: productIdx
                )
                variant.product = product
                modelContext.insert(variant)

                productId += 1
            }

            // Add an event for each store
            let event = ChangeEvent(
                changeType: idx == 0 ? .priceDropped : (idx == 1 ? .backInStock : .newProduct),
                productTitle: "\(name) Product 1",
                variantTitle: "Default",
                oldValue: idx == 2 ? nil : "$49.99",
                newValue: "$39.99",
                store: store
            )
            modelContext.insert(event)
        }

        try? modelContext.save()
    }

    /// Seeds a store with products that have price history (variant snapshots).
    /// Creates: 1 store, 3 products with 5 historical snapshots each
    private func seedPriceHistory() {
        let store = Store(name: "Price History Store", domain: "price-history.myshopify.com")
        modelContext.insert(store)

        for productIdx in 1...3 {
            let product = Product(
                shopifyId: Int64(productIdx),
                handle: "price-tracked-\(productIdx)",
                title: "Price Tracked Product \(productIdx)"
            )
            product.store = store
            modelContext.insert(product)

            let currentPrice = Decimal(49.99)
            let variant = Variant(
                shopifyId: Int64(productIdx * 100),
                title: "Default",
                price: currentPrice,
                available: true,
                position: 1
            )
            variant.product = product
            modelContext.insert(variant)

            // Add historical snapshots (price went from high to low over time)
            let basePrice = 79.99
            for snapshotIdx in 0..<5 {
                let daysAgo = (5 - snapshotIdx) * 7  // Weekly snapshots going back 5 weeks
                let priceReduction = Double(snapshotIdx) * 5.0
                let snapshotPrice = Decimal(basePrice - priceReduction)

                let snapshot = VariantSnapshot(
                    price: snapshotPrice,
                    compareAtPrice: Decimal(99.99),
                    available: true
                )
                snapshot.variant = variant
                snapshot.capturedAt = Calendar.current.date(
                    byAdding: .day,
                    value: -daysAgo,
                    to: Date()
                ) ?? Date()
                modelContext.insert(snapshot)
            }
        }

        try? modelContext.save()
    }

    /// Seeds a store with many change events for testing Activity view pagination.
    /// Creates: 1 store, 5 products, 25 change events
    private func seedManyEvents() {
        let store = Store(name: "Event Heavy Store", domain: "events.myshopify.com")
        modelContext.insert(store)

        // Add products
        for idx in 1...5 {
            let product = Product(
                shopifyId: Int64(idx),
                handle: "event-product-\(idx)",
                title: "Event Product \(idx)"
            )
            product.store = store
            modelContext.insert(product)

            let variant = Variant(
                shopifyId: Int64(idx * 100),
                title: "Default",
                price: Decimal(29.99),
                available: true,
                position: 1
            )
            variant.product = product
            modelContext.insert(variant)
        }

        // Add many events with varied types and times
        let eventTypes: [ChangeType] = [
            .priceDropped, .priceIncreased, .backInStock, .outOfStock, .newProduct
        ]
        for eventIdx in 1...25 {
            let productNum = ((eventIdx - 1) % 5) + 1
            let eventType = eventTypes[(eventIdx - 1) % eventTypes.count]
            let hoursAgo = eventIdx * 2  // Events spread over ~2 days

            let event = ChangeEvent(
                changeType: eventType,
                productTitle: "Event Product \(productNum)",
                variantTitle: "Default",
                oldValue: eventType == .newProduct ? nil : "$\(39.99 + Double(eventIdx))",
                newValue: "$\(29.99 + Double(eventIdx))",
                store: store
            )
            event.occurredAt = Calendar.current.date(
                byAdding: .hour,
                value: -hoursAgo,
                to: Date()
            ) ?? Date()
            modelContext.insert(event)
        }

        try? modelContext.save()
    }

    /// Seeds a store with no products (empty state testing).
    /// Creates: 1 store with 0 products
    private func seedEmptyStore() {
        let store = Store(name: "Empty Store", domain: "empty.myshopify.com")
        modelContext.insert(store)
        try? modelContext.save()
    }
}
