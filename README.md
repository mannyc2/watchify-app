# Watchify

A native macOS app that monitors Shopify stores for price drops, restocks, and new products.

## Features

- **Price Tracking** — Get notified when prices drop (configurable thresholds: $5, $10, $25, or 10%, 25%)
- **Stock Alerts** — Know when sold-out items come back in stock
- **New Product Alerts** — See when stores add new products
- **Price History** — Charts showing price changes over time
- **Menu Bar Quick View** — See recent changes without opening the app
- **Keyboard Shortcuts** — Add Store (⌘N), Sync (⌘R), navigate stores (⌘1-9)
- **VoiceOver Accessible** — Full accessibility support

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 16+ (for building from source)

## Installation

```bash
git clone https://github.com/mannyc2/watchify-app.git
cd watchify-app
open watchify.xcodeproj
```

Build and run with ⌘R in Xcode.

## Usage

1. Click **Add Store** in the sidebar
2. Enter any Shopify store domain (e.g., `allbirds.com`, `gymshark.com`)
3. Watchify fetches all products and begins monitoring

Stores sync automatically in the background. Configure sync interval and notification preferences in **Settings** (⌘,).

## How It Works

Watchify uses Shopify's public `/products.json` endpoint available on all Shopify storefronts. No API keys or authentication required.

## Tech Stack

- SwiftUI + Liquid Glass design
- SwiftData for persistence
- Swift Charts for price history
- Swift Concurrency (actors) for thread safety

## License

MIT
