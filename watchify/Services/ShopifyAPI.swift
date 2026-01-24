//
//  ShopifyAPI.swift
//  watchify
//

import Foundation
import OSLog

protocol ShopifyAPIProtocol: Sendable {
    nonisolated func fetchProducts(domain: String) async throws -> [ShopifyProduct]
}

struct ShopifyAPI: ShopifyAPIProtocol {
    private let session: URLSession

    nonisolated init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
    }

    /// Fetches products from Shopify. Explicitly nonisolated to avoid MainActor hop
    /// when called from background ModelActor (with -default-isolation=MainActor).
    nonisolated func fetchProducts(domain: String) async throws -> [ShopifyProduct] {
        var allProducts: [ShopifyProduct] = []
        var page = 1

        while true {
            guard let url = URL(string: "https://\(domain)/products.json?limit=250&page=\(page)")
            else {
                throw ShopifyAPIError.invalidResponse
            }

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ShopifyAPIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw ShopifyAPIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let result = try decoder.decode(ShopifyProductsResponse.self, from: data)

            if result.products.isEmpty {
                break
            }

            allProducts.append(contentsOf: result.products)
            page += 1
        }

        return allProducts
    }
}

enum ShopifyAPIError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
}
