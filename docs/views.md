# Views

SwiftUI views with Liquid Glass design. Complex views use ViewModels for state management and communicate with StoreService via DTOs.

## Architecture

```
View (@MainActor)
  └── ViewModel (@MainActor, @Observable)
      └── StoreService (actor)
          └── Returns DTOs (Sendable)
```

All views that fetch data use ViewModels. No views use `@Query` directly to avoid main-thread hangs during sync.

## Layout

```
┌─────────────────────────────────────────────────┐
│  Watchify                          [+] [⚙️]    │
├────────────┬────────────────────────────────────┤
│  Sidebar   │  Detail                            │
│            │                                    │
│  Stores    │  (varies by selection)             │
│  • Store A │                                    │
│  • Store B │                                    │
│  ────────  │                                    │
│  Activity  │                                    │
├────────────┴────────────────────────────────────┤
│  Status bar                                     │
└─────────────────────────────────────────────────┘

+ Menu bar extra (separate window)
```

## View Hierarchy

```
WatchifyApp
├── WindowGroup
│   └── ContentView
│       └── NavigationSplitView
│           ├── SidebarView
│           │   ├── StoreRow (per store)
│           │   └── "Activity" link
│           └── Detail
│               ├── OverviewView
│               │   └── StoreCard (per store)
│               ├── StoreDetailView + StoreDetailViewModel
│               │   └── ProductGrid
│               │       └── ProductCardDTO (per product)
│               ├── ProductDetailView
│               │   ├── VariantRow
│               │   └── PriceHistorySection
│               │       ├── PriceHistoryChart
│               │       └── PriceHistoryRow
│               └── ActivityView + ActivityViewModel
│                   └── ActivityRowDTO (per event)
├── MenuBarExtra
│   └── MenuBarView + MenuBarViewModel
│       └── MenuBarEventRowDTO (per event)
└── Settings
    └── SettingsView
        ├── GeneralSettingsTab
        ├── NotificationSettingsTab
        └── DataSettingsTab
```

## ViewModels

ViewModels are `@MainActor @Observable` classes that manage state for views. They communicate with `StoreService` (a background actor) via DTOs, using `Task.detached` to avoid deadlocks.

### StoreListViewModel

Shared ViewModel for ContentView, SidebarView, and OverviewView. Manages store list and unread count.

```swift
@MainActor @Observable
final class StoreListViewModel {
    private(set) var stores: [StoreDTO] = []
    private(set) var unreadCount: Int = 0

    func configure()           // Sets up notification observer
    func loadInitial() async
    func refresh() async
    func deleteStore(id:) async
}
```

### StoreDetailViewModel

Manages product list, filters, and sync for `StoreDetailView`.

```swift
@MainActor @Observable
final class StoreDetailViewModel {
    // State
    private(set) var products: [ProductDTO] = []
    private(set) var isLoading = false
    var searchText: String
    var stockScope: StockScope
    var sortOrder: ProductSort

    // Store metadata
    let storeId: UUID
    private(set) var storeName: String
    private(set) var isSyncing: Bool

    // Actions
    func loadInitial() async
    func fetchProducts() async
    func sync() async
}
```

### ActivityViewModel

Manages event list with filtering, grouping, and mark-read for `ActivityView`.

```swift
@MainActor @Observable
final class ActivityViewModel {
    // State
    private(set) var events: [ChangeEventDTO] = []
    private(set) var listItems: [ActivityListItem] = []  // Flattened: headers + events
    var selectedStoreId: UUID?
    var selectedType: TypeFilter
    var dateRange: DateRange

    // Actions
    func loadInitial() async
    func fetchEvents(reset:) async
    func markEventRead(id:)
    func markAllRead()
}
```

### MenuBarViewModel

Manages recent/unread events for `MenuBarView`.

```swift
@MainActor @Observable
final class MenuBarViewModel {
    private(set) var events: [ChangeEventDTO] = []
    private(set) var unreadCount: Int = 0

    func loadEvents() async
    func markAllRead() async
}
```

### Why ViewModels?

1. **Actor isolation**: Views are `@MainActor`, but `StoreService` is a background actor. ViewModels bridge the gap.
2. **State management**: Complex filtering, sorting, and grouping logic lives in ViewModels, not views.
3. **DTOs**: ViewModels receive `Sendable` DTOs from StoreService, avoiding `@Model` observation overhead.
4. **Testability**: ViewModels can be unit tested without SwiftUI.

## Key Views

### ContentView

Main container. NavigationSplitView with toolbar.

```swift
struct ContentView: View {
    @State private var selectedStore: Store?
    @State private var showingAddStore = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedStore: $selectedStore)
        } detail: {
            // Show store detail or empty state
        }
        .toolbar {
            Button { } label: { Label("Add Store", systemImage: "plus") }
                .buttonStyle(.glass)
            Button { } label: { Label("Sync Now", systemImage: "arrow.clockwise") }
                .buttonStyle(.glass)
        }
    }
}
```

### ProductCard

Glass card with hover interaction.

```swift
struct ProductCard: View {
    let product: Product
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: product.imageURL) { ... }
            Text(product.title)
            HStack {
                Text(product.currentPrice, format: .currency(code: "USD"))
                if let change = product.recentPriceChange {
                    PriceChangeIndicator(change: change)
                }
                Spacer()
                Badge(
                    text: product.isAvailable ? "In Stock" : "Out",
                    color: product.isAvailable ? .green : .red
                )
            }
        }
        .padding()
        .glassEffect(
            isHovering ? .regular.interactive().tint(.blue.opacity(0.2)) : .regular,
            in: .rect(cornerRadius: 16)
        )
        .onHover { isHovering = $0 }
    }
}
```

### PriceHistoryChart

Swift Charts with glass background.

```swift
struct PriceHistoryChart: View {
    let variant: Variant

    var body: some View {
        Chart {
            ForEach(variant.snapshots.sorted(by: { $0.capturedAt < $1.capturedAt }), id: \.capturedAt) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.capturedAt),
                    y: .value("Price", snapshot.price)
                )
                .foregroundStyle(.blue.gradient)

                AreaMark(...)
                    .foregroundStyle(.blue.opacity(0.1).gradient)
            }
        }
        .chartYAxis { ... }
        .chartXAxis { ... }
        .frame(height: 300)
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}
```

### ActivityView

Full-page activity view with filters and date grouping. Uses `ActivityViewModel`.

```swift
struct ActivityView: View {
    @State private var viewModel: ActivityViewModel?

    var body: some View {
        Group {
            if let viewModel {
                ActivityContentView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let activityVM = ActivityViewModel()
                viewModel = activityVM
                await activityVM.loadInitial()
            }
        }
    }
}
```

**Features**:
- Filter by store, type (Price/Stock/Product), and date range (Today/7 Days/30 Days/All)
- "Mark All Read" button marks all filtered events as read
- Events grouped by date with "Today"/"Yesterday"/date headers
- Infinite scroll with pagination

### MenuBarView

Quick access from menu bar. Uses `.menuBarExtraStyle(.window)` for rich content and `MenuBarViewModel`.

```swift
struct MenuBarView: View {
    @State private var viewModel: MenuBarViewModel?

    var body: some View {
        Group {
            if let viewModel {
                MenuBarContentView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let menuBarVM = MenuBarViewModel()
                viewModel = menuBarVM
                await menuBarVM.loadEvents()
            }
        }
    }
}
```

**Features**:
- Shows unread events if any, otherwise recent 10
- "Mark All Read" button
- "Open Watchify" and "Quit" actions
- Fixed 340x400 window size

### MenuBarEventRow

Compact event row optimized for menu bar display. Uses `ChangeEventDTO` (Sendable).

```swift
struct MenuBarEventRowDTO: View {
    let event: ChangeEventDTO
    let onMarkRead: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()  // Unread indicator
                .fill(event.isRead ? Color.clear : Color.accentColor)
                .frame(width: 6, height: 6)

            Image(systemName: event.changeType.icon)
                .foregroundStyle(event.changeType.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.productTitle)
                if let priceChange = event.priceChange {
                    HStack { Text(event.newValue ?? ""); PriceChangeIndicator(change: priceChange) }
                }
            }

            Spacer()
            Text(event.occurredAt, format: .relative(presentation: .named))
        }
        .onAppear { if !event.isRead { onMarkRead() } }
    }
}
```

### SettingsView

Standard macOS Settings window (⌘,) with three tabs.

```swift
struct SettingsView: View {
    @AppStorage("selectedSettingsTab") private var selectedTab = SettingsTab.general.rawValue

    var body: some View {
        TabView(selection: ...) {
            Tab("General", systemImage: "gear", value: .general) {
                GeneralSettingsTab()
            }
            Tab("Notifications", systemImage: "bell", value: .notifications) {
                NotificationSettingsTab()
            }
            Tab("Data", systemImage: "externaldrive", value: .data) {
                DataSettingsTab()
            }
        }
        .scenePadding()
        .frame(maxWidth: 450, minHeight: 250)
    }
}
```

**Tabs**:

| Tab | Settings |
|-----|----------|
| General | Sync interval (preset picker + custom with TextField/Stepper) |
| Notifications | Master toggle + per-change-type toggles (7 types) + price thresholds |
| Data | Auto-delete old events (configurable days) + "Clear All Events" |

**Notifications Tab Details**:
- Master toggle to enable/disable all notifications
- Per-change-type toggles (price drops, increases, back in stock, etc.)
- **Price thresholds**: Minimum drop/increase pickers appear below price toggles
  - Options: Any amount, At least $5/$10/$25, At least 10%/25%
  - Separate thresholds for drops vs increases

**Storage**: All settings use `@AppStorage` for persistence.

## Components

| Component | Purpose |
|-----------|---------|
| `StoreRow` | Sidebar row for a store |
| `OverviewView` | Grid of store cards with adaptive layout |
| `StoreCard` | Overview card showing name, product count, preview images, event badges |
| `ProductCard` | Grid card for a product |
| `PriceChangeIndicator` | Arrow + amount showing price change (↓$15 green, ↑$10 red) |
| `Badge` | Reusable capsule badge with optional icon (stock status, event counts, etc.) |
| `ActivityRow` | Activity feed row with unread indicator (blue dot), marks read on appear |
| `GlassCard` | Reusable glass wrapper |

### ActivityRow

Displays a single change event with read/unread tracking. Uses `ChangeEventDTO` (Sendable).

```swift
struct ActivityRowDTO: View {
    let event: ChangeEventDTO
    let onMarkRead: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()  // Unread indicator (blue dot)
                .fill(event.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)

            Image(systemName: event.changeType.icon)
                .foregroundStyle(event.changeType.color)

            VStack(alignment: .leading) {
                Text(event.productTitle)
                // ... variant, price change details
            }

            Spacer()
            Text(event.occurredAt, format: .relative(presentation: .named))
        }
        .onAppear { if !event.isRead { onMarkRead() } }
    }
}
```

### SidebarView

Navigation sidebar with unread badge on Activity. Uses shared `StoreListViewModel`.

```swift
struct SidebarView: View {
    @Bindable var viewModel: StoreListViewModel
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            Label("Overview", systemImage: "square.grid.2x2")
            Label("Activity", systemImage: "clock.arrow.circlepath")
                .badge(viewModel.unreadCount)  // Shows count, hides at 0
            Section("Stores") {
                ForEach(viewModel.stores) { store in
                    StoreRow(store: store)
                }
            }
        }
    }
}
```

## ChangeType Icons & Colors

Standardized via `ChangeType.icon` and `ChangeType.color` (see [data-model.md](data-model.md)):

| ChangeType | Icon | Color | Rationale |
|------------|------|-------|-----------|
| `priceDropped` | `tag.fill` | green | Positive for user (savings) |
| `priceIncreased` | `tag.fill` | red | Negative for user (costs more) |
| `backInStock` | `shippingbox.fill` | blue | Informational, availability |
| `outOfStock` | `shippingbox.fill` | orange | Warning, not available |
| `newProduct` | `bag.badge.plus` | purple | Discovery, something new |
| `productRemoved` | `bag.badge.minus` | secondary | Neutral, just informational |

Used by `ActivityRow`, `StoreCard`, and `ProductCard` via the shared `Badge` component.

## Liquid Glass Usage

| Effect | When to Use |
|--------|-------------|
| `.glassEffect(.regular, in: shape)` | Static glass backgrounds |
| `.glassEffect(.regular.interactive(), ...)` | Hover/tap feedback |
| `.glassEffect(...).tint(color)` | Colored glass |
| `.glassEffectUnion(id:namespace:)` | Group adjacent glass elements |
| `.buttonStyle(.glass)` | Toolbar buttons |

## File Structure

### Organization Principles

1. **Group by feature/domain** - Co-locate related views for easier navigation
2. **Components are generic** - Reusable pieces that aren't domain-specific go in `Components/`
3. **DTOs stay with their views** - `ProductCardDTO` lives alongside `ProductCard`
4. **Flat is fine for small groups** - Aim for 4-6 files per folder; don't over-nest
5. **Preview files stay with source** - `*+Previews.swift` files live next to the view they preview

### Folder Structure

```
ViewModels/
├── ActivityViewModel.swift
├── MenuBarViewModel.swift
├── StoreDetailViewModel.swift
└── StoreListViewModel.swift

Views/
├── Activity/                    # Activity feed feature
│   ├── ActivityRow.swift
│   └── ActivityView.swift
│
├── Components/                  # Reusable UI primitives
│   ├── Badge.swift
│   ├── GlassTheme.swift
│   ├── PriceChangeIndicator.swift
│   └── SyncStatusView.swift
│
├── MenuBar/                     # Menu bar extra
│   ├── MenuBarEventRow.swift
│   └── MenuBarView.swift
│
├── Product/                     # Product-related views
│   ├── PriceHistoryChart.swift
│   ├── PriceHistoryRow.swift
│   ├── PriceHistorySection.swift
│   ├── ProductCard.swift
│   ├── ProductCardDTO.swift
│   ├── ProductDetailView.swift
│   ├── ProductDetailView+Previews.swift
│   ├── ProductImageCarousel.swift
│   └── VariantRow.swift
│
├── Settings/                    # Settings window
│   ├── DataSettingsTab.swift
│   ├── GeneralSettingsTab.swift
│   ├── NotificationSettingsTab.swift
│   └── SettingsView.swift
│
├── Store/                       # Store-related views
│   ├── AddStoreSheet.swift
│   ├── StoreCard.swift
│   ├── StoreDetailView.swift
│   └── StoreRow.swift
│
├── ContentView.swift            # App shell (NavigationSplitView)
├── OverviewView.swift           # Top-level screen
└── SidebarView.swift            # Navigation sidebar

DTOs/
├── ChangeEventDTO.swift
├── ProductDTO.swift
└── StoreDTO.swift
```

### Conventions

| Convention | Rationale |
|------------|-----------|
| Feature folders are **singular** (`Product/`, not `Products/`) | Matches Swift naming conventions |
| **One view per file** | Easier to navigate; exceptions for tiny private helpers |
| **DTO suffix** for display-only structs | Distinguishes from @Model types |
| **+Previews suffix** for preview-only files | Keeps previews separate when they're large |
| Top-level screens can stay at root | `ContentView`, `OverviewView`, `SidebarView` don't need folders |
| `watchifyApp.swift` stays at project root | App entry point, not a view |

### When to Create a New Folder

Create a new feature folder when:
- You have **3+ related views** for a domain
- The views share common types or logic
- The feature is distinct enough to warrant isolation

Don't create a folder for:
- A single view with no related components
- Generic components (use `Components/` instead)
- Views that span multiple domains (keep at root or in most relevant folder)

### Adding New Views

1. **Identify the domain**: Does it belong to Store, Product, Activity, etc.?
2. **Check existing folders**: Add to an existing folder if it fits
3. **Create folder if needed**: Only when you have 3+ related files
4. **Include DTOs with views**: Keep `FooDTO.swift` next to `Foo.swift`
5. **Update this doc**: Keep the file structure section current
