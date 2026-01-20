# Iteration Plan

Small, working increments. Each iteration should be completable in 1-3 hours and result in something testable.

---

## Iteration 1: Project Setup ✅

**Goal**: Empty app runs.

- [x] Create Xcode project (macOS app, SwiftUI lifecycle)
- [x] Set minimum deployment to macOS 26
- [x] Add SwiftData capability
- [x] Create empty `CLAUDE.md` in project root
- [x] Verify builds and runs

**Test**: App launches, shows empty window.

---

## Iteration 2: Data Model - Store ✅

**Goal**: Can persist a Store.

- [x] Create `Models/Store.swift` with basic fields
- [x] Configure `ModelContainer` in app entry point
- [x] Inject `modelContext` into environment

**Test**: Add a store via debugger/preview, quit, relaunch, verify it persists.

---

## Iteration 3: Add Store UI ✅

**Goal**: User can add a store.

- [x] Create `AddStoreSheet.swift`
  - Text field for domain
  - Text field for name (optional, derive from domain)
  - Add button
- [x] Wire up to ContentView with `.sheet`
- [x] Insert Store into SwiftData on submit
- [x] Basic validation (non-empty domain)

**Test**: Add "allbirds.com", see it saved.

---

## Iteration 4: Sidebar - Store List ✅

**Goal**: See added stores in sidebar.

- [x] Create `SidebarView.swift`
- [x] Use `@Query` to fetch all stores
- [x] Display as `List` with `ForEach`
- [x] Create `StoreRow.swift` (just name for now)
- [x] Wire into `NavigationSplitView` in ContentView

**Test**: Add 2-3 stores, see them in sidebar.

---

## Iteration 5: Delete Store ✅

**Goal**: Can remove a store.

- [x] Add swipe-to-delete on StoreRow
- [x] Add context menu with Delete option
- [x] Delete from SwiftData

**Test**: Add store, delete it, verify gone after relaunch.

---

## Iteration 6: Shopify DTOs ✅

**Goal**: Can decode Shopify JSON.

- [x] Create `DTOs/ShopifyProduct.swift`:
  - `ShopifyProductsResponse`
  - `ShopifyProduct`
  - `ShopifyVariant` (with custom price decoding)
  - `ShopifyImage`
- [x] Handle string→Decimal for price

**Test**: Decode real JSON from a Shopify store, all fields populated.

---

## Iteration 7: Fetch Products ✅

**Goal**: Fetch and print products from a store.

- [x] Create `Services/ShopifyAPI.swift`
- [x] Implement `fetchProducts(domain: String) async throws -> [ShopifyProduct]`

**Test**: Tap button, see products logged.

---

## Iteration 8: Pagination ✅

**Goal**: Fetch all products from large stores.

- [x] Parse `Link` header for `rel="next"`
- [x] Loop until no next page
- [x] Update `fetchProducts` to return all

**Test**: Fetch from store with 300+ products, verify count > 250.

---

## Iteration 9: Data Model - Product & Variant ✅

**Goal**: Can persist products.

- [x] Create `Models/Product.swift`
- [x] Create `Models/Variant.swift`
- [x] Add relationships to Store
- [x] Update ModelContainer

**Test**: Create product + variants in code, verify persists.

---

## Iteration 10: Save Fetched Products ✅

**Goal**: Persist products from fetch.

- [x] Create `Services/StoreService.swift` with `syncStore()` method
- [x] Map DTOs → Models
- [x] Insert/update into SwiftData
- [x] Wire up: fetch → save
- [x] Add `addStore(name:domain:context:)` method for creating store + fetching products in one operation
- [x] `AddStoreSheet` uses `StoreService.addStore()` - view passes raw input, service handles name derivation

**Test**: Fetch store, quit app, relaunch, products still there.

---

## Iteration 11: Store Detail - Product List ✅

**Goal**: See products for a store.

- [x] Create `StoreDetailView.swift`
- [x] `@Query` products filtered by store
- [x] Simple `List` with `ProductRow`
- [x] Show title, price, availability
- [x] Wire into NavigationSplitView detail

**Test**: Select store in sidebar, see its products.

---

## Iteration 12: Manual Sync Button ✅

**Goal**: Refresh products on demand.

- [x] Add "Sync" button to toolbar
- [x] Fetch products, save/update
- [x] Show loading indicator
- [x] Update `store.lastFetchedAt`

**Note**: Products are already loaded when adding a store (see iteration 10). The sync button is for manual refresh only—not for initial load.

**Test**: Change price on Shopify (or use different store), sync, see update.

---

## Iteration 12a: AddStoreSheet Polish ✅

**Goal**: Improve loading state UX in AddStoreSheet.

- [x] Disable form fields when adding
- [x] Replace "Add" button with `ProgressView` spinner while loading
- [x] Remove overlay approach

**Test**: Add store, loading state feels integrated (not overlaid).

---

## Iteration 12b: Auto-Select New Store ✅

**Goal**: Automatically navigate to a newly added store.

- [x] `AddStoreSheet` takes `@Binding var selection: Store?`
- [x] Sets `selection = store` after successful add
- [x] `ContentView` passes `$selectedStore` binding to sheet

**Test**: Add store, detail view shows its products without manual selection.

---

## Iteration 13: Diff Detection ✅

**Goal**: Detect what changed.

- [x] Implement diff logic in `saveProducts`:
  - New products (in fetch, not in DB)
  - Removed products (in DB, not in fetch)
  - Updated products (price or availability changed)
- [x] Add `detectChanges` helper for variant-level change detection
- [x] Return `[ChangeEvent]` from `saveProducts`
- [x] Add `isInitialImport` flag to skip change events on first add

**Test**: Add product on Shopify, sync, diff shows it as new.

---

## Iteration 14: Data Model - ChangeEvent ✅

**Goal**: Persist detected changes.

- [x] Create `Models/ChangeEvent.swift`
- [x] Fields: id, changeType, productTitle, variantTitle, oldValue, newValue, occurredAt, isRead, magnitude
- [x] Add `changeEvents` relationship to Store
- [x] Insert ChangeEvents when diff detected
- [x] Add ChangeEvent to ModelContainer

**Test**: Sync detects change, ChangeEvent persisted.

---

## Iteration 14a: Test Change Detection ✅

**Goal**: Verify ChangeEvents are created and persisted correctly.

- [x] Add `ShopifyAPIProtocol` for dependency injection
- [x] Update `StoreService` to accept injected API
- [x] Create `MockShopifyAPI` for tests
- [x] Create `watchifyTests` test target with Swift Testing
- [x] Add `TestContext` class to reduce test boilerplate
- [x] Add assertion helpers (`fetchEvents`, `expectEvent`, `expectEventCount`)
- [x] Add test tags for organization (`.changeDetection`, `.priceChanges`, `.stockChanges`, etc.)
- [x] Write 14 comprehensive tests:
  - **Initial Import**: `addStoreCreatesNoEvents`, `syncWithNoChangesCreatesNoEvents`
  - **Price Changes**: `syncDetectsPriceDrop`, `syncDetectsPriceIncrease`
  - **Stock Changes**: `syncDetectsBackInStock`, `syncDetectsOutOfStock`
  - **Product Lifecycle**: `syncDetectsNewProducts`, `syncDetectsRemovedProducts`
  - **Complex**: `syncDetectsMultipleChanges`
  - **Error Handling**: `syncHandlesAPIErrors`, `addStoreHandlesAPIErrors`
  - **Isolation**: `testsAreIsolated` (parameterized, 3 iterations)

**Test**: All 14 tests pass via `xcodebuild test`.

---

## Iteration 15: Activity View (Basic) ✅

**Goal**: See change history.

- [x] Create `ActivityView.swift`
- [x] `@Query` all ChangeEvents, sorted by date desc
- [x] Simple list with type icon, product name, values
- [x] Add "Activity" link to sidebar

**Test**: Make changes happen, see them in activity.

---

## Iteration 15a: Activity UX Improvement ✅

**Goal**: Move Activity from sidebar to toolbar for better UX.

- [x] Remove `.activity` case from `SidebarSelection`
- [x] Remove Activity section from `SidebarView`
- [x] Add Activity toolbar button to `ContentView`
- [x] Present `ActivityView` as sheet with detents
- [x] Apply `.buttonStyle(.glass)` for Liquid Glass

**Test**: Activity button in toolbar, opens as sheet, store context preserved. ✅

---

## Iteration 16: Data Model - Snapshots ✅

**Goal**: Track historical values.

- [x] Create `Models/VariantSnapshot.swift`
- [x] Fields: capturedAt, price, compareAtPrice, available
- [x] Relationship to Variant (with cascade delete)
- [x] Create snapshot when variant values change (in `StoreService.updateProduct()`)
- [x] Add `priceHistory` and `mostRecentSnapshot` computed properties to Variant
- [x] Add comprehensive tests in `VariantSnapshotTests.swift`
- [x] (Skip ProductSnapshot for now—variant is what matters)

**Test**: Price changes twice, two snapshots exist. ✅

---

## Iteration 17: Local Notifications (Basic) ✅

**Goal**: Get notified of changes.

- [x] Create `Services/NotificationService.swift`
- [x] Request permission contextually (Apple HIG best practice)
- [x] Send notification when changes detected
- [x] Simple: one notification per sync with change count

**Implementation Notes**:
- Permission is requested contextually when first changes are detected (not on app launch per Apple HIG)
- `authorizationStatus()` - check status without prompting
- `requestPermissionIfNeeded()` - only prompts if `.notDetermined`
- `sendIfAuthorized(for:)` - requests permission if needed, then sends
- `StoreService.syncStore()` calls `sendIfAuthorized()` when changes detected

**Test**: Sync finds changes, notification appears.

---

## Iteration 18: Background Sync Timer ✅

**Goal**: Auto-sync periodically.

- [x] Create `Services/SyncScheduler.swift`
- [x] Start timer on app launch (60 min default)
- [x] Sync all stores when timer fires
- [x] Track `isSyncing` to prevent overlap

**Test**: Set timer to 1 min for testing, see auto-syncs.

---

## Iteration 19: Rate Limiting ✅

**Goal**: Be polite to Shopify.

- [x] Track last fetch time per store
- [x] Enforce 60s minimum between fetches
- [x] Return error if rate limited (don't just skip silently)

**Test**: Spam sync button, get rate limit feedback.

---

## Iteration 19a: Rate Limit UX (Apple HIG) ✅

**Goal**: Replace blocking alert with inline, non-disruptive status view.

- [x] Enrich `SyncError` with `failureReason` and `recoverySuggestion` per Apple's LocalizedError guidance
- [x] Create `SyncStatusView.swift` - inline component with countdown timer, retry button, dismiss button
- [x] Use `.ultraThinMaterial` for native macOS glass effect
- [x] Update `StoreDetailView` to show inline status for rate limits (alerts for other errors)
- [x] Add smooth transition animation for status appearance
- [x] Proper accessibility label for VoiceOver
- [x] Timer cleanup on view disappear
- [x] Add tests for enriched error properties
- [x] **Polish**: Add `Status` enum with `.waiting(seconds:)` and `.ready` cases
- [x] **Polish**: Transition to ready state when countdown hits 0 (icon: clock → checkmark.circle green)
- [x] **Polish**: Change copy from "Wait Xs..." → "You can sync now."
- [x] **Polish**: Post macOS accessibility announcement when ready
- [x] **Polish**: Auto-dismiss after 8 seconds in ready state

**Files**:
- `Services/StoreService.swift` - enriched `SyncError` enum
- `Views/SyncStatusView.swift` - inline status component with state machine
- `Views/StoreDetailView.swift` - inline status integration
- `watchifyTests/StoreServiceTests.swift` - new error property tests

**Test**: Sync button spammed → inline status with countdown appears, retry enables at 0, non-rate-limit errors still show as alerts.

---

## Iteration 19b: Sidebar - Richer Store Rows ⏭️ (Skipped)

**Goal**: Store rows show more than just name.

**Decision**: Keeping store rows simple (icon + name only). Sync status felt too prominent/noisy in the sidebar. Per-store sync tracking added to `SyncScheduler` for potential future use.

---

## Iteration 19c: Sidebar - Section Structure ✅

**Goal**: Separate navigation destinations from stores.

- [x] Add section header "Stores" above store list
- [x] Add "Overview" destination at top of sidebar (before stores)
- [x] Move Activity from toolbar button to sidebar destination (below Overview, above Stores section)
- [x] Add "+ Add Store" row at bottom of Stores section (or as footer)
- [x] Update `SidebarSelection` enum to handle new structure

**Sidebar structure:**
```
Overview
Activity
─────────
Stores
  Allbirds
  Glossier
  + Add Store
```

**Files**:
- `Views/SidebarView.swift` - Added `SidebarSelection` enum, restructured layout
- `Views/OverviewView.swift` - New placeholder view
- `ContentView.swift` - Updated selection type, removed Activity sheet
- `Views/AddStoreSheet.swift` - Updated selection binding

**Test**: Can navigate between Overview, Activity, and stores. Add Store works from sidebar. ✅

---

## Iteration 19d: Overview - Basic Layout ✅

**Goal**: Overview shows all stores at a glance.

- [x] Create `OverviewView.swift` (placeholder created in 19c)
- [x] Make Overview the default selection when app launches (done in 19c)
- [x] Display store cards in adaptive grid (`LazyVGrid` with `GridItem(.adaptive(minimum: 280, maximum: 400))`)
- [x] Create `StoreCard.swift` with: name, product count, preview images (up to 3), event badges (24h changes)
- [x] Clicking a card navigates to that store's detail
- [x] Empty state with `ContentUnavailableView` when no stores

**Test**: Launch app, see Overview with store cards. Click card, navigate to store. ✅

---

## Iteration 19e: Overview - Store Card Polish ✅

**Goal**: Store cards show useful status info.

- [x] Add recent changes count via `EventBadge` (shows 24h changes by type)
- [x] Empty state when no stores: `ContentUnavailableView` with "Add your first store"
- [x] Card styling with `.regularMaterial` background, subtle border, and shadow

**Deferred**:
- Sync status indicator on card
- Sync button on card
- Liquid Glass (`.glassEffect`) - using `.regularMaterial` for now

**Test**: Launch app, Overview shows store cards with event badges. Empty state shows add button. ✅

---

## Iteration 19f: Activity - Full Page with Filters ✅

**Goal**: Activity is a proper filterable view.

- [x] Create full `ActivityView` as sidebar destination (not sheet)
- [x] Add filter bar: Store dropdown (All / specific store), Type dropdown (All / Price / Stock / New)
- [x] Add date preset picker (Today / 7 days / 30 days / All)
- [x] Group events by date with section headers
- [x] Remove old toolbar button + sheet approach (was already sidebar destination)

**Implementation Notes**:
- `DateRange` enum with `.today`, `.week`, `.month`, `.all` cases
- `TypeFilter` enum grouping change types into Price/Stock/Product categories
- In-view filtering via computed properties (simpler than dynamic @Query)
- Events grouped by calendar day with "Today"/"Yesterday"/date headers
- Clear button appears when filters are active

**Test**: Navigate to Activity, filter by store, filter by type, see grouped results.

---

## Iteration 19g: Store Detail - Header Section ✅

**Goal**: Store detail view has a proper header.

- [x] Add header to `StoreDetailView`: store name, domain, product count
- [x] Show sync status and last sync time in header
- [x] Move Sync button into header (or keep in toolbar)
- [x] Add visual separation between header and product list

**Test**: Select store, see header with all info, sync button works. ✅

---

## Iteration 19h: ChangeType Icon & Color Standardization ✅

**Goal**: Consistent icons and colors for change events across views.

**Problem**: Icons and colors were inconsistent between `ActivityRow` and `StoreCard`:
- `priceDropped`: ActivityRow used `arrow.down.circle.fill`, StoreCard used `tag.fill`
- `backInStock`: ActivityRow used green, StoreCard used blue
- `newProduct`: ActivityRow used `sparkles`, StoreCard used `bag.badge.plus`

**Solution**:
- [x] Add `icon` and `color` computed properties to `ChangeType` enum
- [x] Update `ActivityRow` to use `event.changeType.icon` and `.color`
- [x] Update `StoreCard.EventBadge` to use `ChangeType.icon` and `.color`

**Standardized Icons**:
| ChangeType | Icon | Color | Rationale |
|------------|------|-------|-----------|
| `priceDropped` | `tag.fill` | green | Positive (savings) |
| `priceIncreased` | `tag.fill` | red | Negative (costs more) |
| `backInStock` | `shippingbox.fill` | blue | Availability info |
| `outOfStock` | `shippingbox.fill` | orange | Warning |
| `newProduct` | `bag.badge.plus` | purple | Discovery |
| `productRemoved` | `bag.badge.minus` | secondary | Neutral |

**Files**:
- `Models/ChangeEvent.swift` - Added extension with `icon` and `color`
- `Views/ActivityRow.swift` - Removed local icon/color logic
- `Views/StoreCard.swift` - Updated EventBadge calls

**Test**: ActivityView and StoreCard badges now use identical icons and colors.

---

## Iteration 19i: Comprehensive SwiftUI Previews ✅

**Goal**: Ensure all views have comprehensive previews covering each meaningful state.

- [x] `ActivityRow.swift` - 6 states: Price Dropped, Price Increased, Back In Stock, Out of Stock, New Product, Product Removed
- [x] `StoreCard.swift` - 4 states: Empty Store, With Products, With Price Drop Badge, With Back In Stock Badge
- [x] `StoreDetailView.swift` - 5 states: Empty Products, With Products, Rate Limited, ProductRow In Stock, ProductRow Out of Stock
- [x] `AddStoreSheet.swift` - 3 states: Empty Form, Loading State, Error State
- [x] `SidebarView.swift` - 3 states: Empty Stores, With Stores, With Store Selected
- [x] `SyncStatusView.swift` - 2 states: Waiting State, Ready State

**Pattern**: Follow `ActivityView.swift` pattern with `makePreviewContainer()` helper and inline sample data.

**Total**: 23 preview states across 6 files.

**Test**: Build succeeds, all previews render in Xcode. ✅

---

## Iteration 20: Product Grid ✅

**Goal**: Better product display.

- [x] Replace List with `LazyVGrid`
- [x] Create `ProductCard.swift`
- [x] Show image (AsyncImage), title, price
- [x] Basic styling (material, border, shadow, contentShape, accessibility)

**Test**: Products display in grid, images load.

---

## Iteration 21: Stock Badge ✅

**Goal**: See availability at a glance.

- [x] Green "In Stock" / Red "Out of Stock" - implemented inline in `ProductRow`
- [x] Created shared `Badge` component in `Views/Badge.swift`
- [x] Consolidated `StockBadge` and `EventBadge` into single `Badge(text:icon:color:)`
- [x] Updated `ProductCard` and `StoreCard` to use shared `Badge`

**Test**: Mix of in/out of stock products shows correctly. ✅

---

## Iteration 22: Price Change Indicator ✅

**Goal**: See recent changes on cards.

- [x] Create `PriceChangeIndicator.swift` - shows ↑/↓ arrow with amount
- [x] Add `Product.recentPriceChange` computed property (compares to last snapshot)
- [x] Colors standardized: use `ChangeType.priceDropped.color` (green) and `ChangeType.priceIncreased.color` (red)
- [x] Show ↓ green for drop, ↑ red for increase
- [x] Add to ProductCard
- [x] Add `priceChange: Decimal?` field to `ChangeEvent` model
- [x] Update `StoreService` to populate `priceChange` when creating events
- [x] Update `ActivityRow` to use `PriceChangeIndicator` (shows "$21.98 ↓$0.01")

**Test**: Product with price change shows indicator. Activity shows new format for new events. ✅

---

## Iteration 23: Product Detail View ✅

**Goal**: See full product info and all variants.

- [x] Create `ProductDetailView.swift` - hero image, metadata (title/vendor/type), variants list
- [x] Create `VariantRow.swift` - title, price, compareAtPrice strikethrough, savings badge, stock badge, SKU
- [x] Image carousel with thumbnail strip for multi-image products
- [x] Wrap `ProductCard` in `NavigationLink(value: product)`
- [x] Add `.navigationDestination(for: Product.self)` in `StoreDetailView`
- [x] Wrap `StoreDetailView` in `NavigationStack` in `ContentView`
- [x] Toolbar: ShareLink + Open in Browser button
- [x] Created `ProductImage` model for multiple images (to be simplified in 23a)
- [x] Updated `StoreService` to sync all images
- [x] 6 preview states (single/multi image, compareAtPrice, mixed stock, no image, long text)

**Test**: Tap product → detail view with image carousel, variants sorted, toolbar actions work. ✅

---

## Iteration 23a: Simplify ProductImage → imageURLs Array ✅

**Goal**: Replace separate `ProductImage` model with simple `[String]` array on Product.

- [x] Replace `images: [ProductImage]` relationship with `imageURLs: [String]`
- [x] Add `primaryImageURL` and `allImageURLs` computed properties
- [x] Delete `Models/ProductImage.swift`
- [x] Add `.imagesChanged` case to `ChangeType` enum
- [x] Update `StoreService` to use simple array assignment
- [x] Add image count change detection in `detectChanges()`
- [x] Update views and previews to use new properties

**Test**: Images display in carousel, image count changes trigger events.

---

## Iteration 24 & 25: Price History (List + Chart) ✅

**Goal**: See historical prices as list and chart.

- [x] Create `PriceHistoryChart.swift` with Swift Charts `LineMark`
- [x] Create `PriceHistoryRow.swift` for list items with change indicators
- [x] Create `PriceHistorySection.swift` combining chart and list
- [x] Add price history section to `ProductDetailView`
- [x] Handle empty state when no snapshots exist

**Test**: Chart and list render with real snapshot data.

---

## Iteration 25a: Price History & Variants Styling ✅

**Goal**: Visual consistency between price history and product sections.

- [x] Constrain `priceHistorySection` to `maxWidth: 1200` + centered
- [x] Remove gray material wrapper; give chart and table individual bordered containers
- [x] Style variants table with alternating rows + border (matches price history)
- [x] Center empty state with generous height
- [x] Chart uses `accentColor`, tertiary grid lines
- [x] Add design decision comments to code

**Test**: Price history aligns with product section, consistent table styling. ✅

---

## Iteration 26: Notification Grouping

**Goal**: Smarter notifications.

- [ ] Group changes by store
- [ ] Summarize: "3 price drops, 1 back in stock"
- [ ] Use `threadIdentifier` for grouping in NC

**Test**: Multiple changes → one grouped notification.

---

## Iteration 27: Notification Priority

**Goal**: Important changes stand out.

- [ ] High priority: large price drops, back in stock
- [ ] High → `.timeSensitive` + sound
- [ ] Low → `.passive`, no sound

**Test**: Big price drop makes sound, small change doesn't.

---

## Iteration 28: Mark as Read

**Goal**: Track what user has seen.

- [ ] Add `isRead` toggle to ChangeEvent
- [ ] Mark read when viewing Activity
- [ ] Show unread count in sidebar

**Test**: New changes show as unread, viewing marks read.

---

## Iteration 29: Menu Bar Extra (Basic)

**Goal**: Quick access without opening app.

- [ ] Add `MenuBarExtra` to app
- [ ] Show unread change count in icon
- [ ] List recent changes
- [ ] "Open App" and "Quit" buttons

**Test**: Menu bar icon appears, shows changes.

---

## Iteration 30: Liquid Glass - Cards

**Goal**: Apply glass styling.

- [ ] Add `.glassEffect()` to ProductCard
- [ ] Add hover state with `.interactive()`
- [ ] Test appearance

**Test**: Cards have glass effect, respond to hover.

---

## Iteration 31: Liquid Glass - Activity

**Goal**: Grouped glass in activity.

- [ ] Group events by date
- [ ] Use `.glassEffectUnion()` for same-day events
- [ ] Style date headers

**Test**: Activity has cohesive glass groups.

---

## Iteration 32: Liquid Glass - Toolbar

**Goal**: Glass toolbar buttons.

- [ ] Apply `.buttonStyle(.glass)` to toolbar buttons
- [ ] Verify appearance

**Test**: Toolbar looks cohesive.

---

## Iteration 33: Settings View

**Goal**: User preferences.

- [ ] Create `SettingsView.swift`
- [ ] Sync interval setting
- [ ] Notification preferences (on/off, sound)
- [ ] Use `@AppStorage` for persistence

**Test**: Change settings, verify they persist and take effect.

---

## Iteration 34: Search Products

**Goal**: Find products quickly.

- [ ] Add search bar to StoreDetailView
- [ ] Filter products by title
- [ ] Use `@Query` with dynamic predicate or filter in view

**Test**: Type query, products filter.

---

## Iteration 34a: Product Filters

**Goal**: Filter products by attributes.

- [ ] Add filter bar below search (or combined with search)
- [ ] Stock filter: All / In Stock / Out of Stock
- [ ] Sort picker: Name (A-Z) / Price (Low-High) / Price (High-Low) / Recently Added
- [ ] Price range filter (optional): Min/Max price inputs or preset ranges
- [ ] Clear filters button when filters active
- [ ] Persist filter state per store (or reset on navigation)

**Implementation Notes**:
- Follow pattern from `ActivityView` filter bar
- Use `Picker` with `.segmented` style for stock filter
- Use `Menu` for sort options
- Filter in view via computed property (simpler than dynamic `@Query`)

**Test**: Filter by stock status, sort by price, filters persist during session.

---

## Iteration 35: Snapshot Cleanup

**Goal**: Don't grow forever.

- [ ] Add cleanup function for snapshots > 90 days
- [ ] Run during sync
- [ ] Make retention period configurable in settings

**Test**: Old snapshots get deleted.

---

## Iteration 36: Error Handling Polish

**Goal**: User-friendly errors.

- [ ] Show alert on fetch failure
- [ ] Show inline error in store detail
- [ ] Retry option

**Test**: Disconnect network, sync, see friendly error.

---

## Iteration 37: Empty States

**Goal**: Guide new users.

- [ ] Empty state for no stores
- [ ] Empty state for no products (new store)
- [ ] Empty state for no activity

**Test**: Fresh install shows helpful empty states.

---

## Iteration 38: Keyboard Shortcuts

**Goal**: Power user efficiency.

- [ ] ⌘N → Add Store
- [ ] ⌘R → Sync All
- [ ] Add to Commands in app

**Test**: Shortcuts work.

---

## Iteration 39: Final Polish

**Goal**: Ship it.

- [ ] Accessibility audit (labels, contrast)
- [ ] Test with real stores
- [ ] Performance check with large store
- [ ] Fix any remaining bugs

**Test**: Use app for a week, note issues, fix.

---

## Summary

| Iterations | Theme |
|------------|-------|
| 1-5 | Project + Store CRUD |
| 6-10 | Shopify fetch + persist |
| 11-12 | Basic product display |
| 13-16 | Change detection + history |
| 17-19a | Notifications + background sync + rate limit UX |
| 19b-19i | Sidebar, Overview, Activity polish, Previews |
| 20-24 | Product UI polish |
| 25 | Charts |
| 26-28 | Notification improvements |
| 29 | Menu bar |
| 30-32 | Liquid Glass |
| 33-38 | Settings, search, polish |
| 39 | Ship |

Each iteration builds on the last. You always have a working app—just with fewer features.
