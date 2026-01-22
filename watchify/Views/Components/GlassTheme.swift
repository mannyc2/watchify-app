//
//  GlassTheme.swift
//  watchify
//
//  Liquid Glass styling extensions for macOS 26.
//
//  Per Apple guidance:
//  - Apply glass as a BACKGROUND surface, not directly to content
//  - Use compositingGroup() to isolate content from glass vibrancy
//  - Use GlassEffectContainer only for small clusters (badges, controls)
//  - Add manual hover states for cards
//

import SwiftUI

// MARK: - Glass Surface (Background Pattern)

extension View {
    /// Applies glass as a background surface. Content stays unaffected by vibrancy.
    func glassSurface<S: Shape>(_ glass: Glass = .regular, in shape: S) -> some View {
        compositingGroup()
            .background { Color.clear.glassEffect(glass, in: shape) }
    }

    /// Applies interactive glass surface (responds to press).
    func interactiveGlassSurface<S: Shape>(in shape: S) -> some View {
        compositingGroup()
            .background { Color.clear.glassEffect(.regular.interactive(), in: shape) }
    }

    /// Applies interactive glass surface with rounded rectangle.
    func interactiveGlassSurface(cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return compositingGroup()
            .background { Color.clear.glassEffect(.regular.interactive(), in: shape) }
    }
}

// MARK: - Glass Pill (for badges, small elements)

extension View {
    /// Applies glass pill effect. Good for badges and small labels.
    func glassPill(_ glass: Glass = .regular) -> some View {
        compositingGroup()
            .background { Color.clear.glassEffect(glass, in: Capsule()) }
    }
}

// MARK: - Interactive Card Modifier (with hover)

extension View {
    /// Applies interactive glass card styling with hover effects.
    /// Use this on Button or NavigationLink content.
    func interactiveGlassCard(
        isHovering: Bool,
        cornerRadius: CGFloat = 16
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .compositingGroup()
            .background { Color.clear.glassEffect(.regular.interactive(), in: shape) }
            .overlay { shape.strokeBorder(.white.opacity(isHovering ? 0.22 : 0.10), lineWidth: 1) }
            .shadow(radius: isHovering ? 6 : 3)
    }
}
