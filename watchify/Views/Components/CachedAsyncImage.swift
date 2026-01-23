//
//  CachedAsyncImage.swift
//  watchify
//

import NukeUI
import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let displaySize: ImageService.DisplaySize
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    init(
        url: URL?,
        displaySize: ImageService.DisplaySize = .fullSize,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.displaySize = displaySize
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                content(image)
            } else {
                placeholder()
            }
        }
        .pipeline(ImageService.pipeline)
        .processors(ImageService.processors(for: displaySize))
    }
}
