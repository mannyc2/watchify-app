# Services

Four services handle the core logic:

| Service | Isolation | Purpose |
|---------|-----------|---------|
| `StoreService` | `ModelActor` | SwiftData persistence, sync |
| `NotificationService` | `@MainActor` | Local notifications |
| `NetworkMonitor` | `@MainActor` | Connectivity tracking |
| `BackgroundSyncState` | `@MainActor` | Ephemeral sync error state |

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

Comprehensive error type with user-friendly messages and SF Symbol icons.

```swift
enum SyncError: Error, LocalizedError {
    case storeNotFound              // Store not in database
    case rateLimited(retryAfter:)   // 60s cooldown between syncs
    case networkUnavailable         // Device offline
    case networkTimeout             // Request timed out
    case serverError(statusCode:)   // HTTP 5xx errors
    case invalidResponse            // Malformed data

    var errorDescription: String?      // Short title ("No connection")
    var failureReason: String?         // What happened
    var recoverySuggestion: String?    // How to fix it
    var iconName: String               // SF Symbol for UI
}
```

**Error Conversion**: `SyncError.from(_:)` converts `URLError` and `ShopifyAPIError` to appropriate cases:

| Source Error | SyncError |
|--------------|-----------|
| `URLError.notConnectedToInternet` | `.networkUnavailable` |
| `URLError.networkConnectionLost` | `.networkUnavailable` |
| `URLError.timedOut` | `.networkTimeout` |
| `ShopifyAPIError.httpError(5xx)` | `.serverError(statusCode:)` |
| Other errors | `.invalidResponse` |

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

---

## NetworkMonitor (@MainActor)

Singleton that tracks network connectivity using `NWPathMonitor`.

```swift
@MainActor @Observable
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private(set) var isConnected: Bool        // true if network available
    private(set) var connectionType: ConnectionType  // .wifi, .cellular, .wired, .unknown

    func start()   // Begin monitoring (call in app .task)
    func stop()    // Stop monitoring
}
```

### Usage

Started in `watchifyApp.swift`:

```swift
.task {
    NetworkMonitor.shared.start()
    // ...
}
```

Views can observe connectivity:

```swift
private var isOffline: Bool {
    !NetworkMonitor.shared.isConnected
}
```

### Why @Observable?

SwiftUI views need to reactively update when connectivity changes. Using `@Observable` on `@MainActor` allows views to directly observe `isConnected` without manual bindings or Combine.

---

## BackgroundSyncState (@MainActor)

Singleton that tracks ephemeral sync errors from background sync operations. Not persisted—cleared on app restart or successful sync.

```swift
@MainActor @Observable
final class BackgroundSyncState {
    static let shared = BackgroundSyncState()

    private(set) var storeErrors: [UUID: SyncError]  // Per-store errors

    var hasErrors: Bool           // True if any store has error
    var errorSummary: String?     // "1 store failed to sync" or "3 stores failed to sync"

    func recordError(_ error: SyncError, forStore storeId: UUID)
    func recordSuccess(forStore storeId: UUID)  // Clears error for store
    func clearAllErrors()
}
```

### Data Flow

```
Background sync loop (Task.detached)
  └── syncAllStoresWithErrorTracking()
      └── For each store:
          ├── Success → BackgroundSyncState.shared.recordSuccess(forStore:)
          └── Failure → BackgroundSyncState.shared.recordError(_:forStore:)

Views observe BackgroundSyncState.shared.hasErrors
  └── Show CompactErrorBannerView when true
```

### Why Separate from StoreService?

| Concern | StoreService | BackgroundSyncState |
|---------|--------------|---------------------|
| **Isolation** | `ModelActor` (background) | `@MainActor` |
| **Data** | Persistent (SwiftData) | Ephemeral (in-memory) |
| **Observation** | Can't be observed by SwiftUI | `@Observable` for reactive UI |

Views run on `@MainActor` and need `@Observable` state on the same actor. Keeping error state in a `@MainActor` singleton avoids actor-hopping complexity.

### Rate Limit Handling

Rate limit errors (`.rateLimited`) are **not** recorded in `BackgroundSyncState`—they're expected during normal operation (60s cooldown). Only unexpected failures are surfaced to users.
