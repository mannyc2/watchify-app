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
    // Sets lastFetchedAt to enable rate limiting on subsequent syncs
    func addStore(name: String?, domain: String, context: ModelContext) async throws -> Store

    // Sync existing store: fetch from API + save to SwiftData
    // Enforces 60s rate limit - throws SyncError.rateLimited if too soon
    // Returns detected ChangeEvents for notification handling
    @discardableResult
    func syncStore(_ store: Store, context: ModelContext) async throws -> [ChangeEvent]
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
      ├── Rate limit check (60s minimum between syncs)
      │   └── Throws SyncError.rateLimited(retryAfter:) if too soon
      ├── ShopifyAPI.fetchProducts()
      ├── saveProducts(isInitialImport: false)
      │   ├── detectChanges() for existing products
      │   ├── Creates ChangeEvents for price/stock changes
      │   ├── Creates ChangeEvents for new/removed products
      │   ├── Inserts all ChangeEvents into context
      │   └── updateProduct() creates VariantSnapshots before modifying values
      ├── Updates store.lastFetchedAt
      └── Returns [ChangeEvent] for notification handling
```

### SyncError

Custom error type with Apple's `LocalizedError` properties for user-friendly messaging:

```swift
enum SyncError: Error, LocalizedError {
    case storeNotFound
    case rateLimited(retryAfter: TimeInterval)

    var errorDescription: String?      // Short title
    var failureReason: String?         // Detailed explanation
    var recoverySuggestion: String?    // What user can do
}
```

| Error | errorDescription | failureReason | recoverySuggestion |
|-------|------------------|---------------|-------------------|
| `.storeNotFound` | "Store not found" | "We couldn't find..." | "Check the domain..." |
| `.rateLimited(45)` | "Sync limited" | "Please wait 45 seconds..." | "Try again after..." |

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

Singleton that coordinates background sync operations. Uses structured concurrency with `Task.sleep` for the timer loop.

```swift
@MainActor
@Observable
final class SyncScheduler {
    static let shared = SyncScheduler()

    private(set) var isSyncing: Bool = false
    private(set) var lastSyncAt: Date?

    // Reads from UserDefaults (matches @AppStorage in Settings)
    var intervalMinutes: Int {
        UserDefaults.standard.integer(forKey: "syncIntervalMinutes")
            .clamped(to: 5...1440, default: 30)
    }

    func configure(with container: ModelContainer)
    func startBackgroundSync() async
    func syncAllStores() async
}
```

### Setup

Configure in app entry point, start from `.task` modifier:

```swift
@main
struct WatchifyApp: App {
    let container: ModelContainer

    init() {
        container = try! ModelContainer(for: Store.self, ...)
        SyncScheduler.shared.configure(with: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await SyncScheduler.shared.startBackgroundSync()
                }
        }
        .modelContainer(container)
    }
}
```

### Background Sync Loop

Uses `Task.sleep` instead of `Timer.scheduledTimer` for structured concurrency. Cancellation is automatic when the `.task` view disappears.

```swift
func startBackgroundSync() async {
    // Prevent App Nap throttling
    activityToken = ProcessInfo.processInfo.beginActivity(
        options: .userInitiated,
        reason: "Background sync timer"
    )

    while !Task.isCancelled {
        await syncAllStores()
        try? await Task.sleep(for: .seconds(intervalMinutes * 60))
    }

    // Clean up on cancellation
    ProcessInfo.processInfo.endActivity(activityToken)
}
```

### Sync Flow

```
1. Guard against concurrent syncs (isSyncing)
2. Create fresh ModelContext from container
3. Fetch all stores
4. For each store:
   a. Call storeService.syncStore() (handles changes + notifications)
   b. Log errors but continue with other stores
5. Auto-delete old events if enabled in Settings
   a. Check UserDefaults for "autoDeleteEvents" and "eventRetentionDays"
   b. Delete ChangeEvents older than retention period
6. Update lastSyncAt
```

### App Nap Prevention

Uses `ProcessInfo.beginActivity` to prevent macOS from throttling the background timer when the app is not in focus.

---

## NotificationService (@MainActor)

Singleton that sends local notifications when changes are detected. Follows Apple HIG by requesting permission contextually (when first changes occur) rather than on app launch.

```swift
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    func authorizationStatus() async -> UNAuthorizationStatus
    func requestPermission() async -> Bool
    func requestPermissionIfNeeded() async -> Bool
    func sendIfAuthorized(for changes: [ChangeEvent]) async
    func send(for changes: [ChangeEvent]) async
}
```

### Permission Flow

```
sendIfAuthorized(for: changes)
  ├── Guard: return early if changes empty
  ├── requestPermissionIfNeeded()
  │   ├── Check authorizationStatus()
  │   ├── If .notDetermined → requestPermission()
  │   ├── If .authorized → return true
  │   └── Otherwise → return false
  └── If authorized → send(for: changes)
```

### Settings Integration

The `send(for:)` method respects user preferences from Settings:

1. **Master toggle**: Checks `notificationsEnabled` - if false, skips all notifications
2. **Per-type filtering**: Filters changes by enabled types before sending
   - Keys: `notifyPriceDropped`, `notifyPriceIncreased`, `notifyBackInStock`, etc.
   - Defaults: All enabled except `notifyImagesChanged` (false by default)
3. **Price thresholds**: Filters price changes by minimum threshold
   - Keys: `priceDropThreshold`, `priceIncreaseThreshold`
   - Uses `PriceThreshold` enum to check if change meets minimum

### Price Threshold Filtering

Users can set minimum thresholds for price change notifications:

```swift
enum PriceThreshold: String, CaseIterable {
    case any = "Any amount"
    case dollars5 = "At least $5"
    case dollars10 = "At least $10"
    case dollars25 = "At least $25"
    case percent10 = "At least 10%"
    case percent25 = "At least 25%"

    func isSatisfied(by change: ChangeEvent) -> Bool
}
```

| Threshold | Check |
|-----------|-------|
| Any amount | Always passes |
| At least $X | `abs(priceChange) >= X` |
| At least X% | Uses `magnitude` enum (small <10%, medium 10-25%, large >25%) |

The `meetsThreshold(_:)` method in NotificationService applies this filter:
- Non-price changes (back in stock, etc.) always pass
- Price drops use `priceDropThreshold` setting
- Price increases use `priceIncreaseThreshold` setting

### Notification Content

One notification per store with grouped change summary:

```swift
content.title = store.name                    // e.g., "Allbirds"
content.body = "3 price drops, 1 back in stock"
content.threadIdentifier = store.id.uuidString  // Groups in Notification Center
content.interruptionLevel = .timeSensitive    // Breaks through Focus mode
content.sound = .default
```

If changes have no associated store (orphan changes), the title is left empty and macOS shows the app name per Apple HIG.

### Store Grouping

The `send(for:)` method groups changes by store before sending:

```swift
let groupedByStore = Dictionary(grouping: changes) { $0.store?.id }

for (_, storeChanges) in groupedByStore {
    // Send one notification per store
}
```

- **`threadIdentifier`**: Uses `store.id.uuidString` for stable grouping (store names could change)
- **Visual grouping**: macOS Notification Center groups notifications with the same `threadIdentifier`

### Notification Priority

Interruption level is determined by the highest-priority change in the group:

| Priority | Interruption Level | Sound | Criteria |
|----------|-------------------|-------|----------|
| High | `.timeSensitive` | Yes | Back in stock, large price drops (>25%) |
| Normal | `.active` | Yes | Medium price drops (10-25%), price increases, stock changes, new/removed products |
| Low | `.passive` | No | Small price drops (<10%), image changes |

The `determinePriority(for:)` method evaluates all changes and returns the highest applicable level. This ensures important alerts break through Focus modes while minor changes remain unobtrusive.

### Body Formatting

Groups changes by type into human-readable summary:

```
formatBody(for: changes) → "3 price drops, 2 back in stock, 1 new product"
```

| Change Type | Format |
|-------------|--------|
| priceDropped | "N price drop(s)" |
| priceIncreased | "N price increase(s)" |
| backInStock | "N back in stock" |
| outOfStock | "N out of stock" |
| newProduct | "N new product(s)" |
| productRemoved | "N product(s) removed" |

### Future Improvements

- Per-store notification preferences (currently global only)
- Custom threshold values (currently preset options only)
- Precise percentage calculation (currently uses magnitude enum as proxy)
