# Tasks

Remaining work for Watchify MVP. Completed tasks are in [CHANGELOG.md](CHANGELOG.md).

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

## Workflow

When completing a task:

1. Mark all checklist items as `[x]`
2. Add `✅` to the iteration heading
3. Move the entire iteration block to `changelog.md` under the appropriate date
4. Use Keep a Changelog categories: Added, Changed, Fixed, Removed
5. Keep changelog entries concise (1-2 lines per item)

Example changelog entry:
```markdown
## 2025-01-23

### Added
- Snapshot cleanup with configurable retention period

### Fixed
- Old snapshots now deleted during sync
```
