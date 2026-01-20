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

## Iteration 13: Diff Detection

**Goal**: Detect what changed.

- [ ] Create `ProductDiff` struct
- [ ] Implement diff logic:
  - New products (in fetch, not in DB)
  - Removed products (in DB, not in fetch)
  - Updated products (price or availability changed)
- [ ] Return diff from save function

**Test**: Add product on Shopify, sync, diff shows it as new.

---

## Iteration 14: Data Model - ChangeEvent

**Goal**: Persist detected changes.

- [ ] Create `Models/ChangeEvent.swift`
- [ ] Fields: changeType, productTitle, variantTitle, oldValue, newValue, occurredAt, isRead
- [ ] Add relationship to Store
- [ ] Insert ChangeEvents when diff detected

**Test**: Sync detects change, ChangeEvent persisted.

---

## Iteration 15: Activity View (Basic)

**Goal**: See change history.

- [ ] Create `ActivityView.swift`
- [ ] `@Query` all ChangeEvents, sorted by date desc
- [ ] Simple list with type icon, product name, values
- [ ] Add "Activity" link to sidebar

**Test**: Make changes happen, see them in activity.

---

## Iteration 16: Data Model - Snapshots

**Goal**: Track historical values.

- [ ] Create `Models/VariantSnapshot.swift`
- [ ] Fields: capturedAt, price, compareAtPrice, available
- [ ] Relationship to Variant
- [ ] Create snapshot when variant values change
- [ ] (Skip ProductSnapshot for now—variant is what matters)

**Test**: Price changes twice, two snapshots exist.

---

## Iteration 17: Local Notifications (Basic)

**Goal**: Get notified of changes.

- [ ] Create `Services/NotificationService.swift`
- [ ] Request permission on first launch
- [ ] Send notification when changes detected
- [ ] Simple: one notification per sync with change count

**Test**: Sync finds changes, notification appears.

---

## Iteration 18: Background Sync Timer

**Goal**: Auto-sync periodically.

- [ ] Create `Services/SyncScheduler.swift`
- [ ] Start timer on app launch (60 min default)
- [ ] Sync all stores when timer fires
- [ ] Track `isSyncing` to prevent overlap

**Test**: Set timer to 1 min for testing, see auto-syncs.

---

## Iteration 19: Rate Limiting

**Goal**: Be polite to Shopify.

- [ ] Track last fetch time per store
- [ ] Enforce 60s minimum between fetches
- [ ] Return error if rate limited (don't just skip silently)

**Test**: Spam sync button, get rate limit feedback.

---

## Iteration 20: Product Grid

**Goal**: Better product display.

- [ ] Replace List with `LazyVGrid`
- [ ] Create `ProductCard.swift`
- [ ] Show image (AsyncImage), title, price
- [ ] Basic styling

**Test**: Products display in grid, images load.

---

## Iteration 21: Stock Badge

**Goal**: See availability at a glance.

- [ ] Create `StockBadge.swift`
- [ ] Green "In Stock" / Red "Out of Stock"
- [ ] Add to ProductCard

**Test**: Mix of in/out of stock products shows correctly.

---

## Iteration 22: Price Change Indicator

**Goal**: See recent changes on cards.

- [ ] Create `PriceChangeIndicator.swift`
- [ ] Compare current price to last snapshot
- [ ] Show ↓ green for drop, ↑ red for increase
- [ ] Add to ProductCard

**Test**: Product with price change shows indicator.

---

## Iteration 23: Product Detail View

**Goal**: See full product info.

- [ ] Create `ProductDetailView.swift`
- [ ] Show all variants with prices
- [ ] Show product metadata
- [ ] Navigate from ProductCard tap

**Test**: Tap product, see detail.

---

## Iteration 24: Price History (List)

**Goal**: See historical prices.

- [ ] In ProductDetailView, list variant snapshots
- [ ] Show date + price for each
- [ ] Sorted by date

**Test**: Product with history shows past prices.

---

## Iteration 25: Price History (Chart)

**Goal**: Visualize price over time.

- [ ] Create `PriceHistoryChart.swift`
- [ ] Use Swift Charts `LineMark`
- [ ] Add to ProductDetailView
- [ ] Handle empty state

**Test**: Chart renders with real data.

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
| 17-19 | Notifications + background sync |
| 20-24 | Product UI polish |
| 25 | Charts |
| 26-28 | Notification improvements |
| 29 | Menu bar |
| 30-32 | Liquid Glass |
| 33-38 | Settings, search, polish |
| 39 | Ship |

Each iteration builds on the last. You always have a working app—just with fewer features.
