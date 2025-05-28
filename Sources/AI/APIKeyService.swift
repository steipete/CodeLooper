import Foundation
import KeychainAccess

/// Service for securely storing and retrieving API keys from the macOS Keychain
@MainActor
public final class APIKeyService {
    // MARK: - Types
    
    public enum KeychainError: Error, LocalizedError {
        case saveFailed(Error)
        case loadFailed(Error)
        case deleteFailed(Error)
        case invalidData
        
        public var errorDescription: String? {
            switch self {
            case .saveFailed(let error):
                return "Failed to save API key to keychain. Error: \(error.localizedDescription)"
            case .loadFailed(let error):
                return "Failed to load API key from keychain. Error: \(error.localizedDescription)"
            case .deleteFailed(let error):
                return "Failed to delete API key from keychain. Error: \(error.localizedDescription)"
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
    private let keychain = Keychain(service: "com.codelooper.api-keys")
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Save an API key to the keychain
    /// - Parameters:
    ///   - apiKey: The API key to save
    ///   - type: The type of API key (OpenAI, Anthropic, etc.)
    /// - Throws: KeychainError if the save operation fails
    public func saveAPIKey(_ apiKey: String, for type: APIKeyType) throws {
        do {
            try keychain
                .accessibility(.whenUnlockedThisDeviceOnly)
                .set(apiKey, key: type.service)
        } catch {
            throw KeychainError.saveFailed(error)
        }
    }
    
    /// Load an API key from the keychain
    /// - Parameter type: The type of API key to load
    /// - Returns: The API key if found, nil otherwise
    /// - Throws: KeychainError if the load operation fails with an error other than item not found
    public func loadAPIKey(for type: APIKeyType) throws -> String? {
        do {
            return try keychain.get(type.service)
        } catch let error as KeychainAccess.Status {
            if error == .itemNotFound {
                return nil
            }
            throw KeychainError.loadFailed(error)
        } catch {
            throw KeychainError.loadFailed(error)
        }
    }
    
    /// Delete an API key from the keychain
    /// - Parameter type: The type of API key to delete
    /// - Throws: KeychainError if the delete operation fails
    public func deleteAPIKey(for type: APIKeyType) throws {
        do {
            try keychain.remove(type.service)
        } catch let error as KeychainAccess.Status {
            // Consider item not found as success
            if error != .itemNotFound {
                throw KeychainError.deleteFailed(error)
            }
        } catch {
            throw KeychainError.deleteFailed(error)
        }
    }
    
    /// Check if an API key exists in the keychain
    /// - Parameter type: The type of API key to check
    /// - Returns: true if the key exists, false otherwise
    public func hasAPIKey(for type: APIKeyType) -> Bool {
        do {
            return try keychain.contains(type.service)
        } catch {
            return false
        }
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