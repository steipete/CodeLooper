import Foundation

struct CursorWindowInfo: Identifiable, Hashable {
    let id: String // Could be an AXPath or a generated UUID
    var name: String // e.g., "Main AI Input" or a window title
    var queryFile: String? // Name of the JSON file in the project root for this query
    var lastKnownText: String = ""
    var lastError: String?
} 