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

# Test
xcodebuild test -scheme watchify -destination 'platform=macOS'

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

## Architecture

```
┌─────────────────────────────────────────────┐
│  Views (SwiftUI + Liquid Glass)             │
├─────────────────────────────────────────────┤
│  SyncScheduler (@MainActor, @Observable)    │
├──────────────────┬──────────────────────────┤
│  StoreService    │  NotificationService     │
│  (actor)         │  (@MainActor)            │
├──────────────────┴──────────────────────────┤
│  SwiftData Models                           │
└─────────────────────────────────────────────┘
```

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
| `Services/StoreService.swift` | Fetch + diff logic |
| `Services/SyncScheduler.swift` | Coordinates syncs |
| `Models/` | SwiftData schema |
| `DTOs/ShopifyProduct.swift` | JSON decoding |

## Docs

| Doc | Topic |
|-----|-------|
| [docs/data-model.md](docs/data-model.md) | SwiftData schema |
| [docs/services.md](docs/services.md) | Service layer |
| [docs/views.md](docs/views.md) | UI components |
| [docs/shopify-api.md](docs/shopify-api.md) | Shopify JSON + pagination |
| [docs/roadmap.md](docs/roadmap.md) | MVP phases |

## Known Issues to Fix During Implementation

1. **Price decoding**: Shopify returns price as string `"29.99"`. Need custom decoder.

2. ~~**Actor isolation**~~: Resolved - `StoreService` is now `@MainActor` so it can access `ModelContext` directly.

3. **ChangeEvent persistence**: Events are created but never `context.insert()`ed.

4. **`recentPriceChange` perf**: Sorts snapshots on every access. Cache or compute once.
