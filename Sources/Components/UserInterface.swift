import Foundation

/// UserInterface namespace for reorganizing UI components
public enum UserInterface {
    /// Components namespace for UI components
    public enum Components {
        // Reference to types without explicit namespace
        public typealias AlertPresenter = CodeLooper.AlertPresenter
        public typealias AlertPresenting = CodeLooper.AlertPresenting
    }

    /// Views namespace for SwiftUI views
    public enum Views {
        // Reference to view types without explicit namespace
        // Make these internal since the underlying types are internal
        typealias StatsView = CodeLooper.StatsView
        typealias UserAvatarView = CodeLooper.UserAvatarView
        typealias WelcomeView = CodeLooper.WelcomeView
    }
}