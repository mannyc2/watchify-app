# Changelog

All notable changes to Watchify. Format based on [Keep a Changelog](https://keepachangelog.com/).

## 2026-01-24

### Added
- Page object pattern for UI tests (`SidebarScreen`, `StoreDetailScreen`, `AddStoreScreen`, `SettingsScreen`)
- UI test files: `SyncTests`, `NavigationTests`, `AddStoreTests`, `DeleteStoreTests`, `SettingsTests`, `ErrorStateTests`
- Accessibility identifiers for UI testing
- `Helpers/Tags.swift` consolidating all test tag definitions

### Fixed
- Sync button toolbar placement: `.navigation` → `.primaryAction` per HIG
- Add Store button moved to `safeAreaInset(edge: .bottom)` for consistent visibility
- `NavigationStack` uses `.id(id)` to force view recreation on selection change
- `SaveProductsResult` Swift 6 strict concurrency with `nonisolated(unsafe)` markers

### Changed
- Unit tests reorganized into nested Swift Testing suites (`StoreService/`, `NotificationService/`, `Models/`, `Errors/`)
- UI tests refactored to page object pattern with `XCTContext.runActivity` logging
- Test data seeding simplified to `-UITesting` flag with `seedTestDataIfNeeded()`
- Removed swiftlint disable comments (fixed underlying formatting)

### Removed
- `watchifyUITests.swift`, `watchifyUITestsLaunchTests.swift` (replaced by focused test files)

---

## 2026-01-23

### Added
- Nuke image loading library for background decode and caching
- `ImageService` with `DataCache` (500MB persistent disk cache)
- `CachedAsyncImage` SwiftUI wrapper with display size presets
- Display sizes: `.productCard` (120pt), `.thumbnailCompact` (64pt), `.thumbnailExpanded` (80pt), `.storePreview` (100pt), `.fullSize`
- Image cache settings in Settings > Data: size display, limit picker (100MB/250MB/500MB/1GB), clear cache, reveal in Finder

### Fixed
- `SaveProductsResult` optimization: return active products from `saveProducts()` to avoid re-faulting `store.products` relationship in `updateListingCache()` (0.6ms, zero faults)
- Resurrect bug: products removed in prior sync that reappear from Shopify now revive instead of causing duplicate inserts
- Image decode hangs: replaced `AsyncImage` with `CachedAsyncImage` (Nuke) to eliminate 326ms main thread blocks

### Changed
- `saveProducts()` is now `async` and yields every 50 products to release actor lock
- `saveProducts()` returns `SaveProductsResult` struct with `changes` and `activeProducts`
- `addStore()` and `syncStore()` use `result.activeProducts` instead of `store.products`
- Added fetch for removed products that match incoming shopifyIds during sync
- `ProductCard`, `ProductImageCarousel`, `StoreCard`, `ProductDetailView` now use `CachedAsyncImage`

### Performance
- `updateListingCache`: eliminated ~600 product faults per sync
- `Task.yield()` in processing loop: max continuous actor lock reduced from 274ms to ~20ms
- Image loading: main thread hangs reduced from 326ms to 0ms (Nuke background decode)
- Max SwiftUI update time reduced from 326ms to 13.5ms
- No `_SwiftUIProxyImage` stalls in post-Nuke traces

---

## 2026-01-22

### Added
- Full VoiceOver accessibility: labels, hints, hidden decorative icons, combined elements
- Accessibility audit UI tests (`AccessibilityAuditTests.swift`)
- Keyboard shortcuts and menu bar commands (`AppCommands.swift`)
  - File menu: Add Store (⌘N), Sync All (⌘R), Sync Current Store (⌘⇧R)
  - Navigate menu: Overview (⌘1), Activity (⌘2), Stores (⌘3-9)
  - Standard `SidebarCommands` and `ToolbarCommands`
- Snapshot cleanup with configurable retention period (Settings > Data)
- `deleteOldSnapshots(olderThan:)` in `StoreService` for automatic cleanup during sync
- ViewModels: `StoreDetailViewModel`, `ActivityViewModel`, `MenuBarViewModel`, `StoreListViewModel`
- DTOs: `ProductDTO`, `StoreDTO`, `ChangeEventDTO` for actor boundary crossing
- `StoreService` as `ModelActor` with background execution
- `Task.detached` pattern for all StoreService calls (deadlock prevention)
- Native macOS toolbars for StoreDetailView and ActivityView
- `NetworkMonitor` service using `NWPathMonitor` for connectivity tracking
- `BackgroundSyncState` for tracking per-store sync errors
- `ErrorBannerView` component for inline error display with retry/dismiss
- Expanded `SyncError` with `.networkUnavailable`, `.networkTimeout`, `.serverError`, `.invalidResponse`
- "Last synced X ago" context in `SyncStatusView` and error banners
- Offline indicator in Overview/Activity navigation subtitles
- Background sync error surfacing in Overview and Activity views
- 35 new tests for `SyncError` cases, `SyncError.from()` converter, and `BackgroundSyncState`
- TipKit integration with `AddStoreTip`, `SyncTip`, `ActivityTip` for new user guidance
- Tooltips (`.help()`) on toolbar controls throughout the app

### Changed
- Renamed view files: dropped "DTO" suffix (`StoreCardDTO` → `StoreCard`, etc.)
- Moved `CLAUDE.md` and `docs/` to project root
- Background sync hangs reduced from 8.77s to 203ms (97% reduction)
- Replaced modal sync error alert with inline `ErrorBannerView` in StoreDetailView
- Sync button shows `wifi.slash` icon and tooltip when offline
- `PriceHistorySection` shows localized inline empty states (chart/list headers always visible)
- Improved empty state copy to be action-oriented
- 
---

## 2026-01-21

### Added
- Liquid Glass design system (`GlassTheme.swift`)
- Glass helper extensions: `glassSurface()`, `interactiveGlassSurface()`, `glassPill()`, `interactiveGlassCard()`
- Hover effects on StoreCard and ProductCard
- `.buttonStyle(.glass)` for toolbar buttons

### Changed
- StoreCard converted from `onTapGesture` to `Button` for press feedback
- ActivityDateSection uses `.regularMaterial` instead of glass

### Removed
- `GlassEffectContainer` wrappers from grids (incorrect usage)

---

## 2026-01-20

### Added
- Menu bar extra with unread event list (`MenuBarView`, `MenuBarEventRow`)
- Settings window (⌘,) with General, Notifications, Data tabs
- Price threshold notifications (absolute: $5/$10/$25, percentage: 10%/25%)
- Notification priority levels and Time Sensitive entitlement
- Mark as read functionality with unread badge
- Product detail view with image carousel
- Price history chart with Swift Charts
- `PriceChangeIndicator`, `PriceHistorySection`, `VariantRow` components
- Product grid with `LazyVGrid` and `ProductCard`
- Stock badge and shared `Badge` component
- Full ActivityView with filters (store, type, date range)
- Overview page with adaptive store card grid
- Sidebar section structure (Overview, Activity, Stores)
- 23 SwiftUI preview states across 6 files
- `ChangeType.icon` and `ChangeType.color` standardization

### Changed
- Replaced `ProductImage` model with `imageURLs: [String]` array
- Activity moved from toolbar sheet to sidebar destination

---

## 2026-01-19

### Added
- `ChangeEvent` model with change detection
- `VariantSnapshot` model for price history
- Background sync timer and rate limiting
- `SyncStatusView` with countdown timer
- Local notifications via `NotificationService`
- `ShopifyAPIProtocol` and `MockShopifyAPI` for testing
- 14 comprehensive change detection tests
- Store detail view with manual sync
- Pagination for Shopify API
- `StoreService` with `syncStore()` and `addStore()`

### Added (initial)
- Xcode project with SwiftUI lifecycle, macOS 26 minimum
- SwiftData models: `Store`, `Product`, `Variant`
- `AddStoreSheet`, `SidebarView`, store CRUD
- Shopify DTOs and `ShopifyAPI` service

---

## Summary

| Date | Theme |
|------|-------|
| 2026-01-19 | Project setup, data model, Shopify sync, change detection |
| 2026-01-20 | UI polish, product detail, settings, menu bar, notifications |
| 2026-01-21 | Liquid Glass design system |
| 2026-01-22 | Concurrency fixes, ViewModels, snapshot cleanup, error handling, accessibility |
| 2026-01-23 | Sync performance, Nuke image loading (326ms hangs → 0ms) |
| 2026-01-24 | UI test infrastructure, test suite reorganization, Swift 6 concurrency fixes |
