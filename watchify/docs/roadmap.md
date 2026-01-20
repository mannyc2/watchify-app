# Roadmap

## Phase 1: Core (2-3 weeks)

Get it working end-to-end.

### Must Have

- [ ] Add/remove stores
- [ ] Fetch `/products.json` with proper pagination
- [ ] Display products in grid
- [ ] Diff and detect changes
- [ ] Create snapshots on change
- [ ] Persist ChangeEvents
- [ ] Show Activity feed
- [ ] Local notifications (basic)
- [ ] Background sync timer

### Deferred

- Charts (use simple list for now)
- Menu bar extra
- Liquid Glass polish
- Smart notification grouping

### Blockers to Resolve

1. **Actor isolation**: Decide on architecture (actor returns data vs `@MainActor` service)
2. **Price decoding**: Implement custom `Codable` for string prices
3. **Pagination**: Implement `Link` header parsing

### Deliverable

App that can track 1-2 stores and notify on price/stock changes.

---

## Phase 2: Polish (1-2 weeks)

Make it nice.

### Features

- [ ] Swift Charts price history
- [ ] Menu bar extra with recent changes
- [ ] Liquid Glass styling throughout
- [ ] Search/filter products
- [ ] Smart notification grouping by store/priority
- [ ] Keyboard shortcuts (⌘N add, ⌘R sync)
- [ ] Snapshot retention cleanup (90 days)

### Quality

- [ ] Error handling and user feedback
- [ ] Loading states
- [ ] Empty states
- [ ] Accessibility audit

### Deliverable

Polished app ready for daily use.

---

## Phase 3: Advanced (3-4 weeks)

If there's interest.

### Features

- [ ] iOS companion app
- [ ] iCloud sync (SwiftData + CloudKit)
- [ ] WidgetKit widgets
- [ ] Custom alert rules ("notify if >20% drop")
- [ ] Product favoriting/watchlists
- [ ] Export to CSV/JSON
- [ ] Spotlight integration

### Speculative

- Live Activities (iOS)
- Price prediction
- Multi-user/sharing

---

## File Structure Target

```
Watchify/
├── App/
│   ├── WatchifyApp.swift
│   └── ContentView.swift
├── Models/
│   ├── Store.swift
│   ├── Product.swift
│   ├── Variant.swift
│   ├── Snapshots.swift
│   └── ChangeEvent.swift
├── Services/
│   ├── StoreService.swift
│   ├── SyncScheduler.swift
│   └── NotificationService.swift
├── DTOs/
│   └── ShopifyProduct.swift
├── Views/
│   ├── Sidebar/
│   ├── Store/
│   ├── Product/
│   ├── Activity/
│   ├── Settings/
│   ├── MenuBar/
│   └── Components/
└── Utilities/
```

---

## Definition of Done

### Phase 1
- Can add a store by domain
- Products appear after first sync
- Changes detected on subsequent syncs
- Notifications delivered
- Activity shows history

### Phase 2
- Price charts render
- Menu bar shows unread changes
- App feels polished and responsive
- No obvious bugs

### Phase 3
- Works on iPhone
- Syncs via iCloud
- Widgets show recent changes
