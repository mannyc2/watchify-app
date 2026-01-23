# Watchify

macOS app that monitors Shopify stores for price and stock changes via their public `/products.json` endpoint.

## Quick Start

```bash
# Xcode 16+, macOS 26 SDK (for Liquid Glass)
open Watchify.xcodeproj
```

## Development (Zed + Claude Code)

```bash
# Build (typecheck)
~/bin/xcede build

# Build and run
~/bin/xcede buildrun

# Test (unit)
xcodebuild test -scheme watchify -destination 'platform=macOS' -only-testing:watchifyTests

# Test (UI + accessibility audit)
xcodebuild test -scheme watchify -destination 'platform=macOS' -only-testing:watchifyUITests

# Lint
swiftlint

# Clean
~/bin/xcede clean
```

Git pre-commit hook runs build, lint, and tests automatically.

Config is in `.xcrc` (scheme, platform, device). Currently set to `platform=mac`.

## Tech Stack

- **SwiftUI** + Liquid Glass design
- **SwiftData** for persistence
- **Swift Charts** for price history
- **Actors** for thread-safe networking

## UI Guidelines

- **Empty States**: Always use `ContentUnavailableView` with icon, description, and optional action button
  ```swift
  ContentUnavailableView(
      "No Items",
      systemImage: "tray",
      description: Text("Your items will appear here")
  )
  ```

- **SwiftUI Previews**: When creating or modifying views, add previews for each meaningful state. Use the shared `makePreviewContainer()` from `Preview Content/PreviewHelpers.swift`:
  ```swift
  #Preview("State Name") {
      let container = makePreviewContainer()
      // Set up sample data...
      return ViewName(...)
          .modelContainer(container)
  }
  ```
  Common states to cover: empty, populated, loading, error, edge cases (e.g., long text, missing data)

## Code Style

- Prefer SwiftUI and modern Apple frameworks over AppKit equivalents. Only use AppKit when SwiftUI lacks the capability.

## Liquid Glass (macOS 26)

Glass helpers are in `Views/GlassTheme.swift`. Two key rules:

1. **Glass as background**: Never apply `.glassEffect()` directly to content—use `compositingGroup()` + `.background { Color.clear.glassEffect(...) }`
2. **Controls for interactivity**: Use `Button`/`NavigationLink`, not `onTapGesture`—glass `.interactive()` only works on actual controls

See [docs/liquid-glass.md](docs/liquid-glass.md) for full guidelines, best practices, and common pitfalls.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Views (SwiftUI + Liquid Glass)             │
├─────────────────────────────────────────────┤
│  ViewModels (@MainActor, @Observable)       │
│  - StoreDetailViewModel                     │
│  - ActivityViewModel                        │
│  - MenuBarViewModel                         │
├─────────────────────────────────────────────┤
│  DTOs (Sendable, cross-actor boundary)      │
│  - ProductDTO, StoreDTO, ChangeEventDTO     │
├──────────────────┬──────────────────────────┤
│  StoreService    │  @MainActor Singletons   │
│  (ModelActor)    │  - NotificationService   │
│                  │  - NetworkMonitor        │
│                  │  - BackgroundSyncState   │
├──────────────────┴──────────────────────────┤
│  SwiftData Models                           │
└─────────────────────────────────────────────┘
```

Background sync runs via `Task.detached` in `watchifyApp.swift` to avoid blocking MainActor.

## Core Loop

1. Timer fires (or manual sync)
2. Fetch `/products.json` from each store
3. Diff against stored products
4. Create snapshots for changes
5. Emit `ChangeEvent`s
6. Send grouped notifications

## Key Files

| File | Purpose |
|------|---------|
| `Services/StoreService.swift` | ModelActor for all SwiftData operations |
| `Services/StoreService+Sync.swift` | Product sync and change detection |
| `Services/StoreService+Events.swift` | Event queries and management |
| `Services/NetworkMonitor.swift` | NWPathMonitor connectivity tracking |
| `Services/BackgroundSyncState.swift` | Ephemeral sync error state for UI |
| `Services/NotificationService.swift` | Local notification delivery |
| `ViewModels/` | @MainActor ViewModels for complex views |
| `DTOs/` | Sendable types for cross-actor data transfer |
| `Models/` | SwiftData schema |

## Docs

| Doc | Topic |
|-----|-------|
| [docs/data-model.md](docs/data-model.md) | SwiftData schema |
| [docs/services.md](docs/services.md) | Service layer |
| [docs/views.md](docs/views.md) | UI components |
| [docs/shopify-api.md](docs/shopify-api.md) | Shopify JSON + pagination |
| [docs/instruments-cli.md](docs/instruments-cli.md) | Profiling with xctrace |
| [docs/roadmap.md](docs/roadmap.md) | MVP phases |

## Performance Notes

- **Background sync**: Uses `Task.detached` to avoid blocking MainActor during sync operations
- **DTO pattern**: Views receive lightweight DTOs instead of @Model objects to minimize SwiftData observation overhead
- **Deferred relationships**: ChangeEvent.store is set during batch insert, not in initializer, to reduce ObservationRegistrar calls

## Concurrency

**Rule**: Never `await StoreService` directly from `@MainActor`. Always wrap in `Task.detached`:

```swift
// ❌ Deadlocks
let data = await StoreService.shared.fetch()

// ✅ Safe
let data = await Task.detached { await StoreService.shared.fetch() }.value
```

**Why**: `save()` posts `NSManagedObjectContextDidSave` synchronously (waits for observers). If main thread awaits StoreService during this, SwiftData's executor calls `performBlockAndWait`—but the actor queue is blocked waiting for notification delivery. Circular wait = deadlock.

For trivial read-only fetches (single row by indexed ID), `@Environment(\.modelContext)` on main thread is fine. See `ProductDetailViewByShopifyId`.
