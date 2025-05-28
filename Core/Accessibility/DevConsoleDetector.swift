import Foundation

/// Detects if the Chrome/Chromium Developer Console is open in the current window
public enum DevConsoleDetector {
    // MARK: Public

    /// Checks if the developer console is open in the frontmost window
    /// - Returns: True if developer console appears to be open
    public static func isDevConsoleOpen() -> Bool {
        do {
            let windowText = try WindowTextExtractor.extractTextFromFrontWindow()
            return containsDevConsoleIndicators(in: windowText)
        } catch {
            // If we can't extract text, assume console is not open
            return false
        }
    }

    /// Checks if the developer console is open in a specific application
    /// - Parameter appName: Name of the application to check (e.g., "Cursor", "Google Chrome")
    /// - Returns: True if developer console appears to be open
    public static func isDevConsoleOpen(in appName: String) -> Bool {
        do {
            let windowText = try WindowTextExtractor.extractTextFromApp(named: appName)
            return containsDevConsoleIndicators(in: windowText)
        } catch {
            // If we can't extract text, assume console is not open
            return false
        }
    }

    /// Gets detailed information about which dev console indicators were found
    /// - Parameter text: The text to analyze
    /// - Returns: Array of found keywords
    public static func findDevConsoleIndicators(in text: String) -> [String] {
        let normalizedText = text.lowercased()

        return devConsoleKeywords.filter { keyword in
            normalizedText.contains(keyword.lowercased())
        }
    }

    // MARK: Private

    /// Keywords that indicate the developer console is open
    private static let devConsoleKeywords = [
        "Elements",
        "Console",
        "Sources",
        "Network",
        "Performance",
        "Memory",
        "Application",
        "Security",
        "Lighthouse",
        "Recorder",
        "DevTools",
        "Developer Tools",
        "Inspect",
        "Debugger",
        "Breakpoints",
        "Call Stack",
        "Scope",
        "Watch",
        "Event Listeners",
        "Properties",
        "Computed",
        "Layout",
        "Accessibility",
        "Changes",
    ]

    /// Analyzes text to determine if it contains developer console indicators
    /// - Parameter text: The text to analyze
    /// - Returns: True if the text appears to contain developer console content
    private static func containsDevConsoleIndicators(in text: String) -> Bool {
        // Normalize text for comparison
        let normalizedText = text.lowercased()

        // Count how many dev console keywords are present
        var matchCount = 0
        for keyword in devConsoleKeywords {
            if normalizedText.contains(keyword.lowercased()) {
                matchCount += 1
            }
        }

        // If we find multiple dev console keywords, it's likely the console is open
        // Using a threshold of 3 to avoid false positives
        return matchCount >= 3
    }
}
