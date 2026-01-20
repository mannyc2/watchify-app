//
//  ShopifyAPI.swift
//  watchify
//

import Foundation

protocol ShopifyAPIProtocol: Sendable {
    func fetchProducts(domain: String) async throws -> [ShopifyProduct]
}

actor ShopifyAPI: ShopifyAPIProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func fetchProducts(domain: String) async throws -> [ShopifyProduct] {
        var allProducts: [ShopifyProduct] = []
        var page = 1

        while true {
            guard let url = URL(string: "https://\(domain)/products.json?limit=250&page=\(page)") else {
                throw ShopifyAPIError.invalidResponse
            }

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ShopifyAPIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw ShopifyAPIError.httpError(statusCode: httpResponse.statusCode)
            }

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
