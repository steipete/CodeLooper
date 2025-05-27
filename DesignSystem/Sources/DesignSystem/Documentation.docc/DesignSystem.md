# ``DesignSystem``

A comprehensive design system for building consistent user interfaces.

## Overview

The DesignSystem framework provides a unified set of design tokens, components, and utilities for creating cohesive user experiences across CodeLooper. It includes colors, typography, spacing, and pre-built SwiftUI components.

### Design Principles

- **Consistency**: Unified visual language across all interfaces
- **Accessibility**: Built-in support for accessibility features
- **Customization**: Flexible theming and customization options
- **Performance**: Optimized components for smooth interactions

### Quick Start

Apply the design system to your SwiftUI app:

```swift
import DesignSystem
import SwiftUI

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

## Topics

### Getting Started

- ``DesignSystem``
- ``View/withDesignSystem()``
- ``DesignSystemViewModifier``

### Design Tokens

- ``ColorPalette``
- ``ColorTheme``
- ``Typography``
- ``TextStyles``
- ``Spacing``
- ``Layout``

### Components

- ``DSButton``
- ``DSCard``
- ``DSTextField``
- ``DSToggle``
- ``DSSlider``
- ``DSPicker``
- ``DSSection``
- ``DSTabView``
- ``DSBadge``
- ``DSDivider``

### Theming

- ``ColorTheme``
- ``ColorPalette``