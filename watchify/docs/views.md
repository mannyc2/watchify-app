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

Grouped by date with glass union effect.

```swift
struct ActivityView: View {
    @Query(sort: \ChangeEvent.occurredAt, order: .reverse)
    var changes: [ChangeEvent]
    @Namespace private var namespace
    
    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(groupedByDate(changes), id: \.date) { group in
                    Text(group.date, style: .date)
                    
                    ForEach(group.events) { event in
                        ChangeEventRow(event: event)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                            .glassEffectUnion(id: group.date.description, namespace: namespace)
                    }
                }
            }
        }
    }
}
```

### MenuBarView

Quick access from menu bar.

```swift
struct MenuBarView: View {
    @Query(filter: #Predicate<ChangeEvent> { !$0.isRead }, ...)
    var recentChanges: [ChangeEvent]
    
    var body: some View {
        VStack {
            Text("Recent Changes")
            
            if recentChanges.isEmpty {
                ContentUnavailableView("No Changes", ...)
            } else {
                ForEach(recentChanges.prefix(10)) { change in
                    ChangeEventRow(event: change, isCompact: true)
                }
            }
            
            HStack {
                Button("Open App") { ... }
                Button("Mark All Read") { ... }
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .frame(width: 350)
    }
}
```

## Components

| Component | Purpose |
|-----------|---------|
| `StoreRow` | Sidebar row for a store |
| `OverviewView` | Grid of store cards with adaptive layout |
| `StoreCard` | Overview card showing name, product count, preview images, event badges |
| `ProductCard` | Grid card for a product |
| `PriceChangeIndicator` | Arrow + amount showing price change (↓$15 green, ↑$10 red) |
| `Badge` | Reusable capsule badge with optional icon (stock status, event counts, etc.) |
| `ActivityRow` | Activity feed row |
| `GlassCard` | Reusable glass wrapper |

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
│   └── SettingsView.swift
├── MenuBar/
│   └── MenuBarView.swift
└── Components/
    ├── Badge.swift
    ├── GlassCard.swift
    └── EmptyStateView.swift
```
