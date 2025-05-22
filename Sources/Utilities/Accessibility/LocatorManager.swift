import AXorcist // Use the actual AXorcist module
import Defaults // For UserDefaults access
import Foundation

// AXorcist.Locator should be directly usable as `Locator` after import.

@MainActor // Changed from actor to @MainActor class
public class LocatorManager {
    public static let shared = LocatorManager()

    // Default locators - these will need to be populated with actual Locator instances
    // based on AXorcist.Locator's definition and the specific elements to target.
    // For now, an empty dictionary to avoid compilation errors with unknown initializers.
    private let defaultLocators: [String: Locator] = [
        "generatingIndicatorText": Locator(), // Text: "Generating", "Thinking", "Processing"
        "sidebarActivityArea": Locator(),     // Primary sidebar element
        "errorMessagePopup": Locator(),       // General error/stuck message pop-up (e.g. for kAXValueAttribute checks)
        "stopGeneratingButton": Locator(),    // Button to stop generation if stuck
        "connectionErrorIndicator": Locator(),// Text indicating connection issue
        "resumeConnectionButton": Locator(),  // Button: "Resume" for connection issues
        "forceStopResumeLink": Locator(),     // Element: "resume the conversation" for force-stop
        "mainInputField": Locator()           // Main chat input field
    ]

    // Session cache for successfully used/discovered locators
    private var sessionCache: [String: Locator] = [:]

    // UserDefaults keys are now statically defined in DefaultsKeys.swift
    // private func userDefaultsKey(for elementName: String) -> Defaults.Key<String?> {
    //     return Defaults.Key<String?>("locator_override_\(elementName)", default: nil)
    // }

    private init() {}

    // No longer async as it's on the same MainActor as callers like CursorMonitor
    public func getLocator(for elementName: String) -> Locator? {
        var jsonString: String? = nil

        // 1. Check UserDefaults for user override (JSON string)
        switch elementName {
            case "generatingIndicatorText": jsonString = Defaults[.locatorJSON_generatingIndicatorText]
            case "sidebarActivityArea": jsonString = Defaults[.locatorJSON_sidebarActivityArea]
            case "errorMessagePopup": jsonString = Defaults[.locatorJSON_errorMessagePopup]
            case "stopGeneratingButton": jsonString = Defaults[.locatorJSON_stopGeneratingButton]
            case "connectionErrorIndicator": jsonString = Defaults[.locatorJSON_connectionErrorIndicator]
            case "resumeConnectionButton": jsonString = Defaults[.locatorJSON_resumeConnectionButton]
            case "forceStopResumeLink": jsonString = Defaults[.locatorJSON_forceStopResumeLink]
            case "mainInputField": jsonString = Defaults[.locatorJSON_mainInputField]
            default: break
        }
        
        if let str = jsonString, !str.isEmpty,
           let jsonData = str.data(using: .utf8) {
            do {
                let userLocator = try JSONDecoder().decode(Locator.self, from: jsonData)
                // Log success for debugging or diagnostics if needed
                // SessionLogger.shared.log(level: .debug, message: "Successfully decoded user locator for \(elementName)")
                return userLocator
            } catch {
                Task {
                    await SessionLogger.shared.log(
                        level: .error,
                        message: "Failed to decode user-defined locator JSON for \(elementName): \(error.localizedDescription). JSON: \(str)"
                    )
                }
            }
        }

        // 2. Check session cache
        if let cachedLocator = sessionCache[elementName] {
            return cachedLocator
        }

        // 3. Return bundled default
        return defaultLocators[elementName]
    }

    // No longer async
    public func updateSessionCache(for elementName: String, with locator: Locator) {
        sessionCache[elementName] = locator
    }

    // No longer async
    public func resetUserOverride(for elementName: String) {
        // Defaults[userDefaultsKey(for: elementName)] = nil // Old way
        switch elementName {
            case "generatingIndicatorText": Defaults.reset(.locatorJSON_generatingIndicatorText)
            case "sidebarActivityArea": Defaults.reset(.locatorJSON_sidebarActivityArea)
            case "errorMessagePopup": Defaults.reset(.locatorJSON_errorMessagePopup)
            case "stopGeneratingButton": Defaults.reset(.locatorJSON_stopGeneratingButton)
            case "connectionErrorIndicator": Defaults.reset(.locatorJSON_connectionErrorIndicator)
            case "resumeConnectionButton": Defaults.reset(.locatorJSON_resumeConnectionButton)
            case "forceStopResumeLink": Defaults.reset(.locatorJSON_forceStopResumeLink)
            case "mainInputField": Defaults.reset(.locatorJSON_mainInputField)
            default: 
                Task { await SessionLogger.shared.log(level: .warn, message: "Attempted to reset unknown locator override: \(elementName)") }
        }
        sessionCache.removeValue(forKey: elementName)
    }

    // No longer async
    public func resetAllUserOverrides() {
        Defaults.reset(
            .locatorJSON_generatingIndicatorText,
            .locatorJSON_sidebarActivityArea,
            .locatorJSON_errorMessagePopup,
            .locatorJSON_stopGeneratingButton,
            .locatorJSON_connectionErrorIndicator,
            .locatorJSON_resumeConnectionButton,
            .locatorJSON_forceStopResumeLink,
            .locatorJSON_mainInputField
        )
        sessionCache.removeAll()
    }
}

// Extension to make AXCore.Locator usable in the defaultLocators dictionary if it's not Hashable by default.
// This is a placeholder and might not be needed if Locator is already Hashable.
// If AXCore.Locator or AXorcist.Locator is a struct, it's often Hashable by default if its members are.
// extension AXCore.Locator: Hashable { ... }
