# Liquid Glass Design System

Comprehensive guide to implementing Apple's Liquid Glass design language in macOS 26 SwiftUI apps, based on WWDC25 sessions and official documentation.

---

## Overview

Liquid Glass is Apple's new dynamic material that combines optical properties of glass with a sense of fluidity. It blurs content behind it, reflects surrounding color and light, and reacts to touch/pointer interactions in real time.

**Key principle**: Glass is for **controls and small UI elements**, not for content-heavy surfaces.

---

## Core APIs

### `glassEffect(_:in:)`

Applies Liquid Glass to a view within a specified shape.

```swift
Text("Hello")
    .padding()
    .glassEffect(.regular, in: Capsule())
```

### `Glass` Structure

Configures the glass appearance:

- `.regular` - Standard glass
- `.regular.interactive()` - Responds to press/tap
- `.regular.tint(color)` - Tinted glass surface

### `GlassEffectContainer`

Coordinates multiple glass shapes for blending/morphing:

```swift
GlassEffectContainer(spacing: 8) {
    HStack {
        Badge(...)
        Badge(...)
    }
}
```

### Button Styles

- `.buttonStyle(.glass)` - Secondary/utility buttons
- `.buttonStyle(.glassProminent)` - Primary actions with accent tint

---

## Critical Mistake: Direct Application

**WRONG** - Applying glass directly to content views:

```swift
VStack {
    Image(...)
    Text(...)
}
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
```

This applies **vibrancy treatment to the entire layer**, washing out images and text.

**CORRECT** - Glass as background surface:

```swift
VStack {
    Image(...)
    Text(...)
}
.compositingGroup()
.background {
    Color.clear.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
}
```

The `compositingGroup()` isolates content from glass vibrancy. Content stays crisp.

---

## Interactive States

### Press Feedback

`.interactive()` only works when attached to an actual **control** (`Button`, `NavigationLink`).

**WRONG** - No press feedback:

```swift
CardView()
    .glassEffect(.regular.interactive(), in: shape)
    .onTapGesture { /* action */ }
```

**CORRECT** - Press feedback works:

```swift
Button { /* action */ } label: {
    CardView()
}
.buttonStyle(.plain)
.compositingGroup()
.background {
    Color.clear.glassEffect(.regular.interactive(), in: shape)
}
```

### Hover States

Glass does **not** provide automatic hover effects. Implement manually:

```swift
@State private var isHovering = false

var body: some View {
    Button { ... } label: { ... }
        .compositingGroup()
        .background { Color.clear.glassEffect(.regular.interactive(), in: shape) }
        .overlay {
            shape.strokeBorder(.white.opacity(isHovering ? 0.22 : 0.10), lineWidth: 1)
        }
        .shadow(radius: isHovering ? 6 : 3)
        .onHover { isHovering = $0 }
        .animation(.snappy(duration: 0.18), value: isHovering)
}
```

---

## GlassEffectContainer Usage

### Purpose

- Allows nearby glass shapes to **blend together**
- Enables **morphing animations** between shapes
- Provides proper **sampling region** (glass cannot sample other glass)

### When to Use

**DO** use for small clusters:
- Badge groups
- Floating control stacks
- Toolbar button groups

```swift
GlassEffectContainer(spacing: 8) {
    HStack(spacing: 8) {
        Badge(text: "3", icon: "tag.fill", color: .green)
        Badge(text: "2", icon: "box.fill", color: .blue)
    }
}
```

### When NOT to Use

**DON'T** wrap large grids or scrolling content:

```swift
// WRONG - hurts performance, not intended use
GlassEffectContainer(spacing: 16) {
    LazyVGrid(columns: columns) {
        ForEach(items) { item in
            Card(item: item)
        }
    }
}
```

Cards should have individual glass backgrounds, not be wrapped in a container.

---

## When to Use Glass vs Materials

| Use Case | Recommendation |
|----------|----------------|
| Toolbar buttons | `.buttonStyle(.glass)` |
| Small badges/pills | `.glassEffect()` or `.glassPill()` |
| Interactive cards | Glass as background + manual hover |
| Content-heavy cards | Consider `.regularMaterial` instead |
| Large containers | `.regularMaterial` or `.bar` |
| Headers/footers | `.background(.bar)` |

**Rule of thumb**: If the element has significant content (images, multiple text lines), prefer materials over glass.

---

## Best Practices

### 1. Isolate Content from Glass

Always use `compositingGroup()` when applying glass as a background:

```swift
.compositingGroup()
.background { Color.clear.glassEffect(...) }
```

### 2. Use Controls for Interactivity

Convert `onTapGesture` to `Button` or `NavigationLink` for proper press feedback:

```swift
// Instead of:
Card().onTapGesture { action() }

// Use:
Button(action: action) { Card() }
    .buttonStyle(.plain)
```

### 3. Manual Hover States

Implement hover with border and shadow changes:

```swift
.overlay { shape.strokeBorder(.white.opacity(isHovering ? 0.22 : 0.10)) }
.shadow(radius: isHovering ? 6 : 3)
.onHover { isHovering = $0 }
.animation(.snappy(duration: 0.18), value: isHovering)
```

### 4. Appropriate Shadow Values

Keep shadows subtle to avoid overwhelming the UI:

- Default: `radius: 3`
- Hover: `radius: 6`

### 5. Button Style Selection

- `.buttonStyle(.glass)` - Secondary actions (toolbar share, open in browser)
- `.buttonStyle(.glassProminent)` - Primary actions (sync, confirm)

### 6. Avoid Stacking Glass

Don't layer glass on glass or glass on materials:

```swift
// WRONG - double translucency
.background(.regularMaterial)
.glassEffect(...)
```

---

## Watchify Implementation

### Helper Extensions (GlassTheme.swift)

```swift
extension View {
    /// Glass as background surface - content unaffected
    func glassSurface<S: Shape>(_ glass: Glass = .regular, in shape: S) -> some View {
        compositingGroup()
            .background { Color.clear.glassEffect(glass, in: shape) }
    }

    /// Glass pill for badges
    func glassPill(_ glass: Glass = .regular) -> some View {
        compositingGroup()
            .background { Color.clear.glassEffect(glass, in: Capsule()) }
    }

    /// Interactive card with hover effects
    func interactiveGlassCard(isHovering: Bool, cornerRadius: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .compositingGroup()
            .background { Color.clear.glassEffect(.regular.interactive(), in: shape) }
            .overlay { shape.strokeBorder(.white.opacity(isHovering ? 0.22 : 0.10), lineWidth: 1) }
            .shadow(radius: isHovering ? 6 : 3)
    }
}
```

### Usage Examples

**Interactive Card (StoreCard)**:
```swift
Button(action: onSelect) {
    VStack { /* content */ }
        .padding(12)
}
.buttonStyle(.plain)
.contentShape(shape)
.interactiveGlassCard(isHovering: isHovering, cornerRadius: 16)
.onHover { isHovering = $0 }
.animation(.snappy(duration: 0.18), value: isHovering)
```

**Toolbar Button**:
```swift
Button { sync() } label: {
    Label("Sync", systemImage: "arrow.trianglehead.2.clockwise")
}
.buttonStyle(.glass)
```

**Date Section (material for content, glass for badge)**:
```swift
VStack {
    Text("Today")
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassPill()  // Small badge - glass is appropriate

    VStack { /* event rows */ }
}
.padding(12)
.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))  // Content-heavy - use material
```

---

## Common Pitfalls

### 1. Content Washed Out

**Symptom**: Images and text appear faded/white.

**Cause**: Glass applied directly to content view.

**Fix**: Use `compositingGroup()` + background pattern.

### 2. No Press Feedback

**Symptom**: Card doesn't respond to clicks visually.

**Cause**: Using `onTapGesture` instead of `Button`/`NavigationLink`.

**Fix**: Wrap in a control, use `.buttonStyle(.plain)`.

### 3. No Hover Feedback

**Symptom**: Card doesn't change on mouse hover.

**Cause**: Glass doesn't provide automatic hover.

**Fix**: Add `@State var isHovering` + `.onHover` + visual changes.

### 4. Performance Issues in Grids

**Symptom**: Laggy scrolling in large grids.

**Cause**: `GlassEffectContainer` wrapping entire grid.

**Fix**: Remove container, let cards have individual glass backgrounds.

### 5. Overwhelming Shadows

**Symptom**: Cards look like they're floating too high.

**Cause**: Shadow radius too large.

**Fix**: Use subtle values (3 default, 6 hover).

---

## References

- [WWDC25: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple Developer: glassEffect(_:in:)](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))
- [Apple Developer: GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer)
- [Apple Developer: GlassButtonStyle](https://developer.apple.com/documentation/swiftui/glassbuttonstyle)
- [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Landmarks Sample App](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass)
