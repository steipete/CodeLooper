import Foundation
import Security

/// Service for securely storing and retrieving API keys from the macOS Keychain
@MainActor
public final class APIKeyService {
    // MARK: - Types
    
    public enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case invalidData
        
        public var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save API key to keychain. Error: \(status)"
            case .loadFailed(let status):
                return "Failed to load API key from keychain. Error: \(status)"
            case .deleteFailed(let status):
                return "Failed to delete API key from keychain. Error: \(status)"
            case .invalidData:
                return "Invalid data format in keychain"
            }
        }
    }
    
    public enum APIKeyType {
        case openAI
        case anthropic
        case custom(service: String, account: String)
        
        var service: String {
            switch self {
            case .openAI:
                return "CODELOOPER_OPENAI_API_KEY"
            case .anthropic:
                return "CODELOOPER_ANTHROPIC_API_KEY"
            case .custom(let service, _):
                return service
            }
        }
        
        var account: String {
            switch self {
            case .openAI, .anthropic:
                return "api-key"
            case .custom(_, let account):
                return account
            }
        }
    }
    
    // MARK: - Properties
    
    public static let shared = APIKeyService()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Save an API key to the keychain
    /// - Parameters:
    ///   - apiKey: The API key to save
    ///   - type: The type of API key (OpenAI, Anthropic, etc.)
    /// - Throws: KeychainError if the save operation fails
    public func saveAPIKey(_ apiKey: String, for type: APIKeyType) throws {
        guard let data = apiKey.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: type.service,
            kSecAttrAccount as String: type.account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Load an API key from the keychain
    /// - Parameter type: The type of API key to load
    /// - Returns: The API key if found, nil otherwise
    /// - Throws: KeychainError if the load operation fails with an error other than item not found
    public func loadAPIKey(for type: APIKeyType) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: type.service,
            kSecAttrAccount as String: type.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let apiKey = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return apiKey
            
        case errSecItemNotFound:
            return nil
            
        default:
            throw KeychainError.loadFailed(status)
        }
    }
    
    /// Delete an API key from the keychain
    /// - Parameter type: The type of API key to delete
    /// - Throws: KeychainError if the delete operation fails
    public func deleteAPIKey(for type: APIKeyType) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: type.service,
            kSecAttrAccount as String: type.account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Consider item not found as success
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// Check if an API key exists in the keychain
    /// - Parameter type: The type of API key to check
    /// - Returns: true if the key exists, false otherwise
    public func hasAPIKey(for type: APIKeyType) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: type.service,
            kSecAttrAccount as String: type.account,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Validate an API key format
    /// - Parameters:
    ///   - apiKey: The API key to validate
    ///   - type: The type of API key
    /// - Returns: true if the format is valid, false otherwise
    public func isValidFormat(_ apiKey: String, for type: APIKeyType) -> Bool {
        switch type {
        case .openAI:
            // OpenAI keys start with "sk-" and are typically 48+ characters
            return apiKey.hasPrefix("sk-") && apiKey.count >= 48
            
        case .anthropic:
            // Anthropic keys start with "sk-ant-" 
            return apiKey.hasPrefix("sk-ant-") && apiKey.count >= 40
            
        case .custom:
            // For custom keys, just check if not empty
            return !apiKey.isEmpty
        }
    }
}

// MARK: - Convenience Extensions

public extension APIKeyService {
    /// Load OpenAI API key with a simpler interface
    func loadOpenAIKey() -> String {
        (try? loadAPIKey(for: .openAI)) ?? ""
    }
    
    /// Load Anthropic API key with a simpler interface
    func loadAnthropicKey() -> String {
        (try? loadAPIKey(for: .anthropic)) ?? ""
    }
    
    /// Save OpenAI API key with error handling
    @discardableResult
    func saveOpenAIKey(_ apiKey: String) -> Bool {
        do {
            try saveAPIKey(apiKey, for: .openAI)
            return true
        } catch {
            print("Failed to save OpenAI API key: \(error)")
            return false
        }
    }
    
    /// Save Anthropic API key with error handling
    @discardableResult
    func saveAnthropicKey(_ apiKey: String) -> Bool {
        do {
            try saveAPIKey(apiKey, for: .anthropic)
            return true
        } catch {
            print("Failed to save Anthropic API key: \(error)")
            return false
        }
    }
}