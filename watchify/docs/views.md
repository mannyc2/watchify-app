# Views

SwiftUI views with Liquid Glass design.

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
│               ├── StoreDetailView
│               │   └── ProductGrid
│               │       └── ProductCard (per product)
│               ├── ProductDetailView
│               │   ├── VariantRow
│               │   └── PriceHistorySection
│               │       ├── PriceHistoryChart
│               │       └── PriceHistoryRow
│               └── ActivityView
│                   └── ChangeEventRow (per event)
├── MenuBarExtra
│   └── MenuBarView
└── Settings
    └── SettingsView
        ├── GeneralSettingsTab
        ├── NotificationSettingsTab
        └── DataSettingsTab
```

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

Full-page activity view with filters and date grouping.

```swift
struct ActivityView: View {
    @Query(sort: \ChangeEvent.occurredAt, order: .reverse)
    private var allEvents: [ChangeEvent]

    @State private var selectedStore: Store?
    @State private var selectedType: TypeFilter = .all
    @State private var dateRange: DateRange = .all

    var body: some View {
        VStack(spacing: 0) {
            filterBar  // Store, Type, Date pickers + "Mark All Read" + "Clear"
            Divider()

            if filteredEvents.isEmpty {
                ContentUnavailableView("No Activity", ...)
            } else {
                List {
                    ForEach(groupedEvents, id: \.date) { group in
                        Section(header: Text(sectionHeader(for: group.date))) {
                            ForEach(group.events) { event in
                                ActivityRow(event: event)
                            }
                        }
                    }
                }
            }
        }
    }
}
```

**Features**:
- Filter by store, type (Price/Stock/Product), and date range (Today/7 Days/30 Days/All)
- "Mark All Read" button marks all filtered events as read
- Events grouped by date with "Today"/"Yesterday"/date headers

### MenuBarView

Quick access from menu bar. Uses `.menuBarExtraStyle(.window)` for rich content.

```swift
struct MenuBarView: View {
    @Query(filter: #Predicate<ChangeEvent> { !$0.isRead }, sort: \ChangeEvent.occurredAt, order: .reverse)
    private var unreadEvents: [ChangeEvent]

    @Query(sort: \ChangeEvent.occurredAt, order: .reverse)
    private var allEvents: [ChangeEvent]

    // Show unread if any, otherwise recent 10
    private var displayEvents: [ChangeEvent] {
        unreadEvents.isEmpty ? Array(allEvents.prefix(10)) : Array(unreadEvents.prefix(10))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Changes").font(.headline)
                Spacer()
                if !unreadEvents.isEmpty {
                    Button("Mark All Read") { markAllRead() }
                }
            }
            .padding()

            Divider()

            // Event list
            if displayEvents.isEmpty {
                ContentUnavailableView("No Changes Yet", ...)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayEvents) { event in
                            MenuBarEventRow(event: event)
                            Divider()
                        }
                    }
                }
            }

            Divider()

            // Action buttons
            HStack {
                Button("Open Watchify") { openWindow(id: "main") }
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding()
            .background(.regularMaterial)
        }
        .frame(width: 340, height: 400)
    }
}
```

### MenuBarEventRow

Compact event row optimized for menu bar display.

```swift
struct MenuBarEventRow: View {
    @Bindable var event: ChangeEvent

    var body: some View {
        HStack(spacing: 10) {
            Circle()  // Unread indicator
                .fill(event.isRead ? Color.clear : Color.accentColor)
                .frame(width: 6, height: 6)

            Image(systemName: event.changeType.icon)
                .foregroundStyle(event.changeType.color)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.productTitle)
                    .font(.subheadline.weight(.medium))
                if let priceChange = event.priceChange {
                    HStack { Text(event.newValue!); PriceChangeIndicator(change: priceChange) }
                } else if let desc = changeDescription {
                    Text(desc).font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()
            Text(event.occurredAt, format: .relative(presentation: .named))
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onAppear { if !event.isRead { event.isRead = true } }
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

Displays a single change event with read/unread tracking.

```swift
struct ActivityRow: View {
    @Bindable var event: ChangeEvent  // @Bindable for mutation

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
        .onAppear {
            if !event.isRead { event.isRead = true }
        }
    }
}
```

### SidebarView

Navigation sidebar with unread badge on Activity.

```swift
struct SidebarView: View {
    @Query(filter: #Predicate<ChangeEvent> { !$0.isRead })
    private var unreadEvents: [ChangeEvent]

    var body: some View {
        List(selection: $selection) {
            Label("Overview", systemImage: "square.grid.2x2")
            Label("Activity", systemImage: "clock.arrow.circlepath")
                .badge(unreadEvents.count)  // Shows count, hides at 0
            Section("Stores") { ... }
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

```
Views/
├── Sidebar/
│   ├── SidebarView.swift
│   └── StoreRow.swift
├── Store/
│   ├── StoreDetailView.swift
│   ├── ProductCard.swift
│   └── ProductGrid.swift
├── Product/
│   ├── ProductDetailView.swift
│   ├── VariantRow.swift
│   ├── PriceHistorySection.swift
│   ├── PriceHistoryChart.swift
│   ├── PriceHistoryRow.swift
│   └── PriceChangeIndicator.swift
├── Activity/
│   ├── ActivityView.swift
│   └── ChangeEventRow.swift
├── Settings/
│   ├── SettingsView.swift
│   ├── GeneralSettingsTab.swift
│   ├── NotificationSettingsTab.swift
│   └── DataSettingsTab.swift
├── MenuBar/
│   ├── MenuBarView.swift
│   └── MenuBarEventRow.swift
└── Components/
    ├── Badge.swift
    ├── GlassCard.swift
    └── EmptyStateView.swift
```
