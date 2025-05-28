import DesignSystem
import SwiftUI

// Example showcasing the CodeLooper Design System
struct DesignSystemShowcase: View {
    // MARK: Internal

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xxLarge) {
                // Header
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("CodeLooper Design System")
                        .font(Typography.largeTitle())
                    Text("Beautiful, consistent UI components for macOS")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .padding(.bottom, Spacing.large)

                // Colors Section
                DSSettingsSection("Colors") {
                    HStack(spacing: Spacing.medium) {
                        ColorSwatch(color: ColorPalette.primary, name: "Primary")
                        ColorSwatch(color: ColorPalette.success, name: "Success")
                        ColorSwatch(color: ColorPalette.warning, name: "Warning")
                        ColorSwatch(color: ColorPalette.error, name: "Error")
                        ColorSwatch(color: ColorPalette.info, name: "Info")
                    }
                }

                // Typography Section
                DSSettingsSection("Typography") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Large Title").font(Typography.largeTitle())
                        Text("Title 1").font(Typography.title1())
                        Text("Title 2").font(Typography.title2())
                        Text("Headline").font(Typography.headline())
                        Text("Body").font(Typography.body())
                        Text("Caption").font(Typography.caption1())
                    }
                }

                // Components Section
                DSSettingsSection("Components") {
                    // Buttons
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text("Buttons").font(Typography.headline())
                        HStack(spacing: Spacing.small) {
                            DSButton("Primary", style: .primary) {}
                            DSButton("Secondary", style: .secondary) {}
                            DSButton("Tertiary", style: .tertiary) {}
                            DSButton("Destructive", style: .destructive) {}
                        }
                    }

                    DSDivider()

                    // Form Controls
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text("Form Controls").font(Typography.headline())

                        DSToggle("Enable Feature", isOn: $toggleValue)

                        DSTextField("Enter text", text: $textFieldValue)

                        DSSlider(
                            value: $sliderValue,
                            in: 0 ... 10,
                            label: "Slider",
                            showValue: true
                        )

                        DSPicker(
                            "Select Option",
                            selection: $selectedOption,
                            options: [
                                ("Option 1", "Option 1"),
                                ("Option 2", "Option 2"),
                                ("Option 3", "Option 3"),
                            ]
                        )
                    }

                    DSDivider()

                    // Badges
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Text("Badges").font(Typography.headline())
                        HStack(spacing: Spacing.small) {
                            DSBadge("Default")
                            DSBadge("Primary", style: .primary)
                            DSBadge("Success", style: .success)
                            DSBadge("Warning", style: .warning)
                            DSBadge("Error", style: .error)
                        }
                    }
                }

                // Cards Section
                DSSettingsSection("Cards") {
                    VStack(spacing: Spacing.medium) {
                        DSCard(style: .elevated) {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("Elevated Card")
                                    .font(Typography.headline())
                                Text("This is an elevated card with a shadow")
                                    .font(Typography.body())
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }

                        DSCard(style: .outlined) {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("Outlined Card")
                                    .font(Typography.headline())
                                Text("This is an outlined card with a border")
                                    .font(Typography.body())
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }

                        DSCard(style: .filled) {
                            VStack(alignment: .leading, spacing: Spacing.small) {
                                Text("Filled Card")
                                    .font(Typography.headline())
                                Text("This is a filled card with a background color")
                                    .font(Typography.body())
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }
                    }
                }

                // Spacing Section
                DSSettingsSection("Spacing") {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        ForEach([
                            ("xxxSmall", Spacing.xxxSmall),
                            ("xxSmall", Spacing.xxSmall),
                            ("xSmall", Spacing.xSmall),
                            ("small", Spacing.small),
                            ("medium", Spacing.medium),
                            ("large", Spacing.large),
                            ("xLarge", Spacing.xLarge),
                            ("xxLarge", Spacing.xxLarge),
                        ], id: \.0) { name, spacing in
                            HStack {
                                Text(name)
                                    .font(Typography.caption1())
                                    .frame(width: 80, alignment: .leading)
                                Rectangle()
                                    .fill(ColorPalette.primary)
                                    .frame(width: spacing, height: 20)
                                Text("\(Int(spacing))pt")
                                    .font(Typography.caption1(.medium))
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.xLarge)
        }
        .frame(width: 800, height: 900)
        .background(ColorPalette.background)
        .withDesignSystem()
    }

    // MARK: Private

    @State private var toggleValue = true
    @State private var textFieldValue = ""
    @State private var sliderValue = 5.0
    @State private var selectedOption = "Option 1"
}

// Color Swatch Component
private struct ColorSwatch: View {
    let color: Color
    let name: String

    var body: some View {
        VStack(spacing: Spacing.xxSmall) {
            RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)
                .fill(color)
                .frame(width: 60, height: 60)
                .shadowStyle(Layout.Shadow.small)

            Text(name)
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.textSecondary)
        }
    }
}

// Preview
#if DEBUG
    struct DesignSystemShowcase_Previews: PreviewProvider {
        static var previews: some View {
            DesignSystemShowcase()
        }
    }
#endif
