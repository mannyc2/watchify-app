//
//  ProductDetailView+Previews.swift
//  watchify
//

import SwiftData
import SwiftUI

// MARK: - Previews

#Preview("Single Image") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    let product = Product(
        shopifyId: 1,
        handle: "wool-runners",
        title: "Wool Runners",
        vendor: "Allbirds",
        productType: "Shoes"
    )
    product.store = store
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png"]
    container.mainContext.insert(product)

    let variant = Variant(shopifyId: 100, title: "Size 10 / Black", price: 110, available: true, position: 0)
    variant.product = product
    container.mainContext.insert(variant)

    return NavigationStack {
        ProductDetailView(product: product)
    }
    .modelContainer(container)
}

#Preview("Multiple Images") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    let product = Product(
        shopifyId: 2,
        handle: "tree-dashers",
        title: "Tree Dashers",
        vendor: "Allbirds",
        productType: "Running Shoes"
    )
    product.store = store
    let imageBase = "https://cdn.shopify.com/s/files/1/1104/4168/products"
    product.imageURLs = [
        "\(imageBase)/Tree_Dasher.png",
        "\(imageBase)/Wool_Runner.png",
        "\(imageBase)/Wool_Lounger.png"
    ]
    container.mainContext.insert(product)

    let sizes = [8, 9, 10, 11, 12]
    for (idx, size) in sizes.enumerated() {
        let variant = Variant(
            shopifyId: Int64(200 + idx),
            title: "Size \(size) / Black",
            sku: "TD-\(size)-BLK",
            price: 125,
            available: idx != 2,
            position: idx
        )
        variant.product = product
        container.mainContext.insert(variant)
    }

    return NavigationStack {
        ProductDetailView(product: product)
    }
    .modelContainer(container)
}

#Preview("With Compare Price") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    let product = Product(
        shopifyId: 3,
        handle: "wool-loungers-sale",
        title: "Wool Loungers - Sale",
        vendor: "Allbirds",
        productType: "Loungewear"
    )
    product.store = store
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Lounger.png"]
    container.mainContext.insert(product)

    let variants = [
        Variant(shopifyId: 301, title: "Size S", price: 75, compareAtPrice: 95, available: true, position: 0),
        Variant(shopifyId: 302, title: "Size M", price: 75, compareAtPrice: 95, available: true, position: 1),
        Variant(shopifyId: 303, title: "Size L", price: 80, compareAtPrice: 95, available: false, position: 2)
    ]

    variants.forEach {
        $0.product = product
        container.mainContext.insert($0)
    }

    return NavigationStack {
        ProductDetailView(product: product)
    }
    .modelContainer(container)
}

#Preview("Mixed Stock") {
    let container = makePreviewContainer()
    let store = Store(name: "Allbirds", domain: "allbirds.com")
    container.mainContext.insert(store)

    let product = Product(
        shopifyId: 4,
        handle: "tree-breezers",
        title: "Tree Breezers",
        vendor: "Allbirds",
        productType: "Flats"
    )
    product.store = store
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Tree_Breezer.png"]
    container.mainContext.insert(product)

    let variants: [(String, Bool)] = [
        ("Size 6 / Chalk", true),
        ("Size 7 / Chalk", false),
        ("Size 8 / Chalk", true),
        ("Size 9 / Chalk", false),
        ("Size 10 / Chalk", false)
    ]

    for (idx, (title, available)) in variants.enumerated() {
        let variant = Variant(shopifyId: Int64(400 + idx), title: title, price: 98, available: available, position: idx)
        variant.product = product
        container.mainContext.insert(variant)
    }

    return NavigationStack {
        ProductDetailView(product: product)
    }
    .modelContainer(container)
}

#Preview("No Image") {
    let container = makePreviewContainer()
    let store = Store(name: "Test Store", domain: "test.myshopify.com")
    container.mainContext.insert(store)

    let product = Product(
        shopifyId: 5,
        handle: "mystery-product",
        title: "Mystery Product",
        vendor: "Unknown Vendor",
        productType: "Unknown"
    )
    product.store = store
    container.mainContext.insert(product)

    let variant = Variant(shopifyId: 500, title: "Default", price: 49.99, available: true, position: 0)
    variant.product = product
    container.mainContext.insert(variant)

    return NavigationStack {
        ProductDetailView(product: product)
    }
    .modelContainer(container)
}

#Preview("Long Metadata") {
    let container = makePreviewContainer()
    let store = Store(name: "Fancy Store", domain: "fancy.myshopify.com")
    container.mainContext.insert(store)

    let product = Product(
        shopifyId: 6,
        handle: "super-long-product",
        title: "Men's Tree Runner Go - Limited Edition Collaboration with Famous Designer Collection 2024",
        vendor: "The Very Long Brand Name That Keeps Going And Going",
        productType: "Limited Edition Collaborative Running Shoes - Special Release"
    )
    product.store = store
    product.imageURLs = ["https://cdn.shopify.com/s/files/1/1104/4168/products/Wool_Runner.png"]
    container.mainContext.insert(product)

    let variant = Variant(
        shopifyId: 600,
        title: "Size 10 US / 43 EU / Black Carbon Limited Edition Colorway",
        sku: "TR-GO-LE-2024-BLK-CARBON-10US-43EU",
        price: 275,
        compareAtPrice: 350,
        available: true,
        position: 0
    )
    variant.product = product
    container.mainContext.insert(variant)

    return NavigationStack {
        ProductDetailView(product: product)
    }
    .modelContainer(container)
}
