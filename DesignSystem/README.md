# DesignSystem Framework 🎨

A comprehensive design system for building consistent macOS user interfaces with SwiftUI.

## Overview

The DesignSystem framework provides a unified set of design tokens, components, and utilities for creating cohesive user experiences. Built specifically for CodeLooper but designed to be reusable across macOS applications.

### Design Principles

- **Consistency**: Unified visual language across all interfaces
- **Accessibility**: Built-in support for system accessibility features
- **Customization**: Flexible theming and customization options
- **Performance**: Optimized components for smooth interactions
- **Platform Integration**: Native macOS styling and behaviors

---

*This document provides a comprehensive overview of all DesignSystem classes and components. For interactive API documentation, run `../view-docs.sh` to open the DocC archives.*

## Core Classes Reference

### DesignSystem (Main Entry Point)

The central access point for all design system resources.

```swift
public struct DesignSystem {
    static let colors = ColorPalette.self
    static let typography = Typography.self
    static let textStyles = TextStyles.self
    static let spacing = Spacing.self
    static let layout = Layout.self
}
```

**Key Features:**
- Centralized access to design tokens
- Type-safe design system resources
- Consistent API across all components
- Environment-based theming support

### ColorPalette

Comprehensive color system with semantic naming and theme support.

```swift
public struct ColorPalette {
    // Primary Colors
    static var primary: Color
    static var primaryVariant: Color
    
    // Semantic Colors
    static var success: Color
    static var warning: Color
    static var error: Color
    
    // Text Colors
    static var text: Color
    static var textSecondary: Color
    static var textTertiary: Color
    
    // Background Colors
    static var background: Color
    static var surface: Color
    static var surfaceSecondary: Color
}
```

### Typography

Comprehensive typography system with semantic text styles.

```swift
public struct Typography {
    // Display Styles
    static func largeTitle(_ weight: Font.Weight = .regular) -> Font
    static func title1(_ weight: Font.Weight = .regular) -> Font
    static func title2(_ weight: Font.Weight = .regular) -> Font
    static func title3(_ weight: Font.Weight = .regular) -> Font
    
    // Body Styles
    static func body(_ weight: Font.Weight = .regular) -> Font
    static func callout(_ weight: Font.Weight = .regular) -> Font
    static func caption1(_ weight: Font.Weight = .regular) -> Font
    static func caption2(_ weight: Font.Weight = .regular) -> Font
}
```

---

## UI Components Reference

Components detailed in this framework include DSButton, DSCard, DSTextField, DSSlider, DSToggle, and more with comprehensive styling options and accessibility support.

## Usage

### Setup

Apply the design system to your SwiftUI app:

```swift
import DesignSystem

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withDesignSystem()
        }
    }
}
```

### Colors

```swift
// Semantic colors
ColorPalette.primary
ColorPalette.success
ColorPalette.warning
ColorPalette.error

// Neutral colors
ColorPalette.text
ColorPalette.textSecondary
ColorPalette.background
ColorPalette.border

// Dynamic theme
@Environment(\.colorTheme) var theme
Text("Hello").foregroundColor(theme.primary)
```

### Typography

```swift
// Text styles
Text("Title").font(Typography.title1())
Text("Body").font(Typography.body(.medium))
Text("Code").font(Typography.monospaced(.large))

// Pre-configured text styles
Text("Display").textStyle(TextStyles.displayLarge)
Text("Heading").textStyle(TextStyles.headingMedium)
Text("Body").textStyle(TextStyles.bodyMedium)
```

### Spacing

```swift
// Consistent spacing
VStack(spacing: Spacing.medium) {
    Text("Item 1")
    Text("Item 2")
}
.padding(Spacing.large)

// Component spacing
.padding(Spacing.Component.paddingMedium)

// Layout spacing
.padding(.horizontal, Spacing.Layout.marginLarge)
```

### Components

#### Button

```swift
DSButton("Primary", style: .primary) {
    // Action
}

DSButton("Delete", icon: Image(systemName: "trash"), style: .destructive) {
    // Action
}

DSButton("Full Width", style: .secondary, isFullWidth: true) {
    // Action
}
```

#### TextField

```swift
@State private var text = ""

DSTextField("Enter name", text: $text)

DSTextField(
    "Email", 
    text: $text,
    icon: Image(systemName: "envelope"),
    helperText: "We'll never share your email",
    errorText: isValidEmail ? nil : "Invalid email"
)
```

#### Card

```swift
DSCard {
    VStack(alignment: .leading, spacing: Spacing.small) {
        Text("Card Title").font(Typography.headline())
        Text("Card content goes here").font(Typography.body())
    }
}

DSCard(style: .outlined) {
    // Content
}
```

#### Badge

```swift
DSBadge("New")
DSBadge("Success", style: .success)
DSBadge("Warning", style: .warning)
DSBadge("Error", style: .error)
```

#### Divider

```swift
DSDivider()
DSDivider(orientation: .vertical)
DSDivider(thickness: 2, color: ColorPalette.primary)
```

### Layout

```swift
// Corner radius
.cornerRadiusDS(Layout.CornerRadius.medium)

// Shadows
.shadowStyle(Layout.Shadow.medium)

// Borders
.borderDS(ColorPalette.primary, width: Layout.BorderWidth.medium)

// Animations
.animateDS(Layout.Animation.fast)
.springAnimateDS()
```

### View Extensions

```swift
// Conditional modifiers
Text("Hello")
    .if(isLarge) { view in
        view.font(.largeTitle)
    }
    .ifLet(optionalColor) { view, color in
        view.foregroundColor(color)
    }
```

## Architecture

- **Colors**: Semantic color system with support for dark/light themes
- **Typography**: Consistent font styles and sizes
- **Spacing**: 4-point grid system for consistent spacing
- **Components**: Pre-built UI components following design guidelines
- **Layout**: Constants for corners, shadows, borders, and animations
- **Extensions**: Helpful view modifiers for common patterns

## Requirements

- macOS 14+
- Swift 6.0+
- SwiftUI