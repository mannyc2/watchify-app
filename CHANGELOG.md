# Changelog

All notable changes to Watchify. Format based on [Keep a Changelog](https://keepachangelog.com/).

## 2026-01-22

### Added
- ViewModels: `StoreDetailViewModel`, `ActivityViewModel`, `MenuBarViewModel`, `StoreListViewModel`
- DTOs: `ProductDTO`, `StoreDTO`, `ChangeEventDTO` for actor boundary crossing
- `StoreService` as `ModelActor` with background execution
- `Task.detached` pattern for all StoreService calls (deadlock prevention)
- Native macOS toolbars for StoreDetailView and ActivityView

### Changed
- Renamed view files: dropped "DTO" suffix (`StoreCardDTO` → `StoreCard`, etc.)
- Moved `CLAUDE.md` and `docs/` to project root
- Background sync hangs reduced from 8.77s to 203ms (97% reduction)

### Removed
- Dead code: old `ProductCard.swift` (replaced by DTO-based version)
- `swiftdata-main-thread-issue.md` (consolidated into CLAUDE.md)

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
| 2026-01-22 | Concurrency fixes, ViewModels, code cleanup |
