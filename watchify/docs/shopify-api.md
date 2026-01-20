# Shopify API

Public `/products.json` endpoint. No auth required.

## Endpoint

```
GET https://{store-domain}/products.json?limit=250
```

## Response Structure

```json
{
  "products": [
    {
      "id": 123456789,
      "title": "Example Product",
      "handle": "example-product",
      "vendor": "Brand",
      "product_type": "Shirts",
      "created_at": "2024-01-01T00:00:00-05:00",
      "images": [
        { "src": "https://cdn.shopify.com/..." }
      ],
      "variants": [
        {
          "id": 987654321,
          "title": "Small",
          "price": "29.99",
          "compare_at_price": "39.99",
          "sku": "EX-SM",
          "available": true
        }
      ]
    }
  ]
}
```

## ⚠️ Price is a String

Shopify returns `"price": "29.99"` not `"price": 29.99`.

Need custom decoding:

```swift
struct ShopifyVariant: Codable {
    let id: Int64
    let title: String
    let sku: String?
    let available: Bool
    
    // Decode string to Decimal
    let price: Decimal
    let compareAtPrice: Decimal?
    
    enum CodingKeys: String, CodingKey {
        case id, title, sku, available, price
        case compareAtPrice = "compare_at_price"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        sku = try container.decodeIfPresent(String.self, forKey: .sku)
        available = try container.decode(Bool.self, forKey: .available)
        
        // String -> Decimal
        let priceString = try container.decode(String.self, forKey: .price)
        price = Decimal(string: priceString) ?? 0
        
        if let compareString = try container.decodeIfPresent(String.self, forKey: .compareAtPrice) {
            compareAtPrice = Decimal(string: compareString)
        } else {
            compareAtPrice = nil
        }
    }
}
```

## Pagination

### ⚠️ `?page=N` is Deprecated

The spec shows `?page=1`, `?page=2`, etc. This is unreliable.

### Correct: Cursor-Based Pagination

Shopify uses `Link` header with `page_info` parameter:

```
Link: <https://store.myshopify.com/products.json?page_info=abc123&limit=250>; rel="next"
```

Implementation:

```swift
func fetchAllProducts(domain: String) async throws -> [ShopifyProduct] {
    var allProducts: [ShopifyProduct] = []
    var nextURL: URL? = URL(string: "https://\(domain)/products.json?limit=250")
    
    while let url = nextURL {
        let (data, response) = try await session.data(from: url)
        
        let result = try decoder.decode(ShopifyProductsResponse.self, from: data)
        allProducts.append(contentsOf: result.products)
        
        // Parse Link header for next page
        nextURL = parseNextPageURL(from: response)
    }
    
    return allProducts
}

func parseNextPageURL(from response: URLResponse) -> URL? {
    guard let httpResponse = response as? HTTPURLResponse,
          let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") else {
        return nil
    }
    
    // Parse: <URL>; rel="next"
    let pattern = #/<([^>]+)>;\s*rel="next"/#
    if let match = linkHeader.firstMatch(of: pattern) {
        return URL(string: String(match.1))
    }
    return nil
}
```

### Most Stores Don't Need Pagination

250 products per page. Only stores with 250+ products need multiple requests.

## DTOs

```swift
struct ShopifyProductsResponse: Codable {
    let products: [ShopifyProduct]
}

struct ShopifyProduct: Codable {
    let id: Int64
    let title: String
    let handle: String
    let vendor: String?
    let productType: String?
    let createdAt: Date?
    let images: [ShopifyImage]
    let variants: [ShopifyVariant]
    
    enum CodingKeys: String, CodingKey {
        case id, title, handle, vendor, images, variants
        case productType = "product_type"
        case createdAt = "created_at"
    }
}

struct ShopifyImage: Codable {
    let src: String
}

struct ShopifyVariant: Codable {
    // See custom decoding above for price handling
}
```

## Rate Limiting

Shopify doesn't publish rate limits for public endpoints, but be polite:

- 60 second minimum between fetches per store
- Don't hammer multiple stores simultaneously
- Back off on 429 responses

```swift
actor StoreService {
    private var lastFetchTimes: [UUID: Date] = [:]
    private let minimumFetchInterval: TimeInterval = 60
    
    func fetchProducts(for store: Store) async throws -> [ShopifyProduct] {
        if let lastFetch = lastFetchTimes[store.id],
           Date().timeIntervalSince(lastFetch) < minimumFetchInterval {
            throw StoreServiceError.rateLimited
        }
        // ... fetch ...
        lastFetchTimes[store.id] = Date()
    }
}
```
