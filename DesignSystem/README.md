# CodeLooper Design System

A comprehensive design system for CodeLooper that provides consistent UI components, typography, colors, and spacing.

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