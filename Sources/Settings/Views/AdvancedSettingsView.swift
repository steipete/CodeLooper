import Defaults
import SwiftUI

struct AdvancedSettingsView: View {
    // Supervision Tuning Defaults
    @Default(.maxConnectionIssueRetries) var maxConnectionIssueRetries
    @Default(.maxConsecutiveRecoveryFailures) var maxConsecutiveRecoveryFailures
    @Default(.postInterventionObservationWindowSeconds) var postInterventionObservationWindowSeconds
    @Default(.sendNotificationOnPersistentError) var sendNotificationOnPersistentError: Bool
    @Default(.stuckDetectionTimeoutSeconds) var stuckDetectionTimeoutSeconds: TimeInterval

    // Sound Configuration
    @Default(.successfulInterventionSoundName) var successfulInterventionSoundName: String

    // Custom Locator Defaults
    @Default(.locatorJSONGeneratingIndicatorText) var locatorGeneratingIndicatorText: String
    @Default(.locatorJSONSidebarActivityArea) var locatorSidebarActivityArea: String
    @Default(.locatorJSONErrorMessagePopup) var locatorErrorMessagePopup: String
    @Default(.locatorJSONStopGeneratingButton) var locatorStopGeneratingButton: String
    @Default(.locatorJSONConnectionErrorIndicator) var locatorConnectionErrorIndicator: String
    @Default(.locatorJSONResumeConnectionButton) var locatorResumeConnectionButton: String
    @Default(.locatorJSONForceStopResumeLink) var locatorForceStopResumeLink: String
    @Default(.locatorJSONMainInputField) var locatorMainInputField: String

    private let locatorPlaceholders: [String: String] = [
        "generatingIndicatorText": "e.g., {\"criteria\":[{\"key\":\"AXValue\",\"value\":\"Generating...\",\"match_type\":\"contains\"}],\"type\":\"text\"}",
        "sidebarActivityArea": "e.g., {\"criteria\":[{\"key\":\"AXIdentifier\",\"value\":\"sidebar_main\",\"match_type\":\"exact\"}]}",
        "errorMessagePopup": "e.g., {\"criteria\":[{\"key\":\"AXRole\",\"value\":\"AXWindow\"},{\"key\":\"AXTitle\",\"value\":\"Error\",\"match_type\":\"contains\"}]}",
        "stopGeneratingButton": "e.g., {\"criteria\":[{\"key\":\"AXRole\",\"value\":\"AXButton\"},{\"key\":\"AXTitle\",\"value\":\"Stop\",\"match_type\":\"exact\"}]}",
        "connectionErrorIndicator": "e.g., {\"criteria\":[{\"key\":\"AXValue\",\"value\":\"We\'re having trouble connecting\",\"match_type\":\"contains\"}],\"type\":\"text\"}",
        "resumeConnectionButton": "e.g., {\"criteria\":[{\"key\":\"AXRole\",\"value\":\"AXButton\"},{\"key\":\"AXTitle\",\"value\":\"Resume\",\"match_type\":\"exact\"}]}",
        "forceStopResumeLink": "e.g., {\"criteria\":[{\"key\":\"AXValue\",\"value\":\"resume the conversation\",\"match_type\":\"contains\"}],\"type\":\"text\"}",
        "mainInputField": "e.g., {\"criteria\":[{\"key\":\"AXRole\",\"value\":\"AXTextArea\"},{\"key\":\"AXIdentifier\",\"value\":\"chat_input\"}]}"
    ]

    var body: some View {
        Form {
            Section(header: Text("Supervision Tuning")) {
                Stepper("Max 'Resume' clicks (Connection Issue): \\(maxConnectionIssueRetries)", value: $maxConnectionIssueRetries, in: 1...5)
                Stepper("Max Recovery Cycles (Persistent Error): \\(maxConsecutiveRecoveryFailures)", value: $maxConsecutiveRecoveryFailures, in: 1...5)
                TextField("Observation Window Post-Intervention (s)", value: $postInterventionObservationWindowSeconds, formatter: NumberFormatter.timeIntervalFormatter) 
                    .frame(maxWidth: 150)
                TextField("Stuck Detection Timeout (s)", value: $stuckDetectionTimeoutSeconds, formatter: NumberFormatter.generalSecondsFormatter)
                     .frame(maxWidth: 150)
                Toggle("Send Notification on Persistent Error", isOn: $sendNotificationOnPersistentError)
            }

            Section(header: Text("Sound Configuration")) {
                HStack {
                    Text("Successful Intervention Sound:")
                    TextField("Sound Name (e.g., Funk, Glass)", text: $successfulInterventionSoundName)
                }
                Text("Enter a system sound name (e.g., Funk, Glass, Sosumi) or a filename (e.g., my_sound.aiff) located in the app bundle's Sounds directory. Leave blank for default.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Custom Element Locators (JSON - Advanced)")) {
                Text("Override default AXorcist.Locator JSON definitions. Invalid JSON or locators may break functionality. Leave blank to use app default.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 5)
                
                Group {
                    locatorEditor(title: "Generating Indicator Text", textBinding: $locatorGeneratingIndicatorText, key: .locatorJSONGeneratingIndicatorText, placeholder: locatorPlaceholders["generatingIndicatorText"] ?? "")
                    locatorEditor(title: "Sidebar Activity Area", textBinding: $locatorSidebarActivityArea, key: .locatorJSONSidebarActivityArea, placeholder: locatorPlaceholders["sidebarActivityArea"] ?? "")
                    locatorEditor(title: "Error Message Popup", textBinding: $locatorErrorMessagePopup, key: .locatorJSONErrorMessagePopup, placeholder: locatorPlaceholders["errorMessagePopup"] ?? "")
                    locatorEditor(title: "Stop Generating Button", textBinding: $locatorStopGeneratingButton, key: .locatorJSONStopGeneratingButton, placeholder: locatorPlaceholders["stopGeneratingButton"] ?? "")
                }
                Group {
                    locatorEditor(title: "Connection Error Indicator", textBinding: $locatorConnectionErrorIndicator, key: .locatorJSONConnectionErrorIndicator, placeholder: locatorPlaceholders["connectionErrorIndicator"] ?? "")
                    locatorEditor(title: "Resume Connection Button", textBinding: $locatorResumeConnectionButton, key: .locatorJSONResumeConnectionButton, placeholder: locatorPlaceholders["resumeConnectionButton"] ?? "")
                    locatorEditor(title: "Force-Stop Resume Link", textBinding: $locatorForceStopResumeLink, key: .locatorJSONForceStopResumeLink, placeholder: locatorPlaceholders["forceStopResumeLink"] ?? "")
                    locatorEditor(title: "Main Input Field", textBinding: $locatorMainInputField, key: .locatorJSONMainInputField, placeholder: locatorPlaceholders["mainInputField"] ?? "")
                }

                Button("Reset All Locators to Defaults") {
                    Defaults.reset(
                        .locatorJSONGeneratingIndicatorText,
                        .locatorJSONSidebarActivityArea,
                        .locatorJSONErrorMessagePopup,
                        .locatorJSONStopGeneratingButton,
                        .locatorJSONConnectionErrorIndicator,
                        .locatorJSONResumeConnectionButton,
                        .locatorJSONForceStopResumeLink,
                        .locatorJSONMainInputField
                    )
                }
                .foregroundColor(.orange)
                .padding(.top)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Adjust frame as needed
    }

    @ViewBuilder
    private func locatorEditor(title: String, textBinding: Binding<String>, key: Defaults.Key<String>, placeholder: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Button("Reset") {
                    Defaults.reset(key)
                }.font(.caption)
            }
            TextEditor(text: textBinding)
                .font(.system(.body, design: .monospaced))
                .frame(height: 80)
                .border(Color.gray.opacity(0.5), width: 1)
                .overlay(alignment: .topLeading) {
                    if textBinding.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6))
                            .padding(EdgeInsets(top: 8, leading: 5, bottom: 0, trailing: 0))
                            .allowsHitTesting(false)
                    }
                }
            Text("Enter valid AXorcist.Locator JSON. Blank uses app default.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 3)
    }
}

extension NumberFormatter {
    static var generalSecondsFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 1.0 
        formatter.maximum = 300.0 
        formatter.maximumFractionDigits = 1
        return formatter
    }
    
}

#if DEBUG
struct AdvancedSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedSettingsView()
            .frame(width: 600, height: 800) // Example frame for preview
    }
}
#endif 
