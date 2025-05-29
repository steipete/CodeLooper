import Diagnostics
import Foundation

/// Factory for creating standardized loggers across the application.
///
/// LoggerFactory provides a centralized way to create loggers with consistent
/// configuration and naming conventions. This eliminates the need for each
/// class to manually create its own logger instance and ensures logging
/// consistency across the codebase.
///
/// ## Topics
///
/// ### Logger Creation
/// - ``logger(for:category:)``
/// - ``logger(for:)``
///
/// ### Protocol Extensions
/// - ``Loggable``
///
/// ## Usage
///
/// ```swift
/// // Using the factory directly
/// class MyService {
///     private let logger = LoggerFactory.logger(for: MyService.self)
/// }
///
/// // Using the Loggable protocol
/// class MyService: Loggable {
///     // logger property is automatically available
///     func doSomething() {
///         logger.info("Operation started")
///     }
/// }
/// ```
public enum LoggerFactory {
    
    /// Creates a logger for the specified type with automatic category detection
    /// - Parameter type: The type requesting the logger
    /// - Returns: A configured Logger instance
    public static func logger<T>(for type: T.Type) -> Logger {
        let category = categoryFromType(type)
        return Logger(category: category)
    }
    
    /// Creates a logger for the specified type with explicit category
    /// - Parameters:
    ///   - type: The type requesting the logger
    ///   - category: The log category to use
    /// - Returns: A configured Logger instance
    public static func logger<T>(for type: T.Type, category: LogCategory) -> Logger {
        return Logger(category: category)
    }
    
    // MARK: - Private Helpers
    
    /// Maps type names to appropriate log categories
    private static func categoryFromType<T>(_ type: T.Type) -> LogCategory {
        let typeName = String(describing: type)
        
        // Map based on common naming patterns
        switch typeName {
        case let name where name.contains("Monitor"):
            return .supervision
        case let name where name.contains("Intervention"):
            return .intervention
        case let name where name.contains("JSHook") || name.contains("WebSocket"):
            return .jshook
        case let name where name.contains("Settings"):
            return .settings
        case let name where name.contains("AI") || name.contains("Analysis"):
            return .aiAnalysis
        case let name where name.contains("Window") || name.contains("Accessibility"):
            return .accessibility
        case let name where name.contains("Diagnostic"):
            return .diagnostics
        case let name where name.contains("Network") || name.contains("HTTP"):
            return .networking
        case let name where name.contains("Git"):
            return .git
        case let name where name.contains("StatusBar") || name.contains("MenuBar"):
            return .statusBar
        case let name where name.contains("Onboarding") || name.contains("Welcome"):
            return .onboarding
        default:
            return .general
        }
    }
}

/// Protocol for types that need logging functionality.
///
/// Conforming to Loggable automatically provides a logger property
/// with appropriate category based on the type name.
public protocol Loggable {
    /// The logger instance for this type
    var logger: Logger { get }
}

public extension Loggable {
    /// Automatically configured logger for the conforming type
    var logger: Logger {
        LoggerFactory.logger(for: Self.self)
    }
}

/// Provides logging functionality without requiring protocol conformance.
///
/// Use this when you need a logger but cannot or don't want to conform to Loggable.
public extension NSObject {
    /// Convenience logger for NSObject subclasses
    var logger: Logger {
        LoggerFactory.logger(for: type(of: self))
    }
}