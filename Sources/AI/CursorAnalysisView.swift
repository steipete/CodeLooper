import SwiftUI
import Defaults

public struct CursorAnalysisView: View {
    @StateObject private var analyzer = CursorScreenshotAnalyzer()
    @State private var customPrompt = ""
    @State private var selectedPromptType = PromptType.general
    @Default(.aiProvider) private var aiProvider
    @Default(.aiModel) private var aiModel
    
    private enum PromptType: String, CaseIterable {
        case general = "General Analysis"
        case errors = "Error Detection"
        case progress = "Progress Check"
        case code = "Code Understanding"
        case custom = "Custom Prompt"
        
        var prompt: String {
            switch self {
            case .general:
                return CursorScreenshotAnalyzer.AnalysisPrompts.generalAnalysis
            case .errors:
                return CursorScreenshotAnalyzer.AnalysisPrompts.errorDetection
            case .progress:
                return CursorScreenshotAnalyzer.AnalysisPrompts.progressCheck
            case .code:
                return CursorScreenshotAnalyzer.AnalysisPrompts.codeUnderstanding
            case .custom:
                return ""
            }
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection
            
            Divider()
            
            promptSection
            
            actionSection
            
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
        .padding()
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cursor Window Analysis")
                .font(.title2)
                .fontWeight(.semibold)
            
            HStack {
                Label("Provider: \(aiProvider.displayName)", systemImage: "cpu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label("Model: \(aiModel.displayName)", systemImage: "brain")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Analysis Type", selection: $selectedPromptType) {
                ForEach(PromptType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            if selectedPromptType == .custom {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Prompt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $customPrompt)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 80)
                        .border(Color.gray.opacity(0.2))
                }
            }
        }
    }
    
    private var actionSection: some View {
        HStack {
            Button("Analyze Cursor Window") {
                Task {
                    await analyzeWindow()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(analyzer.isAnalyzing || (selectedPromptType == .custom && customPrompt.isEmpty))
            
            Button("Clear") {
                analyzer.lastAnalysis = nil
                analyzer.lastError = nil
            }
            .disabled(analyzer.lastAnalysis == nil && analyzer.lastError == nil)
        }
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