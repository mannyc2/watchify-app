# Data Model

SwiftData schema for Watchify.

## Entity Relationship

```
Store (1) ──── (*) Product (1) ──── (*) Variant
  │                  │                    │
  │                  │                    │
  └── (*) ChangeEvent    ProductSnapshot     VariantSnapshot
```

## Models

### Store

Root entity. Represents a Shopify store being monitored.

```swift
@Model
class Store {
    @Attribute(.unique) var id: UUID
    var name: String
    var domain: String              // e.g. "shop.example.com"
    var addedAt: Date
    var lastFetchedAt: Date?
    var fetchIntervalMinutes: Int   // default 60
    
    @Relationship(deleteRule: .cascade, inverse: \Product.store)
    var products: [Product]
    
    @Relationship(deleteRule: .cascade, inverse: \ChangeEvent.store)
    var changeEvents: [ChangeEvent]
}
```

### Product

Canonical product record. Tracks `isRemoved` for products that disappear from feed.

```swift
@Model
class Product {
    @Attribute(.unique) var shopifyId: Int64
    var handle: String
    var title: String
    var vendor: String?
    var productType: String?
    var createdAt: Date?
    var firstSeenAt: Date
    var lastSeenAt: Date
    var isRemoved: Bool
    var imageURL: URL?
    
    var store: Store?
    
    @Relationship(deleteRule: .cascade, inverse: \Variant.product)
    var variants: [Variant]
    
    @Relationship(deleteRule: .cascade, inverse: \ProductSnapshot.product)
    var snapshots: [ProductSnapshot]
}
```

### Variant

Product variant (size, color, etc.). This is where price and availability live.

```swift
@Model
class Variant {
    @Attribute(.unique) var shopifyId: Int64
    var title: String               // e.g. "Small / Red"
    var sku: String?
    var price: Decimal
    var compareAtPrice: Decimal?
    var available: Bool
    var position: Int

    var product: Product?

    @Relationship(deleteRule: .cascade, inverse: \VariantSnapshot.variant)
    var snapshots: [VariantSnapshot]

    // Convenience: snapshots sorted oldest to newest
    var priceHistory: [VariantSnapshot] {
        snapshots.sorted { $0.capturedAt < $1.capturedAt }
    }

    // Convenience: most recent snapshot (if any)
    var mostRecentSnapshot: VariantSnapshot? {
        snapshots.max { $0.capturedAt < $1.capturedAt }
    }
}
```

### Snapshots

Point-in-time captures for history tracking.

```swift
@Model
class ProductSnapshot {
    var capturedAt: Date
    var title: String
    var vendor: String?
    var productType: String?
    var product: Product?
}

@Model
class VariantSnapshot {
    var capturedAt: Date
    var price: Decimal
    var compareAtPrice: Decimal?
    var available: Bool
    var variant: Variant?
}
```

### ChangeEvent

Detected changes for activity feed and notifications.

```swift
@Model
class ChangeEvent {
    var id: UUID
    var occurredAt: Date
    var changeType: ChangeType
    var productTitle: String
    var variantTitle: String?
    var oldValue: String?
    var newValue: String?
    var isRead: Bool
    var magnitude: ChangeMagnitude
    var store: Store?
}

enum ChangeType: String, Codable {
    case priceDropped
    case priceIncreased
    case backInStock
    case outOfStock
    case newProduct
    case productRemoved
}

extension ChangeType {
    var icon: String {
        switch self {
        case .priceDropped, .priceIncreased: "tag.fill"
        case .backInStock, .outOfStock: "shippingbox.fill"
        case .newProduct: "bag.badge.plus"
        case .productRemoved: "bag.badge.minus"
        }
    }

    var color: Color {
        switch self {
        case .priceDropped: .green
        case .priceIncreased: .red
        case .backInStock: .blue
        case .outOfStock: .orange
        case .newProduct: .purple
        case .productRemoved: .secondary
        }
    }
}

enum ChangeMagnitude: String, Codable {
    case small    // < 10%
    case medium   // 10-25%
    case large    // > 25%
}
```

## Computed Properties

On `Product`:

```swift
var currentPrice: Decimal {
    variants.first?.price ?? 0
}

var isAvailable: Bool {
    variants.contains { $0.available }
}

// TODO: Cache this - currently sorts on every access
var recentPriceChange: PriceChange? {
    guard let latest = variants.first,
          let previous = latest.snapshots
              .sorted(by: { $0.capturedAt > $1.capturedAt })
              .dropFirst().first else {
        return nil
    }
    let change = latest.price - previous.price
    guard change != 0 else { return nil }
    return PriceChange(
        amount: change,
        percentage: (change / previous.price) * 100
    )
}
```

## Snapshot Retention

Default: 90 days. Cleanup runs during sync:

```swift
func cleanupOldSnapshots(context: ModelContext) {
    let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
    // Delete ProductSnapshot and VariantSnapshot older than cutoff
}
```
