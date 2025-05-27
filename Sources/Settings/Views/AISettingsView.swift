import SwiftUI
import Defaults
import Security
import DesignSystem

struct AISettingsView: View {
    // MARK: - Status Messages
    private enum StatusMessage {
        static let keepTyping = "🔑 Keep typing..."
        static let validatingSoon = "⏳ Validating soon..."
        static let validatingAPIKey = "🔄 Validating API key..."
        static let validatingOllama = "🔄 Testing Ollama connection..."
        static let checkingConnection = "⏳ Checking connection..."
        static let checkingProvider: @Sendable (String) -> String = { (provider: String) in "⏳ Checking \(provider) connection..." }
        static let invalidAPIKeyFormat = "⚠️ API key should start with 'sk-' and be at least 48 characters"
        static let invalidURLFormat = "⚠️ Invalid URL format"
        static let openAIConnected = "✓ OpenAI connected successfully"
        static let ollamaConnected: @Sendable ([String]) -> String = { (models: [String]) in "✓ Ollama connected - Models available: \(models.joined(separator: ", "))" }
    }
    
    @Default(.aiProvider) private var aiProvider
    @Default(.aiModel) private var aiModel
    @Default(.ollamaBaseURL) private var ollamaBaseURL
    
    @State private var showAPIKey = false
    @State private var openAIAPIKey = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    @State private var isAutoTesting = false
    @StateObject private var aiManager = AIServiceManager()
    
    private let apiKeyDebouncer = Debouncer(delay: 2.0)
    
    var body: some View {
        Form {
            Section {
                Picker("AI Provider", selection: $aiProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: aiProvider) { _, newValue in
                    configureAIManager()
                    aiModel = availableModels.first ?? .gpt4o
                    connectionTestResult = nil
                    isAutoTesting = false
                    
                    // Test the new provider automatically
                    Task {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                        
                        if (newValue == .openAI && !openAIAPIKey.isEmpty) ||
                           (newValue == .ollama) {
                            connectionTestResult = StatusMessage.checkingProvider(newValue.displayName)
                            await testConnection()
                        }
                    }
                }
                
                Picker("Model", selection: $aiModel) {
                    ForEach(availableModels) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                .disabled(availableModels.isEmpty)
            }
            
            Section {
                switch aiProvider {
                case .openAI:
                    openAISettings
                case .ollama:
                    ollamaSettings
                }
            }
            
            Section {
                connectionTestSection
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Image Analysis")
                        .font(.headline)
                    Text("The AI service will be used to analyze screenshots of Cursor windows and provide insights about what the application is currently doing.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .onAppear {
            openAIAPIKey = loadAPIKeyFromKeychain(service: "CODELOOPER_OPENAI_API_KEY")
            
            // Configure AI manager after loading API key
            Task { @MainActor in
                configureAIManager()
                
                // Small delay to let UI settle
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // Only test if we have credentials
                if (aiProvider == .openAI && !openAIAPIKey.isEmpty) ||
                   (aiProvider == .ollama) {
                    connectionTestResult = StatusMessage.checkingConnection
                    await testConnection()
                }
            }
        }
    }
    
    private var openAISettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if showAPIKey {
                    TextField("API Key", text: $openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: openAIAPIKey) { _, newValue in
                            handleAPIKeyChange(newValue)
                        }
                } else {
                    SecureField("API Key", text: $openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: openAIAPIKey) { _, newValue in
                            handleAPIKeyChange(newValue)
                        }
                }
                
                Button(action: { showAPIKey.toggle() }) {
                    Image(systemName: showAPIKey ? "eye.slash" : "eye")
                }
                .buttonStyle(.borderless)
            }
            
            if isAutoTesting || connectionTestResult != nil {
                HStack {
                    if isAutoTesting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(connectionTestResult ?? "")
                        .font(.caption)
                        .foregroundColor(connectionTestResult?.contains("✓") == true ? .green : 
                                       connectionTestResult?.contains("✗") == true ? .red : .secondary)
                }
                .padding(.top, 4)
            }
            
            Link("Get your API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(.caption)
        }
    }
    
    private var ollamaSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Base URL", text: $ollamaBaseURL)
                .textFieldStyle(.roundedBorder)
                .onChange(of: ollamaBaseURL) { _, newValue in
                    configureAIManager()
                    
                    // Auto-test if URL looks valid
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        connectionTestResult = StatusMessage.validatingSoon
                        isAutoTesting = true
                        apiKeyDebouncer.call {
                            Task { @MainActor in
                                self.connectionTestResult = StatusMessage.validatingOllama
                                await self.testConnection()
                                self.isAutoTesting = false
                            }
                        }
                    } else {
                        connectionTestResult = nil
                        isAutoTesting = false
                    }
                }
            
            if isAutoTesting || connectionTestResult != nil {
                HStack {
                    if isAutoTesting {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(connectionTestResult ?? "")
                        .font(.caption)
                        .foregroundColor(connectionTestResult?.contains("✓") == true ? .green : 
                                       connectionTestResult?.contains("✗") == true ? .red : .secondary)
                }
                .padding(.top, 4)
            }
            
            Text("Default: http://localhost:11434")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Link("Install Ollama", destination: URL(string: "https://ollama.ai")!)
                .font(.caption)
        }
    }
    
    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                DSButton("Test Connection", style: .secondary) {
                    Task {
                        isAutoTesting = false
                        await testConnection()
                    }
                }
                .disabled(isTestingConnection || isAutoTesting || (aiProvider == .openAI && openAIAPIKey.isEmpty))
                
                if isTestingConnection && !isAutoTesting {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            
            Text("Connection will be automatically tested when you enter valid credentials")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var availableModels: [AIModel] {
        AIModel.allCases.filter { $0.provider == aiProvider }
    }
    
    private func configureAIManager() {
        switch aiProvider {
        case .openAI:
            if !openAIAPIKey.isEmpty {
                aiManager.configure(provider: .openAI, apiKey: openAIAPIKey)
                print("🔑 Configured OpenAI with API key (length: \(openAIAPIKey.count))")
            } else {
                print("⚠️ OpenAI API key is empty, not configuring")
            }
        case .ollama:
            if let url = URL(string: ollamaBaseURL) {
                aiManager.configure(provider: .ollama, baseURL: url)
            } else {
                aiManager.configure(provider: .ollama)
            }
        }
    }
    
    private func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil
        
        do {
            switch aiProvider {
            case .ollama:
                // For Ollama, check service and models separately
                let baseURL = URL(string: ollamaBaseURL) ?? URL(string: "http://localhost:11434")!
                let ollamaService = OllamaService(baseURL: baseURL)
                
                let (serviceRunning, visionModels) = try await ollamaService.checkServiceAndModels()
                
                if !serviceRunning {
                    throw AIServiceError.ollamaNotRunning
                }
                
                if visionModels.isEmpty {
                    throw AIServiceError.noVisionModelsInstalled
                }
                
                // Try to analyze with the selected model
                let testImage = createTestImage()
                let request = ImageAnalysisRequest(
                    image: testImage,
                    prompt: "Describe this image in one word",
                    model: aiModel
                )
                
                _ = try await aiManager.analyzeImage(request)
                connectionTestResult = StatusMessage.ollamaConnected(visionModels)
                
            case .openAI:
                // For OpenAI, ensure we have an API key
                if openAIAPIKey.isEmpty {
                    throw AIServiceError.apiKeyMissing
                }
                
                // Reconfigure to ensure API key is set
                aiManager.configure(provider: .openAI, apiKey: openAIAPIKey)
                
                let testImage = createTestImage()
                let request = ImageAnalysisRequest(
                    image: testImage,
                    prompt: "Describe this image in one word",
                    model: aiModel
                )
                
                _ = try await aiManager.analyzeImage(request)
                connectionTestResult = StatusMessage.openAIConnected
            }
        } catch let error as AIServiceError {
            var message = "✗ \(error.localizedDescription)"
            if let recovery = error.recoverySuggestion {
                message += "\n💡 \(recovery)"
            }
            connectionTestResult = message
        } catch {
            connectionTestResult = "✗ Connection failed: \(error.localizedDescription)"
        }
        
        isTestingConnection = false
    }
    
    private func storeAPIKeyInKeychain(_ apiKey: String, service: String) {
        let data = apiKey.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-key",
            kSecValueData as String: data
        ]
        
        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Error storing API key: \(status)")
        }
    }
    
    private func loadAPIKeyFromKeychain(service: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-key",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        }
        
        return ""
    }
    
    private func deleteAPIKeyFromKeychain(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-key"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    private func handleAPIKeyChange(_ newValue: String) {
        // Store/delete from keychain
        if !newValue.isEmpty {
            storeAPIKeyInKeychain(newValue, service: "CODELOOPER_OPENAI_API_KEY")
        } else {
            deleteAPIKeyFromKeychain(service: "CODELOOPER_OPENAI_API_KEY")
            connectionTestResult = nil
            isAutoTesting = false
            return
        }
        configureAIManager()
        
        // Show immediate feedback
        if newValue.count < 10 {
            connectionTestResult = StatusMessage.keepTyping
            isAutoTesting = false
        } else if isValidAPIKeyFormat(newValue) {
            connectionTestResult = StatusMessage.validatingSoon
            isAutoTesting = true
            apiKeyDebouncer.call {
                Task { @MainActor in
                    self.connectionTestResult = StatusMessage.validatingAPIKey
                    await self.testConnection()
                    self.isAutoTesting = false
                }
            }
        } else {
            connectionTestResult = StatusMessage.invalidAPIKeyFormat
            isAutoTesting = false
        }
    }
    
    private func isValidAPIKeyFormat(_ apiKey: String) -> Bool {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // OpenAI API keys should start with 'sk-' and be at least 48 characters
        return trimmed.hasPrefix("sk-") && trimmed.count >= 48
    }
    
    private func createTestImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.white.drawSwatch(in: NSRect(x: 0, y: 0, width: 100, height: 100))
        image.unlockFocus()
        return image
    }
}
