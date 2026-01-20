# Data Model

SwiftData schema for Watchify.

## Entity Relationship

```
Store (1) ──── (*) Product (1) ──── (*) Variant (1) ──── (*) VariantSnapshot
  │
  └── (*) ChangeEvent
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
    var firstSeenAt: Date
    var lastSeenAt: Date
    var isRemoved: Bool
    var imageURLs: [String] = []  // Ordered array of CDN URLs

    var store: Store?

    @Relationship(deleteRule: .cascade, inverse: \Variant.product)
    var variants: [Variant]

    // Convenience
    var primaryImageURL: URL? {
        imageURLs.first.flatMap { URL(string: $0) }
    }

    var allImageURLs: [URL] {
        imageURLs.compactMap { URL(string: $0) }
    }
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

### VariantSnapshot

Point-in-time captures for price/availability history tracking.

```swift
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
    var priceChange: Decimal?      // For price changes: the delta amount
    var isRead: Bool               // Tracks if user has seen this event (default: false)
    var magnitude: ChangeMagnitude // small/medium/large for notification priority
    var store: Store?
}
```

| Property | Description |
|----------|-------------|
| `isRead` | `false` when created, set to `true` when event row appears in ActivityView |
| `priceChange` | Dollar amount of change (negative for drops), used by `PriceChangeIndicator` |
| `magnitude` | Determines notification priority: small (<10%), medium (10-25%), large (>25%) |

enum ChangeType: String, Codable {
    case priceDropped
    case priceIncreased
    case backInStock
    case outOfStock
    case newProduct
    case productRemoved
    case imagesChanged
}

extension ChangeType {
    var icon: String {
        switch self {
        case .priceDropped, .priceIncreased: "tag.fill"
        case .backInStock, .outOfStock: "shippingbox.fill"
        case .newProduct: "bag.badge.plus"
        case .productRemoved: "bag.badge.minus"
        case .imagesChanged: "photo.on.rectangle"
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
        case .imagesChanged: .blue
        }
    }
}

enum ChangeMagnitude: String, Codable {
    case small    // < 10%
    case medium   // 10-25%
    case large    // > 25%
}
```

### PriceThreshold

User setting for minimum price change notifications. Not a SwiftData model, but used with `@AppStorage`.

```swift
enum PriceThreshold: String, CaseIterable, Codable {
    case any = "Any amount"
    case dollars5 = "At least $5"
    case dollars10 = "At least $10"
    case dollars25 = "At least $25"
    case percent10 = "At least 10%"
    case percent25 = "At least 25%"

    var minDollars: Decimal?  // For absolute thresholds
    var minPercent: Int?      // For percentage thresholds

    func isSatisfied(by change: ChangeEvent) -> Bool
}
```

| Threshold | Check Logic |
|-----------|-------------|
| `any` | Always passes |
| `dollars5/10/25` | `abs(priceChange) >= threshold` |
| `percent10/25` | Uses `magnitude` enum as proxy (small <10%, medium 10-25%, large >25%) |

**Storage keys**: `priceDropThreshold`, `priceIncreaseThreshold` (separate thresholds for drops vs increases)

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
    // Delete VariantSnapshot older than cutoff
}
```
