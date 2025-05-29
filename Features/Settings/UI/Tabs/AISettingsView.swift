import Defaults
import DesignSystem
import SwiftUI

// Define a Notification name for AI Service configuration changes
extension Notification.Name {
    static let AIServiceConfigured = Notification.Name("AIServiceConfiguredNotification")
}

struct AISettingsView: View {
    // MARK: - Status Messages

    private enum StatusMessage {
        static let keepTyping = "🔑 Keep typing..."
        static let validatingSoon = "⏳ Validating soon..."
        static let validatingAPIKey = "🔄 Validating API key..."
        static let validatingOllama = "🔄 Testing Ollama connection..."
        static let checkingConnection = "⏳ Checking connection..."
        static let checkingProvider: @Sendable (String) -> String = { (provider: String) in
            "⏳ Checking \(provider) connection..."
        }

        static let invalidAPIKeyFormat = "⚠️ API key should start with 'sk-' and be at least 48 characters"
        static let invalidURLFormat = "⚠️ Invalid URL format"
        static let openAIConnected = "✓ OpenAI connected successfully"
        static let ollamaConnected: @Sendable ([String]) -> String = { (models: [String]) in
            "✓ Ollama connected - Models available: \(models.joined(separator: ", "))"
        }
    }

    @Default(.aiProvider) private var aiProvider
    @Default(.aiModel) private var aiModel
    @Default(.ollamaBaseURL) private var ollamaBaseURL

    @State private var showAPIKey = false
    @State private var openAIAPIKey = ""
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String?
    @State private var isAutoTesting = false

    private let apiKeyDebouncer = Debouncer(delay: 2.0)

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // AI Provider Configuration
            DSSettingsSection("AI Provider") {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    HStack {
                        Text("AI Provider")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                            .frame(width: 120, alignment: .leading)

                        Picker("", selection: $aiProvider) {
                            ForEach(AIProvider.allCases) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                        .onChange(of: aiProvider) { _, newValue in
                            configureAIManager()
                            // Ensure we select a model that's available for the new provider
                            let newAvailableModels = AIModel.allCases.filter { $0.provider == newValue }
                            if !newAvailableModels.contains(aiModel) {
                                aiModel = newAvailableModels.first ?? .gpt4o
                            }
                            connectionTestResult = nil
                            isAutoTesting = false

                            // Test the new provider automatically
                            Task {
                                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

                                if (newValue == .openAI && !openAIAPIKey.isEmpty) ||
                                    (newValue == .ollama)
                                {
                                    connectionTestResult = StatusMessage.checkingProvider(newValue.displayName)
                                    await testConnection()
                                }
                            }
                        }
                    }

                    DSDivider()

                    HStack {
                        Text("Model")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                            .frame(width: 120, alignment: .leading)

                        Picker("", selection: $aiModel) {
                            ForEach(availableModels) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(availableModels.isEmpty)
                    }
                }
            }

            // Provider-specific Settings
            DSSettingsSection("Configuration") {
                switch aiProvider {
                case .openAI:
                    openAISettings
                case .ollama:
                    ollamaSettings
                }
            }

            // Connection Test Note
            Text("Connection will be automatically tested when you enter valid credentials")
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Spacing.xxSmall)

            // Manual AI Window Analysis
            DSSettingsSection("Manual AI Window Analysis") {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    Text(
                        "The AI service will be used to analyze screenshots of Cursor windows and provide insights about what the application is currently doing."
                    )
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    CursorAnalysisView()
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
        .withDesignSystem()
        .onAppear {
            openAIAPIKey = loadAPIKeyFromKeychain(service: "CODELOOPER_OPENAI_API_KEY")

            // Configure AI manager after loading API key
            Task { @MainActor in
                configureAIManager()

                // Small delay to let UI settle
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Only test if we have credentials
                if (aiProvider == .openAI && !openAIAPIKey.isEmpty) ||
                    (aiProvider == .ollama)
                {
                    connectionTestResult = StatusMessage.checkingConnection
                    await testConnection()
                }
            }
        }
    }

    private var openAISettings: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Text("API Key")
                    .font(Typography.body(.medium))
                    .foregroundColor(ColorPalette.text)
                    .frame(width: 120, alignment: .leading)

                HStack {
                    if showAPIKey {
                        TextField("", text: $openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .onChange(of: openAIAPIKey) { _, newValue in
                                handleAPIKeyChange(newValue)
                            }
                    } else {
                        SecureField("", text: $openAIAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                            .onChange(of: openAIAPIKey) { _, newValue in
                                handleAPIKeyChange(newValue)
                            }
                    }

                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if isAutoTesting || connectionTestResult != nil {
                HStack {
                    if isAutoTesting {
                        DSShimmer(width: 16, height: 16, cornerRadius: 2)
                    }
                    Text(connectionTestResult ?? "")
                        .font(Typography.caption1())
                        .foregroundColor(connectionTestResult?.contains("✓") == true ? ColorPalette.success :
                            connectionTestResult?.contains("✗") == true ? ColorPalette.error : ColorPalette
                            .textSecondary)
                }
                .padding(.top, Spacing.xxSmall)
            }

            Link("Get your API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.primary)
        }
    }

    private var ollamaSettings: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack(alignment: .top) {
                Text("Base URL")
                    .font(Typography.body(.medium))
                    .foregroundColor(ColorPalette.text)
                    .frame(width: 120, alignment: .leading)

                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    TextField("Base URL", text: $ollamaBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
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

                    Text("Default: http://localhost:11434")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }

            if isAutoTesting || connectionTestResult != nil {
                HStack {
                    if isAutoTesting {
                        DSShimmer(width: 16, height: 16, cornerRadius: 2)
                    }
                    Text(connectionTestResult ?? "")
                        .font(Typography.caption1())
                        .foregroundColor(connectionTestResult?.contains("✓") == true ? ColorPalette.success :
                            connectionTestResult?.contains("✗") == true ? ColorPalette.error : ColorPalette
                            .textSecondary)
                }
                .padding(.top, Spacing.xxSmall)
            }

            Link("Install Ollama", destination: URL(string: "https://ollama.ai")!)
                .font(Typography.caption1())
                .foregroundColor(ColorPalette.primary)
        }
    }

    private var availableModels: [AIModel] {
        AIModel.allCases.filter { $0.provider == aiProvider }
    }

    private func configureAIManager() {
        // Now configures the shared instance
        AIServiceManager.shared.configureWithCurrentDefaults()

        // Log based on the shared manager's state or passed parameters if preferred
        let currentProvider = AIServiceManager.shared.currentProvider
        switch currentProvider {
        case .openAI:
            if !openAIAPIKey.isEmpty {
                print("🔑 Configured OpenAI with API key (length: \(openAIAPIKey.count))")
            } else {
                print("⚠️ OpenAI API key is empty, not configuring")
            }
        case .ollama:
            print("🦙 Configured Ollama with URL: \(Defaults[.ollamaBaseURL])")
        }
    }

    func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil

        // Re-configure the shared manager right before testing to ensure it has the latest credentials from the UI
        // fields
        // This is important because `configureAIManager` might be called on `onChange` of provider,
        // but not necessarily after every keystroke in API key or URL fields.
        let currentProvider = Defaults[.aiProvider]
        let currentAPIKey = (currentProvider == .openAI) ? openAIAPIKey : nil
        let currentOllamaURL = (currentProvider == .ollama) ? URL(string: ollamaBaseURL) : nil

        AIServiceManager.shared.configure(provider: currentProvider, apiKey: currentAPIKey, baseURL: currentOllamaURL)

        let providerName = AIServiceManager.shared.currentProvider.displayName
        let messagePrefix = isAutoTesting ? "" : "Testing \(providerName)... "

        if await AIServiceManager.shared.isServiceAvailable() {
            var successMessage = ""
            if AIServiceManager.shared.currentProvider == .ollama {
                let models = AIServiceManager.shared.supportedModels().map(\.displayName)
                successMessage = messagePrefix + StatusMessage.ollamaConnected(models)
            } else {
                successMessage = messagePrefix + StatusMessage.openAIConnected
            }
            connectionTestResult = successMessage
            NotificationCenter.default.post(name: .AIServiceConfigured, object: nil) // Post notification
        } else {
            connectionTestResult = "✗ Connection failed for \(providerName). Check settings."
        }
        isTestingConnection = false
        isAutoTesting = false
    }

    private func storeAPIKeyInKeychain(_ apiKey: String, service: String) {
        // Map the service string to APIKeyType
        if service == "CODELOOPER_OPENAI_API_KEY" {
            _ = APIKeyService.shared.saveOpenAIKey(apiKey)
        }
    }

    private func loadAPIKeyFromKeychain(service: String) -> String {
        // Map the service string to APIKeyType
        if service == "CODELOOPER_OPENAI_API_KEY" {
            return APIKeyService.shared.loadOpenAIKey()
        }
        return ""
    }

    private func deleteAPIKeyFromKeychain(service: String) {
        // Map the service string to APIKeyType
        if service == "CODELOOPER_OPENAI_API_KEY" {
            try? APIKeyService.shared.deleteAPIKey(for: .openAI)
        }
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

// MARK: - Preview

#if DEBUG
    struct AISettingsView_Previews: PreviewProvider {
        static var previews: some View {
            AISettingsView()
                .frame(width: 600, height: 700)
                .background(ColorPalette.background)
                .withDesignSystem()
        }
    }
#endif
