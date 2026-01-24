//
//  StoreListViewModel.swift
//  watchify
//

import CoreData
import Foundation

/// ViewModel for ContentView, SidebarView, and OverviewView.
/// Replaces @Query to avoid main thread hangs during sync.
@MainActor @Observable
final class StoreListViewModel {
    // MARK: - Published State

    private(set) var stores: [StoreDTO] = []
    private(set) var unreadCount: Int = 0
    private(set) var isLoading = false

    // MARK: - Private

    private var refreshTask: Task<Void, Never>?
    private nonisolated(unsafe) var observer: (any NSObjectProtocol)?
    private let isPreview: Bool

    // MARK: - Initializers

    init() {
        self.isPreview = false
    }

    /// Preview initializer with pre-populated data
    init(previewStores: [StoreDTO], previewUnreadCount: Int = 0) {
        self.isPreview = true
        self.stores = previewStores
        self.unreadCount = previewUnreadCount
    }

    // MARK: - Public Methods

    func store(byId id: UUID) -> StoreDTO? {
        stores.first { $0.id == id }
    }

    func configure() {
        guard !isPreview else { return }

        // CRITICAL: Use Task.detached to ensure the StoreService call happens
        // on a background thread, not main. SwiftData's ModelActor executor
        // uses performBlockAndWait when enqueueing, which can deadlock if
        // called from main thread while the actor is saving.
        Task.detached {
            let (stores, unread) = await (
                StoreService.shared.fetchStoresForList(),
                StoreService.shared.fetchUnreadCount()
            )
            await MainActor.run { [weak self] in
                self?.stores = stores
                self?.unreadCount = unread
                self?.isLoading = false
            }
        }
        isLoading = true

        // Observe DB saves for refresh (debounced)
        // CRITICAL: Use queue: nil to receive on posting thread, then async to main
        // to break the synchronous notification chain and avoid deadlock.
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil  // Receive on posting thread, not main
        ) { [weak self] _ in
            // Break out of notification delivery before touching actors
            DispatchQueue.main.async {
                Task { @MainActor [weak self] in
                    self?.refreshDebounced()
                }
            }
        }
    }

    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }

        async let storesTask = StoreService.shared.fetchStoresForList()
        async let unreadTask = StoreService.shared.fetchUnreadCount()

        stores = await storesTask
        unreadCount = await unreadTask
    }

    func refresh() async {
        // CRITICAL: Fetch on detached task to avoid main thread blocking.
        // SwiftData's ModelActor executor deadlocks if main thread awaits
        // while the actor is in a blocking save operation.
        let (newStores, newUnread) = await Task.detached {
            await (
                StoreService.shared.fetchStoresForList(),
                StoreService.shared.fetchUnreadCount()
            )
        }.value

        stores = newStores
        unreadCount = newUnread
    }

    func deleteStore(id: UUID) async {
        // Optimistic update
        stores.removeAll { $0.id == id }

        await StoreService.shared.deleteStore(id: id)
    }

    // MARK: - Private Methods

    private func refreshDebounced() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    deinit {
        MainActor.assumeIsolated {
            if let observer = self.observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
