# Data Model

SwiftData schema for Watchify.

## Entity Relationship

```
SwiftData Models (persisted):

Store (1) ──── (*) Product (1) ──── (*) Variant (1) ──── (*) VariantSnapshot
  │
  └── (*) ChangeEvent

DTOs (in-memory, for actor boundary crossing):

StoreDTO ←── Store
ProductDTO ←── Product
ChangeEventDTO ←── ChangeEvent
```

## Models

### Store

Root entity. Represents a Shopify store being monitored.

```swift
@Model
final class Store {
    @Attribute(.unique) var id: UUID
    var name: String
    var domain: String              // e.g. "shop.example.com"
    var addedAt: Date
    var lastFetchedAt: Date?
    var isSyncing: Bool = false     // True during active sync

    @Relationship(deleteRule: .cascade, inverse: \Product.store)
    var products: [Product] = []

    @Relationship(deleteRule: .cascade, inverse: \ChangeEvent.store)
    var changeEvents: [ChangeEvent] = []

    // Denormalized fields (N+1 prevention in list views)
    var cachedProductCount: Int = 0
    var cachedPreviewImageURLs: [String] = []

    func updateListingCache(products: [Product])
}
```

### Product

Canonical product record. Tracks `isRemoved` for products that disappear from feed.

```swift
@Model
final class Product {
    // Compound indexes for common query patterns
    #Index<Product>(
        [\.store], [\.store, \.isRemoved],
        [\.store, \.cachedIsAvailable], [\.store, \.cachedPrice],
        [\.store, \.titleSearchKey]
    )

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
    var variants: [Variant] = []

    // Denormalized listing fields (N+1 prevention)
    var cachedPrice: Decimal = 0
    var cachedIsAvailable: Bool = false
    var titleSearchKey: String = ""   // Lowercase/normalized for search

    // Convenience
    var primaryImageURL: URL?
    var allImageURLs: [URL]
    var currentPrice: Decimal
    var isAvailable: Bool
    var recentPriceChange: Decimal?   // nil if no change

    func updateListingCache()
    func updateListingCache(from variantDTOs: [ShopifyVariant])
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

var recentPriceChange: Decimal? {
    guard let variant = variants.first,
          let snapshot = variant.mostRecentSnapshot else { return nil }
    let change = variant.price - snapshot.price
    return change != 0 ? change : nil
}
```

Note: List views use `cachedPrice` and `cachedIsAvailable` instead of these computed properties to avoid N+1 relationship faults.

## Snapshot Retention

Default: 90 days. Cleanup runs during sync:

```swift
func cleanupOldSnapshots(context: ModelContext) {
    let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
    // Delete VariantSnapshot older than cutoff
}
```

---

## DTOs (Data Transfer Objects)

Lightweight `Sendable` structs for crossing actor boundaries. Views receive DTOs from `StoreService` instead of `@Model` objects to avoid observation overhead and actor isolation issues.

### ProductDTO

```swift
struct ProductDTO: Identifiable, Sendable {
    let id: UUID
    let shopifyId: Int64
    let title: String
    let handle: String
    let vendor: String?
    let productType: String?
    let imageURLs: [String]
    let isRemoved: Bool

    // Cached listing info
    let minPrice: Decimal
    let maxPrice: Decimal
    let isAvailable: Bool
    let variantCount: Int

    var primaryImageURL: URL?
}
```

### StoreDTO

```swift
struct StoreDTO: Identifiable, Sendable {
    let id: UUID
    let name: String
    let domain: String
    let lastFetchedAt: Date?
    let isSyncing: Bool

    // From cached fields
    let cachedProductCount: Int
    let cachedPreviewImageURLs: [String]
}
```

### ChangeEventDTO

```swift
struct ChangeEventDTO: Identifiable, Sendable {
    let id: UUID
    let occurredAt: Date
    let changeType: ChangeType
    let productTitle: String
    let variantTitle: String?
    let oldValue: String?
    let newValue: String?
    let priceChange: Decimal?
    let isRead: Bool
    let magnitude: ChangeMagnitude

    // Store info (denormalized)
    let storeId: UUID?
    let storeName: String?
}
```

### Why DTOs?

1. **Sendable**: Can safely cross actor boundaries (MainActor ↔ StoreService actor)
2. **No observation**: Unlike `@Model` objects, DTOs don't trigger SwiftData observation when accessed
3. **Immutable**: Structs are value types, preventing accidental mutation
4. **Denormalized**: Include related data (e.g., `storeName`) to avoid relationship traversal
