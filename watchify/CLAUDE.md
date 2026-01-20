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

# Lint
swiftlint

# Clean
~/bin/xcede clean
```

Config is in `.xcrc` (scheme, platform, device). Currently set to `platform=mac`.

## Tech Stack

- **SwiftUI** + Liquid Glass design
- **SwiftData** for persistence
- **Swift Charts** for price history
- **Actors** for thread-safe networking

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

1. **Pagination**: Spec shows `?page=N` but Shopify uses cursor-based `page_info`. See [docs/shopify-api.md](docs/shopify-api.md).

2. **Price decoding**: Shopify returns price as string `"29.99"`. Need custom decoder.

3. ~~**Actor isolation**~~: Resolved - `StoreService` is now `@MainActor` so it can access `ModelContext` directly.

4. **ChangeEvent persistence**: Events are created but never `context.insert()`ed.

5. **`recentPriceChange` perf**: Sorts snapshots on every access. Cache or compute once.
