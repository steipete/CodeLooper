import Foundation

/// UserInterface namespace for reorganizing UI components
public enum UserInterface {
    // Reference to types without explicit namespace
    public typealias AlertPresenter = CodeLooper.AlertPresenter
    public typealias AlertPresenting = CodeLooper.AlertPresenting
}

/// Components namespace for UI components
public enum UIComponents {
    public typealias AlertPresenter = CodeLooper.AlertPresenter
    public typealias AlertPresenting = CodeLooper.AlertPresenting
}

/// Views namespace for SwiftUI views
public enum UIViews {
    // Reference to view types without explicit namespace
    // Make these internal since the underlying types are internal
    typealias StatsView = CodeLooper.StatsView
    typealias MainPopoverView = CodeLooper.MainPopoverView
    typealias WelcomeView = CodeLooper.WelcomeView
}
