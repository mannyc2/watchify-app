# Services

Three services handle the core logic.

## StoreService (@MainActor, @Observable)

Handles store creation, product persistence, and syncing. Works with SwiftData ModelContext.

```swift
@MainActor
@Observable
final class StoreService {
    // Add new store: validates domain, creates store, fetches and saves products
    // Name is optional - derives from domain if nil/empty (e.g., "allbirds.com" → "allbirds")
    func addStore(name: String?, domain: String, context: ModelContext) async throws -> Store

    // Sync existing store: fetch from API + save to SwiftData
    func syncStore(_ store: Store, context: ModelContext) async throws
}
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
      ├── Saves products
      └── Returns store
```

### Manual Sync Flow

```
StoreDetailView sync button
  └── StoreService.syncStore(store, context)
      ├── ShopifyAPI.fetchProducts()
      ├── Saves/updates products
      └── Updates store.lastFetchedAt
```

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
