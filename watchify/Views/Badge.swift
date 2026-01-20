//
//  Badge.swift
//  watchify
//

import SwiftUI

struct Badge: View {
    let text: String
    var icon: String?
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
    }
}

// MARK: - Previews

#Preview("Text Only") {
    Badge(text: "In Stock", color: .green)
        .padding()
}

#Preview("With Icon") {
    Badge(text: "3", icon: "tag.fill", color: .green)
        .padding()
}

#Preview("Various Colors") {
    HStack(spacing: 8) {
        Badge(text: "In Stock", color: .green)
        Badge(text: "Out", color: .red)
        Badge(text: "2", icon: "shippingbox.fill", color: .blue)
        Badge(text: "New", icon: "bag.badge.plus", color: .purple)
    }
    .padding()
}
