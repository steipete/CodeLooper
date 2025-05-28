import Foundation

// MARK: - Query Data Models

struct QueryData: Codable {
    let name: String
    let command: String
    let params: QueryParams
    let response: ResponseConfig
}

struct QueryParams: Codable {
    let includeAttributes: [String]?
    let excludeAttributes: [String]?
    let maxDepth: Int?
}

struct ResponseConfig: Codable {
    let attributes: [AttributeConfig]
}

struct AttributeConfig: Codable {
    let name: String
    let type: String?
}