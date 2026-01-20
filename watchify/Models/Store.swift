//
//  Store.swift
//  watchify
//

import Foundation
import SwiftData

@Model
final class Store {
    @Attribute(.unique) var id: UUID
    var name: String
    var domain: String
    var addedAt: Date
    var lastFetchedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Product.store)
    var products: [Product] = []

    @Relationship(deleteRule: .cascade, inverse: \ChangeEvent.store)
    var changeEvents: [ChangeEvent] = []

    init(id: UUID = UUID(), name: String, domain: String, addedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.domain = domain
        self.addedAt = addedAt
    }
}
