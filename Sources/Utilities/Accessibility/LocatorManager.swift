import AppKit
import ApplicationServices // Ensure this is imported for AX constants
import AXorcist // Use the library product
import Defaults // For UserDefaults access
import Diagnostics
import Foundation

// Locator should be directly usable after import.

// MARK: - LocatorManager

@MainActor // Changed from actor to @MainActor class
public class LocatorManager {
    // MARK: Lifecycle

    private init() {
        // Initialize AXorcist instance here or ensure it's passed if needed by discoverer directly.
        // For simplicity, assuming discoverer can take it during its discover call.
        self.axorcistInstance = AXorcist() // Or get from a shared context if appropriate
        self.dynamicDiscoverer = DynamicLocatorDiscoverer()

        // Populate defaultLocators from LocatorType enum
        for type in LocatorType.allCases {
            defaultLocators[type] = type.defaultLocator
        }
    }

    // MARK: Public

    public static let shared = LocatorManager()

    public func getLocator(for type: LocatorType, pid: pid_t? = nil) async -> Locator? {
        var jsonString: String?
        _ = type.rawValue // Unused variable

        // 1. Check UserDefaults for user override (JSON string)
        switch type {
        case .generatingIndicatorText: jsonString = Defaults[.locatorJSONGeneratingIndicatorText]
        case .sidebarActivityArea: jsonString = Defaults[.locatorJSONSidebarActivityArea]
        case .errorMessagePopup: jsonString = Defaults[.locatorJSONErrorMessagePopup]
        case .stopGeneratingButton: jsonString = Defaults[.locatorJSONStopGeneratingButton]
        case .connectionErrorIndicator: jsonString = Defaults[.locatorJSONConnectionErrorIndicator]
        case .resumeConnectionButton: jsonString = Defaults[.locatorJSONResumeConnectionButton]
        case .forceStopResumeLink: jsonString = Defaults[.locatorJSONForceStopResumeLink]
        case .mainInputField: jsonString = Defaults[.locatorJSONMainInputField]
            // default: break // Not needed if LocatorType is comprehensive and matches DefaultsKeys
        }

        if let str = jsonString, !str.isEmpty,
           let jsonData = str.data(using: .utf8)
        {
            do {
                let userLocator = try JSONDecoder().decode(Locator.self, from: jsonData)
                SessionLogger.shared.log(
                    level: .debug,
                    message: "Using user-defined locator for \(type.rawValue) from Defaults.",
                    pid: pid
                )
                return userLocator
            } catch {
                SessionLogger.shared.log(
                    level: .error,
                    message: "Failed to decode user-defined locator JSON for \(type.rawValue): " +
                        "\(error.localizedDescription). JSON: \(str)", pid: pid
                )
            }
        }

        // 2. Check session cache
        if let cachedLocator = sessionCache[type] {
            SessionLogger.shared.log(
                level: .debug,
                message: "Using session-cached locator for \(type.rawValue).",
                pid: pid
            )
            return cachedLocator
        }

        // 3. Return bundled default
        if defaultLocators[type] != nil {
            SessionLogger.shared.log(
                level: .debug,
                message: "Using bundled default locator for \(type.rawValue).",
                pid: pid
            )
            // Attempt to use this locator once. If it fails, dynamic discovery might be tried next (implicitly by
            // caller or explicitly here)
            // For now, just return it. Dynamic discovery is the next step if this doesn't work for the caller.
            // return bundledLocator // Old behavior: just return the bundled one
        } else {
            SessionLogger.shared.log(
                level: .warning,
                message: "No bundled default locator found for type: \(type.rawValue)",
                pid: pid
            )
        }

        // 4. If PID is available, attempt dynamic discovery as a fallback
        // This happens if user, cache, and bundled (or if bundled fails in practice) don't yield a result.
        // For clarity, we try dynamic discovery if user & cache miss, and bundled is considered a starting point for
        // heuristics or a direct attempt.

        // First, try the bundled locator if it exists. Actual query to AXorcist is done by the caller (CursorMonitor).
        // If the caller determines the bundled locator failed, it could re-call getLocator with a flag to force
        // discovery,
        // or LocatorManager can attempt discovery now if the bundled one *might* be stale.
        // Let's try dynamic discovery if user & cache miss. Bundled is the ultimate fallback if discovery also fails.

        if let currentPid = pid {
            SessionLogger.shared.log(
                level: .info,
                message: "User/cached locator not found for \(type.rawValue). Attempting dynamic discovery for PID: \(currentPid).",
                pid: currentPid
            )
            if let discoveredLocator = await dynamicDiscoverer.discover(
                type: type,
                for: currentPid,
                axorcist: self.axorcistInstance
            ) {
                SessionLogger.shared.log(
                    level: .info,
                    message: "Dynamic discovery successful for \(type.rawValue). Caching and returning.",
                    pid: currentPid
                )
                updateSessionCache(for: type, with: discoveredLocator) // Use type directly
                return discoveredLocator
            }
        }

        // 5. If dynamic discovery also fails or no PID, fall back to bundled default (if it exists)
        if let bundledLocator = defaultLocators[type] {
            SessionLogger.shared.log(
                level: .debug,
                message: "Falling back to bundled default locator for \(type.rawValue) after other attempts.",
                pid: pid
            )
            return bundledLocator
        }

        SessionLogger.shared.log(
            level: .error,
            message: "Failed to find any locator for type: \(type.rawValue) after all attempts.",
            pid: pid
        )
        return nil // Absolute fallback
    }

    public func updateSessionCache(for type: LocatorType, with locator: Locator) {
        sessionCache[type] = locator
        // Task { // Fire and forget log // Removed Task wrapper as log is not async
        SessionLogger.shared.log(level: .info, message: "Session cache updated for locator type: \(type.rawValue)")
        // }
    }

    public func resetUserOverride(for type: LocatorType) {
        _ = type.rawValue // Unused variable
        switch type {
        case .generatingIndicatorText: Defaults.reset(.locatorJSONGeneratingIndicatorText)
        case .sidebarActivityArea: Defaults.reset(.locatorJSONSidebarActivityArea)
        case .errorMessagePopup: Defaults.reset(.locatorJSONErrorMessagePopup)
        case .stopGeneratingButton: Defaults.reset(.locatorJSONStopGeneratingButton)
        case .connectionErrorIndicator: Defaults.reset(.locatorJSONConnectionErrorIndicator)
        case .resumeConnectionButton: Defaults.reset(.locatorJSONResumeConnectionButton)
        case .forceStopResumeLink: Defaults.reset(.locatorJSONForceStopResumeLink)
        case .mainInputField: Defaults.reset(.locatorJSONMainInputField)
            // default: await SessionLogger.shared.log(level: .warning, message: "Attempted to reset unknown locator override: \(defaultsKeyName)")
        }
        sessionCache.removeValue(forKey: type)
        // Task { // Fire and forget log // Removed Task wrapper
        SessionLogger.shared.log(
            level: .info,
            message: "User override reset for locator type: \(type.rawValue) and cleared from session cache."
        )
        // }
    }

    public func resetAllUserOverrides() {
        Defaults.reset(
            .locatorJSONGeneratingIndicatorText,
            .locatorJSONSidebarActivityArea,
            .locatorJSONErrorMessagePopup,
            .locatorJSONStopGeneratingButton,
            .locatorJSONConnectionErrorIndicator,
            .locatorJSONResumeConnectionButton,
            .locatorJSONForceStopResumeLink,
            .locatorJSONMainInputField
        )
        sessionCache.removeAll()
        // Task { // Fire and forget log // Removed Task wrapper
        SessionLogger.shared.log(level: .info, message: "All user locator overrides reset and session cache cleared.")
        // }
    }

    // MARK: Private

    private let axorcistInstance: AXorcist // To pass to discoverer
    private let dynamicDiscoverer: DynamicLocatorDiscoverer
    private let logger = Logger(category: .accessibility)

    // Default locators - these are fallback locators if not overridden by user or found in session cache.
    // These should represent common, reasonably stable ways to find these elements.
    private var defaultLocators: [LocatorType: Locator?] = [:]

    // Session cache for successfully used/discovered locators
    private var sessionCache: [LocatorType: Locator] = [:]
}

// Extension to make AXCore.Locator usable in the defaultLocators dictionary if it's not Hashable by default.
// This is a placeholder and might not be needed if Locator is already Hashable.
// If AXCore.Locator or AXorcist.Locator is a struct, it's often Hashable by default if its members are.
// extension AXCore.Locator: Hashable { ... }
