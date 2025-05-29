import Foundation

/// Information about a specific Cursor window being monitored.
///
/// CursorWindowInfo tracks:
/// - Window identification and naming
/// - Associated query configuration files
/// - Last known text content for comparison
/// - Error states specific to the window
///
/// Each window can have custom query configurations loaded
/// from JSON files in the project root.
struct CursorWindowInfo: Identifiable, Hashable, Sendable {
    let id: String // Could be an AXPath or a generated UUID
    var name: String // e.g., "Main AI Input" or a window title
    var queryFile: String? // Name of the JSON file in the project root for this query
    var lastKnownText: String = ""
    var lastError: String?
}
