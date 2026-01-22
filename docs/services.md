# Services

Two services handle the core logic.

## StoreService (ModelActor)

Background actor for all SwiftData operations. Conforms to `ModelActor` protocol for thread-safe database access.

```swift
actor StoreService: ModelActor {
    static var shared: StoreService!

    nonisolated let modelExecutor: any ModelExecutor
    nonisolated let modelContainer: ModelContainer
    nonisolated let api: ShopifyAPIProtocol

    // Factory method - ensures background execution
    @concurrent
    static func makeBackground(
        container: ModelContainer,
        api: ShopifyAPIProtocol? = nil
    ) async -> StoreService

    // Store management
    func addStore(name: String?, domain: String) async throws -> UUID
    func syncStore(storeId: UUID) async throws -> [ChangeEventDTO]
    func syncAllStores() async

    // Product queries (return DTOs for cross-actor safety)
    func fetchProducts(storeId:searchText:stockScope:sortOrder:offset:limit:) -> [ProductDTO]
    func fetchProductCount(storeId:searchText:stockScope:) -> Int

    // Event queries
    func fetchActivityEvents(storeId:changeTypes:startDate:offset:limit:) -> [ChangeEventDTO]
    func fetchMenuBarEvents(limit:) -> [ChangeEventDTO]
    func fetchUnreadCount() -> Int
    func markEventRead(id:)
    func markAllUnreadEventsRead()
}
```

### Initialization

StoreService is initialized in `watchifyApp.swift` and stored as a shared singleton:

```swift
.task {
    StoreService.shared = await StoreService.makeBackground(container: container)

    // Background sync runs in detached task to avoid blocking MainActor
    Task.detached(priority: .utility) {
        while !Task.isCancelled {
            await StoreService.shared.syncAllStores()
            try? await Task.sleep(for: .seconds(interval))
        }
    }
}
```

### Why ModelActor?

- **Thread safety**: All SwiftData operations happen on the actor's serial executor
- **Background execution**: Sync operations don't block the main thread
- **DTOs for communication**: Returns `Sendable` DTOs instead of `@Model` objects to cross actor boundaries safely

### File Organization

| File | Purpose |
|------|---------|
| `StoreService.swift` | Core actor, initialization, store management |
| `StoreService+Sync.swift` | Product sync, change detection, batch operations |
| `StoreService+Events.swift` | Event queries, mark read, filtering |

### Sync Flow

```
Task.detached (background)
  └── StoreService.syncAllStores()
      └── For each store:
          └── syncStore(storeId:)
              ├── Rate limit check (60s minimum)
              ├── api.fetchProducts(domain:)
              ├── saveProducts(_:to:isInitialImport:false)
              │   ├── processFetchedProducts() → detect changes
              │   ├── processRemovedProducts() → mark removed
              │   └── Batch insert ChangeEvents (deferred store relationship)
              └── Return [ChangeEventDTO]
```

### Performance Optimizations

1. **Task.detached**: Breaks MainActor inheritance from SwiftUI body
2. **Deferred store relationship**: ChangeEvent.store is set during batch insert, not in initializer
3. **Task.yield()**: Yields between stores to allow other background work
4. **DTO pattern**: Views receive lightweight DTOs, avoiding @Model observation overhead

### SyncError

```swift
enum SyncError: Error, LocalizedError {
    case storeNotFound
    case rateLimited(retryAfter: TimeInterval)
}
```

---

## NotificationService (@MainActor)

Singleton that sends local notifications when changes are detected.

```swift
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    func send(for changes: [ChangeEventDTO]) async
}
```

### Permission Flow

Requests permission contextually (when first changes occur) rather than on app launch, following Apple HIG.

### Settings Integration

Respects user preferences from Settings:
- **Master toggle**: `notificationsEnabled`
- **Per-type filtering**: `notifyPriceDropped`, `notifyBackInStock`, etc.
- **Price thresholds**: `priceDropThreshold`, `priceIncreaseThreshold`

### Notification Priority

| Priority | Interruption Level | Criteria |
|----------|-------------------|----------|
| High | `.timeSensitive` | Back in stock, large price drops (>25%) |
| Normal | `.active` | Medium changes, stock changes |
| Low | `.passive` | Small price drops, image changes |

### Notification Content

One notification per store with grouped change summary:

```swift
content.title = storeName              // e.g., "Allbirds"
content.body = "3 price drops, 1 back in stock"
content.threadIdentifier = storeId     // Groups in Notification Center
```
