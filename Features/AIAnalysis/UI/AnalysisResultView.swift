import Defaults
import DesignSystem
import SwiftUI

public struct CursorAnalysisView: View {
    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            headerSection

            DSDivider()

            promptSection

            if analyzer.isAnalyzing {
                ProgressView("Analyzing Cursor window...")
                    .frame(maxWidth: .infinity)
                    .padding()
            }

            if let error = analyzer.lastError {
                errorView(error)
            }

            if let analysis = analyzer.lastAnalysis {
                analysisResultView(analysis)
            }

            Spacer()
        }
        .onAppear {
            // Check versions if not checked recently
            Task {
                if mcpVersionService.lastCheckDate == nil ||
                    Date().timeIntervalSince(mcpVersionService.lastCheckDate!) > 3600
                { // 1 hour
                    await mcpVersionService.checkAllVersions()
                }
            }
        }
    }

    // MARK: Private

    private enum PromptType: String, CaseIterable {
        case general = "General Analysis"
        case errors = "Error Detection"
        case progress = "Progress Check"
        case code = "Code Understanding"
        case working = "Working Detection"
        case custom = "Custom Prompt"

        // MARK: Internal

        var prompt: String {
            switch self {
            case .general:
                CursorScreenshotAnalyzer.AnalysisPrompts.generalAnalysis
            case .errors:
                CursorScreenshotAnalyzer.AnalysisPrompts.errorDetection
            case .progress:
                CursorScreenshotAnalyzer.AnalysisPrompts.progressCheck
            case .code:
                CursorScreenshotAnalyzer.AnalysisPrompts.codeUnderstanding
            case .working:
                CursorScreenshotAnalyzer.AnalysisPrompts.working
            case .custom:
                ""
            }
        }
    }

    private static let timeAgoFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .short
        return formatter
    }()

    @StateObject private var analyzer = CursorScreenshotAnalyzer()
    @StateObject private var mcpVersionService = MCPVersionService.shared
    @State private var customPrompt = ""
    @State private var selectedPromptType = PromptType.general

    @Default(.aiProvider) private var aiProvider
    @Default(.aiModel) private var aiModel

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(ColorPalette.textSecondary)
                Text("Provider: \(aiProvider.displayName)")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)

                Image(systemName: "brain")
                    .foregroundColor(ColorPalette.textSecondary)
                Text("Model: \(aiModel.displayName)")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)

                Spacer()

                if mcpVersionService.isChecking {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Checking versions...")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                } else if let lastCheck = mcpVersionService.lastCheckDate {
                    Text("Updated: \(Self.timeAgoFormatter.localizedString(for: lastCheck, relativeTo: Date()))")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                }
            }

            // MCP Extensions Version Info
            mcpExtensionsSection
        }
    }

    private var mcpExtensionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text("MCP Extensions")
                .font(Typography.caption1(.medium))
                .foregroundColor(ColorPalette.text)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: Spacing.xSmall) {
                ForEach(MCPExtensionType.allCases) { mcpExtension in
                    mcpExtensionRow(mcpExtension)
                }
            }
        }
        .padding(.top, Spacing.xSmall)
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Text("Analysis Type")
                    .font(Typography.body(.medium))
                    .foregroundColor(ColorPalette.text)
                    .frame(width: 120, alignment: .leading)

                Picker("", selection: $selectedPromptType) {
                    ForEach(PromptType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)

                Button("Analyze Cursor Window") {
                    Task {
                        await analyzeWindow()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(analyzer.isAnalyzing || (selectedPromptType == .custom && customPrompt.isEmpty))

                DSButton("Clear", style: .secondary) {
                    analyzer.lastAnalysis = nil
                    analyzer.lastError = nil
                }
                .disabled(analyzer.lastAnalysis == nil && analyzer.lastError == nil)
            }

            if selectedPromptType == .custom {
                HStack(alignment: .top) {
                    Text("Custom Prompt")
                        .font(Typography.body(.medium))
                        .foregroundColor(ColorPalette.text)
                        .frame(width: 120, alignment: .leading)

                    TextEditor(text: $customPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .border(ColorPalette.border)
                }
            }
        }
    }

    private func mcpExtensionRow(_ mcpExtension: MCPExtensionType) -> some View {
        HStack(spacing: Spacing.xxSmall) {
            Image(systemName: mcpExtension.iconName)
                .foregroundColor(ColorPalette.textSecondary)
                .frame(width: 12)

            Text(mcpExtension.displayName)
                .font(Typography.caption2())
                .foregroundColor(ColorPalette.text)
                .lineLimit(1)

            Spacer()

            let latestVersion = mcpVersionService.getLatestVersion(for: mcpExtension)
            let hasUpdate = mcpVersionService.hasUpdate(for: mcpExtension)

            Text(latestVersion)
                .font(Typography.caption2(.medium))
                .foregroundColor(hasUpdate ? ColorPalette.warning : ColorPalette.success)

            if hasUpdate {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(ColorPalette.warning)
                    .font(.caption2)
            }
        }
        .padding(.horizontal, Spacing.xSmall)
        .padding(.vertical, 2)
        .background(ColorPalette.backgroundSecondary)
        .cornerRadius(4)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.red)

            Text(error.localizedDescription)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
    }

    private func analysisResultView(_ analysis: ImageAnalysisResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Analysis Result", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundColor(.green)

            ScrollView {
                Text(analysis.text)
                    .font(.system(.body, design: .default))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(8)
            }

            if let tokens = analysis.tokensUsed {
                Text("Tokens used: \(tokens)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func analyzeWindow() async {
        do {
            if selectedPromptType == .custom {
                _ = try await analyzer.analyzeWithCustomPrompt(customPrompt)
            } else {
                let prompt = selectedPromptType.prompt
                _ = try await analyzer.analyzeWithCustomPrompt(prompt)
            }
        } catch {
            analyzer.lastError = error
        }
    }
}

#if DEBUG
    struct CursorAnalysisView_Previews: PreviewProvider {
        static var previews: some View {
            CursorAnalysisView()
        }
    }
#endif
