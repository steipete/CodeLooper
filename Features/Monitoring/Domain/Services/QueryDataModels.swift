import Foundation

// MARK: - Query Data Models

/// Configuration data for accessibility queries executed against Cursor.
///
/// QueryData encapsulates:
/// - Query identification and naming
/// - The accessibility command to execute
/// - Parameters for filtering and depth control
/// - Response formatting configuration
struct QueryData: Codable {
    let name: String
    let command: String
    let params: QueryParams
    let response: ResponseConfig
}

/// Parameters for customizing accessibility query behavior.
///
/// Allows filtering attributes and controlling traversal depth
/// to optimize query performance and reduce response size.
struct QueryParams: Codable {
    let includeAttributes: [String]?
    let excludeAttributes: [String]?
    let maxDepth: Int?
}

/// Configuration for formatting query response data.
///
/// Defines which attributes to include in the response
/// and how they should be formatted or typed.
struct ResponseConfig: Codable {
    let attributes: [AttributeConfig]
}

/// Configuration for individual attributes in query responses.
///
/// Specifies attribute names and optional type information
/// for proper handling and display of accessibility data.
struct AttributeConfig: Codable {
    let name: String
    let type: String?
}
