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

        if args.contains("-SeedScreenshots") {
            seedScreenshots()
        } else if args.contains("-SeedMultipleStores") {
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

    // MARK: - Screenshot Seed Data

    /// Seeds rich realistic data for programmatic screenshot capture.
    /// Creates 3 stores with named products, price history, and ~15 change events.
    private func seedScreenshots() {
        var ids = SeedIds()

        let allbirds = seedScreenshotStore(
            name: "Allbirds", domain: "allbirds.myshopify.com",
            products: SeedProduct.allbirds, ids: &ids
        )
        seedWoolRunnerPriceHistory(store: allbirds)

        let gymshark = seedScreenshotStore(
            name: "Gymshark", domain: "gymshark.myshopify.com",
            products: SeedProduct.gymshark, ids: &ids
        )

        let mvmt = seedScreenshotStore(
            name: "MVMT Watches", domain: "mvmt.myshopify.com",
            products: SeedProduct.mvmt, ids: &ids
        )

        seedScreenshotEvents(allbirds: allbirds, gymshark: gymshark, mvmt: mvmt)
        try? modelContext.save()
    }

    private func seedScreenshotStore(
        name: String, domain: String,
        products: [SeedProduct], ids: inout SeedIds
    ) -> Store {
        let store = Store(name: name, domain: domain)
        modelContext.insert(store)

        for spec in products {
            let product = Product(
                shopifyId: ids.nextProduct(),
                handle: spec.handle,
                title: spec.title,
                vendor: spec.vendor,
                productType: spec.productType
            )
            product.store = store
            product.cachedPrice = spec.price
            product.cachedIsAvailable = spec.available
            product.imageURLs = spec.imageURLs
            modelContext.insert(product)

            for (vIdx, vName) in spec.variants.enumerated() {
                let variant = Variant(
                    shopifyId: ids.nextVariant(),
                    title: vName,
                    price: spec.price,
                    available: spec.available || vIdx == 0,
                    position: vIdx + 1
                )
                variant.product = product
                modelContext.insert(variant)
            }
        }

        store.cachedProductCount = products.count
        store.cachedPreviewImageURLs = products.prefix(3).compactMap { $0.imageURLs.first }
        return store
    }

    private func seedWoolRunnerPriceHistory(store: Store) {
        guard let product = store.products.first(where: { $0.handle == "wool-runner" }),
              let variant = product.variants.first else { return }

        let prices: [Decimal] = [110, 108, 105, 100, 98, 95, 92, 89]
        for (idx, snapshotPrice) in prices.enumerated() {
            let weeksAgo = prices.count - idx
            let snapshot = VariantSnapshot(
                price: snapshotPrice, compareAtPrice: 120, available: true
            )
            snapshot.variant = variant
            snapshot.capturedAt = Calendar.current.date(
                byAdding: .day, value: -weeksAgo * 7, to: Date()
            ) ?? Date()
            modelContext.insert(snapshot)
        }
    }

    private func seedScreenshotEvents(allbirds: Store, gymshark: Store, mvmt: Store) {
        let events: [SeedEvent] = [
            SeedEvent(.priceDropped, "Wool Runner", "Men's 9", "$110.00", "$89.00", allbirds, 2, true, 1),
            SeedEvent(.priceDropped, "Tree Dasher 2", "Men's 10", "$145.00", "$135.00", allbirds, 6, true, 2),
            SeedEvent(.newProduct, "SuperLight Sneaker", nil, nil, "$110.00", allbirds, 12, false, 6),
            SeedEvent(.outOfStock, "Tree Lounger", "Men's 10", nil, nil, allbirds, 18, true, 4),
            SeedEvent(.backInStock, "Wool Pipers", "Women's 8", nil, nil, allbirds, 30, false, 3),
            SeedEvent(.priceDropped, "Vital Seamless Leggings", "XS", "$60.00", "$52.00", gymshark, 4, false, 7),
            SeedEvent(.backInStock, "Power Shorts", "L", nil, nil, gymshark, 10, true, 9),
            SeedEvent(.outOfStock, "Training Hoodie", "M", nil, nil, gymshark, 20, false, 10),
            SeedEvent(.priceIncreased, "Apex T-Shirt", "M", "$34.00", "$38.00", gymshark, 36, true, 8),
            SeedEvent(.newProduct, "Power Shorts", nil, nil, "$32.00", gymshark, 48, true, 9),
            SeedEvent(.priceDropped, "Classic 40mm", "Black/Silver", "$150.00", "$138.00", mvmt, 8, false, 11),
            SeedEvent(.newProduct, "Voyager Chrono", nil, nil, "$175.00", mvmt, 24, false, 13),
            SeedEvent(.backInStock, "Boulevard 38mm", "Ivory", nil, nil, mvmt, 40, true, 12),
            SeedEvent(.priceDropped, "Boulevard 38mm", "Slate", "$170.00", "$158.00", mvmt, 54, true, 12),
            SeedEvent(.outOfStock, "Classic 40mm", "White/Rose Gold", nil, nil, mvmt, 60, true, 11)
        ]

        for seed in events {
            let event = ChangeEvent(
                changeType: seed.type,
                productTitle: seed.product,
                variantTitle: seed.variant,
                oldValue: seed.oldVal,
                newValue: seed.newVal,
                productShopifyId: seed.prodId,
                store: seed.store
            )
            event.occurredAt = Calendar.current.date(
                byAdding: .hour, value: -seed.hoursAgo, to: Date()
            ) ?? Date()
            event.isRead = seed.isRead
            modelContext.insert(event)
        }
    }
}

// MARK: - Screenshot Seed Helpers

private struct SeedIds {
    private var productId: Int64 = 1
    private var variantId: Int64 = 100

    mutating func nextProduct() -> Int64 {
        defer { productId += 1 }
        return productId
    }

    mutating func nextVariant() -> Int64 {
        defer { variantId += 1 }
        return variantId
    }
}

private struct SeedProduct {
    let title: String
    let handle: String
    let price: Decimal
    let available: Bool
    let vendor: String
    let productType: String
    let variants: [String]
    let imageURLs: [String]

    // swiftlint:disable line_length

    // Allbirds — real Shopify CDN images from allbirds.com
    private static let allbirdsBase = "https://cdn.shopify.com/s/files/1/1104/4168/files"
    static let allbirds = [
        SeedProduct(title: "Wool Runner", handle: "wool-runner", price: 89, available: true, vendor: "Allbirds", productType: "Shoes", variants: ["Men's 9", "Men's 10", "Women's 7"],
                    imageURLs: ["\(allbirdsBase)/A12097_25Q4_Wool-Runner-NZ-Luxe-Gold-Stony-Cream-Sole_PDP_LEFT_5a352806-ebc6-4cae-b339-4e71d6d2cec6.png?v=1761692343"]),
        SeedProduct(title: "Tree Dasher 2", handle: "tree-dasher-2", price: 135, available: true, vendor: "Allbirds", productType: "Shoes", variants: ["Men's 10", "Men's 11"],
                    imageURLs: ["\(allbirdsBase)/A12329_26Q1_Strider-Warm-Red-Mushroom_PDP_LEFT.png?v=1765238799"]),
        SeedProduct(title: "Wool Pipers", handle: "wool-pipers", price: 95, available: true, vendor: "Allbirds", productType: "Shoes", variants: ["Men's 9", "Women's 8"],
                    imageURLs: ["\(allbirdsBase)/A12153_25Q4_Kiwi-Slipper-Medium-Grey-Dark-Grey-Sole_PDP_LEFT.png?v=1761687927"]),
        SeedProduct(title: "Tree Lounger", handle: "tree-lounger", price: 98, available: false, vendor: "Allbirds", productType: "Shoes", variants: ["Men's 10"],
                    imageURLs: ["\(allbirdsBase)/A12618_26Q1_Lounger-Lift-Mushroom-Mushroom-Sole_PDP_LEFT.png?v=1766430291"]),
        SeedProduct(title: "Wool Runner Mizzle", handle: "wool-runner-mizzle", price: 115, available: true, vendor: "Allbirds", productType: "Shoes", variants: ["Men's 9", "Men's 10"],
                    imageURLs: ["\(allbirdsBase)/A12142_25Q4_Kiwi-Slipper-Dark-Camel-Stony-Cream-Sole_PDP_LEFT.png?v=1761687976"]),
        SeedProduct(title: "SuperLight Sneaker", handle: "superlight-sneaker", price: 110, available: true, vendor: "Allbirds", productType: "Shoes", variants: ["Women's 7", "Women's 8"],
                    imageURLs: ["\(allbirdsBase)/A12485_26Q1_Tree-Runner-NZ-Burnt-Olive-Burnt-Olive-Sole_PDP_LEFT_9487ac29-5786-4fd4-8b61-1f9430bdd42b.png?v=1765834155"])
    ]

    // Gymshark — Outdoor Voices CDN (real activewear images, Gymshark blocks their API)
    private static let ovBase = "https://cdn.shopify.com/s/files/1/0190/1390/files"
    static let gymshark = [
        SeedProduct(title: "Vital Seamless Leggings", handle: "vital-seamless-leggings", price: 52, available: true, vendor: "Gymshark", productType: "Apparel", variants: ["XS", "S", "M"],
                    imageURLs: ["\(ovBase)/W101500-TSW-DRC_TechSweatCore7-8Legging_Dewberry-Chocolate_000.jpg?v=1759256280"]),
        SeedProduct(title: "Apex T-Shirt", handle: "apex-tshirt", price: 38, available: true, vendor: "Gymshark", productType: "Apparel", variants: ["S", "M", "L"],
                    imageURLs: ["\(ovBase)/W301577-TDN-SAL_DesertShirt_Salt_000.jpg?v=1757707243"]),
        SeedProduct(title: "Power Shorts", handle: "power-shorts", price: 32, available: true, vendor: "Gymshark", productType: "Apparel", variants: ["M", "L"],
                    imageURLs: ["\(ovBase)/W702390-WTS-JCF_LightSpeedMinimal3inSkort_JuicyFruit_001162780009.jpg?v=1767739872"]),
        SeedProduct(title: "Training Hoodie", handle: "training-hoodie", price: 65, available: false, vendor: "Gymshark", productType: "Apparel", variants: ["M", "L", "XL"],
                    imageURLs: ["\(ovBase)/W702044-TDN-SAL_DesertPant_Salt_000.jpg?v=1757707245"])
    ]

    // MVMT Watches — Daniel Wellington CDN (real watch images, MVMT blocks their API)
    private static let dwBase = "https://cdn.shopify.com/s/files/1/0689/3826/8979/files"
    static let mvmt = [
        SeedProduct(title: "Classic 40mm", handle: "classic-40mm", price: 138, available: true, vendor: "MVMT", productType: "Watches", variants: ["Black/Silver", "White/Rose Gold"],
                    imageURLs: ["\(dwBase)/txyh8yoebbztgyzm28bj.png?v=1768312509"]),
        SeedProduct(title: "Boulevard 38mm", handle: "boulevard-38mm", price: 158, available: true, vendor: "MVMT", productType: "Watches", variants: ["Slate", "Ivory"],
                    imageURLs: ["\(dwBase)/uw1huurpiovz7ofqlklk.png?v=1768312510"]),
        SeedProduct(title: "Voyager Chrono", handle: "voyager-chrono", price: 175, available: true, vendor: "MVMT", productType: "Watches", variants: ["Steel", "Gunmetal"],
                    imageURLs: ["\(dwBase)/vlazzva6tcpxjhfr6xnl.png?v=1768312507"])
    ]

    // swiftlint:enable line_length
}

private struct SeedEvent {
    let type: ChangeType
    let product: String
    let variant: String?
    let oldVal: String?
    let newVal: String?
    let store: Store
    let hoursAgo: Int
    let isRead: Bool
    let prodId: Int64?

    init(
        _ type: ChangeType, _ product: String, _ variant: String?,
        _ oldVal: String?, _ newVal: String?, _ store: Store,
        _ hoursAgo: Int, _ isRead: Bool, _ prodId: Int64?
    ) {
        self.type = type
        self.product = product
        self.variant = variant
        self.oldVal = oldVal
        self.newVal = newVal
        self.store = store
        self.hoursAgo = hoursAgo
        self.isRead = isRead
        self.prodId = prodId
    }
}
