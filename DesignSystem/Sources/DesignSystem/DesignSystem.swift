import SwiftUI

public struct DesignSystem {
    public static let colors = ColorPalette.self
    public static let typography = Typography.self
    public static let textStyles = TextStyles.self
    public static let spacing = Spacing.self
    public static let layout = Layout.self
    
    private init() {}
}

// MARK: - Environment Setup
public struct DesignSystemViewModifier: ViewModifier {
    @State private var colorTheme = ColorTheme()
    
    public func body(content: Content) -> some View {
        content
            .environment(\.colorTheme, colorTheme)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeOcclusionStateNotification)) { _ in
                colorTheme.updateFromSystem()
            }
    }
}

public extension View {
    func withDesignSystem() -> some View {
        modifier(DesignSystemViewModifier())
    }
}