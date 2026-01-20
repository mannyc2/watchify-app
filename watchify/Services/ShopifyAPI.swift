//
//  ShopifyAPI.swift
//  watchify
//

import Foundation

actor ShopifyAPI {
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
        var nextURL: URL? = URL(string: "https://\(domain)/products.json?limit=250")

        while let url = nextURL {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ShopifyAPIError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw ShopifyAPIError.httpError(statusCode: httpResponse.statusCode)
            }

            let result = try decoder.decode(ShopifyProductsResponse.self, from: data)
            allProducts.append(contentsOf: result.products)

            nextURL = parseNextPageURL(from: httpResponse)
        }

        return allProducts
    }

    private func parseNextPageURL(from response: HTTPURLResponse) -> URL? {
        guard let linkHeader = response.value(forHTTPHeaderField: "Link") else {
            return nil
        }

        let pattern = /<([^>]+)>;\s*rel="next"/
        if let match = linkHeader.firstMatch(of: pattern) {
            return URL(string: String(match.1))
        }
        return nil
    }
}

enum ShopifyAPIError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
}
