# Services

Three services handle the core logic.

## StoreService (@MainActor, @Observable)

Handles store creation, product persistence, change detection, and syncing. Works with SwiftData ModelContext.

```swift
@MainActor
@Observable
final class StoreService {
    // Dependency injection for testability
    init(api: ShopifyAPIProtocol? = nil)

    // Add new store: validates domain, creates store, fetches and saves products
    // Name is optional - derives from domain if nil/empty (e.g., "allbirds.com" → "allbirds")
    // Uses isInitialImport=true so no ChangeEvents are created for initial products
    func addStore(name: String?, domain: String, context: ModelContext) async throws -> Store

    // Sync existing store: fetch from API + save to SwiftData
    // Detects and persists ChangeEvents for price/stock changes
    func syncStore(_ store: Store, context: ModelContext) async throws
}
```

### Dependency Injection

`StoreService` accepts an optional `ShopifyAPIProtocol` for testing:

```swift
// Production (uses real API)
let service = StoreService()

// Testing (uses mock)
let mockAPI = MockShopifyAPI()
let service = StoreService(api: mockAPI)
```

### Method Usage

| Method | Caller | Purpose |
|--------|--------|---------|
| `addStore()` | AddStoreSheet | Create store + fetch/save products in one operation |
| `syncStore()` | StoreDetailView sync button | Manual refresh for existing store |

### Add Store Flow

```
AddStoreSheet
  └── StoreService.addStore(name, domain, context)
      ├── ShopifyAPI.fetchProducts() → validates store, returns products
      ├── Derives name from domain if not provided
      ├── Creates Store, inserts into context
      ├── saveProducts(isInitialImport: true) → no ChangeEvents
      └── Returns store
```

### Manual Sync Flow

```
StoreDetailView sync button
  └── StoreService.syncStore(store, context)
      ├── ShopifyAPI.fetchProducts()
      ├── saveProducts(isInitialImport: false)
      │   ├── detectChanges() for existing products
      │   ├── Creates ChangeEvents for price/stock changes
      │   ├── Creates ChangeEvents for new/removed products
      │   ├── Inserts all ChangeEvents into context
      │   └── updateProduct() creates VariantSnapshots before modifying values
      └── Updates store.lastFetchedAt
```

### Private Methods

#### `saveProducts(_:to:context:isInitialImport:) -> [ChangeEvent]`

Core persistence logic with change detection.

| Parameter | Type | Description |
|-----------|------|-------------|
| `shopifyProducts` | `[ShopifyProduct]` | Fetched products from API |
| `store` | `Store` | Store to save products to |
| `context` | `ModelContext` | SwiftData context |
| `isInitialImport` | `Bool` | If `true`, skips change detection (no ChangeEvents) |

Returns array of `ChangeEvent` objects that were created and inserted.

#### `detectChanges(existing:fetched:store:) -> [ChangeEvent]`

Compares existing product variants against fetched variants to detect:

- **Price changes**: Creates `.priceDropped` or `.priceIncreased` events with magnitude (small/medium/large)
- **Availability changes**: Creates `.backInStock` or `.outOfStock` events

#### `updateProduct(_:from:context:)`

Updates an existing product and its variants from fetched Shopify data. **Before modifying variant values**, creates a `VariantSnapshot` if price, compareAtPrice, or availability changed. This preserves historical data for price history charts.

#### `formatPrice(_:) -> String`

Formats a `Decimal` as USD currency string (e.g., "$29.99").

---

## SyncScheduler (@MainActor, @Observable)

Coordinates sync operations and exposes state to UI.

```swift
@MainActor
@Observable
class SyncScheduler {
    var isSyncing: Bool = false
    var lastSyncAt: Date?
    var syncProgress: Double = 0
    var currentStore: String?
    var errorMessage: String?
    
    func startBackgroundTimer(intervalMinutes: Int = 60)
    func stopBackgroundTimer()
    func syncAllStores() async
    func syncStore(_ store: Store) async
}
```

### Sync Flow

```
1. Guard against concurrent syncs (isSyncing)
2. Fetch all stores from SwiftData
3. For each store:
   a. Update currentStore for UI
   b. Fetch products via StoreService
   c. Apply diff, create snapshots
   d. Insert ChangeEvents  // <-- currently missing!
   e. Save context
   f. Update syncProgress
4. Send notifications for all changes
5. Reset state
```

### Timer

Uses `Timer.scheduledTimer` on macOS. For iOS, would need `BGAppRefreshTask`.

```swift
timer = Timer.scheduledTimer(
    withTimeInterval: TimeInterval(intervalMinutes * 60),
    repeats: true
) { [weak self] _ in
    Task { @MainActor in
        await self?.syncAllStores()
    }
}
```

---

## NotificationService (@MainActor)

Sends grouped local notifications.

```swift
@MainActor
class NotificationService {
    func requestPermission() async -> Bool
    func send(for changes: [ChangeEvent]) async
    func setupNotificationCategories()
}
```

### Grouping Strategy

Groups by (store, priority) to avoid spam:

```
Store A: 3 price drops, 1 back in stock
Store B: 2 new products
```

Instead of 6 separate notifications.

### Priority Levels

| Change Type | Magnitude | Priority |
|-------------|-----------|----------|
| priceDropped | large | high |
| backInStock | any | high |
| newProduct | any | medium |
| everything else | any | low |

High priority → `.timeSensitive` + sound
Low priority → `.passive`, no sound

### Notification Content

```swift
content.title = storeName
content.body = "3 price drops, 1 back in stock"
content.threadIdentifier = storeName  // Groups in Notification Center
```
