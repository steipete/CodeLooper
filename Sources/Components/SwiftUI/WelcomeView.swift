import Defaults
import OSLog
import SwiftUI
import AXorcistLib
import ApplicationServices

// MARK: - Welcome View

struct WelcomeView: View {
    // Use ObservedObject instead of StateObject to allow creating a binding
    @ObservedObject var viewModel: WelcomeViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color
                Color(.windowBackgroundColor).edgesIgnoringSafeArea(.all)

                // Content
                VStack(spacing: 0) {
                    if viewModel.currentStep == .welcome {
                        WelcomeStepView(viewModel: viewModel)
                    } else if viewModel.currentStep == .accessibility {
                        AccessibilityStepView(viewModel: viewModel)
                    } else if viewModel.currentStep == .settings {
                        SettingsStepView(viewModel: viewModel)
                    } else if viewModel.currentStep == .complete {
                        CompletionStepView(viewModel: viewModel)
                    }

                    // Footer with navigation for non-complete steps
                    if viewModel.currentStep != .complete {
                        FooterView(viewModel: viewModel)
                    }
                }
                .frame(
                    width: UserInterfaceConstants.constants.settingsWindowSize.width,
                    height: UserInterfaceConstants.constants.settingsWindowSize.height
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2) // Center in window
            }
        }
    }
}

// MARK: - Welcome Step View

struct WelcomeStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Logo and header area
            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .padding(.top, 40)

                Text("Welcome to CodeLooper")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                Text("Your coding companion for macOS")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }

            // Main content area with features
            VStack(spacing: 30) {
                FeatureRow(
                    iconName: "rectangle.on.rectangle.angled",
                    title: "Code assistance",
                    description: "Get help with your coding tasks and projects"
                )

                FeatureRow(
                    iconName: "gearshape.2",
                    title: "System integration",
                    description: "Works seamlessly with your macOS workflow"
                )

                FeatureRow(
                    iconName: "lock.shield",
                    title: "Privacy focused",
                    description: "Your code stays on your machine"
                )
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 20)
            .background(Color(.windowBackgroundColor).brightness(-0.03))

            Spacer(minLength: 0)

            // Bottom button area
            VStack(spacing: 15) {
                Button(
                    action: {
                        viewModel.goToNextStep()
                    },
                    label: {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                )
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 40)
                .padding(.top, 20)

                HStack(spacing: 4) {
                    Text("Need help?")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    Text("Visit our GitHub")
                        .font(.system(size: 13))
                        .foregroundColor(Color.accentColor)
                        .underline()
                        .onTapGesture {
                            if let url = URL(string: "https://github.com/codelooper/codelooper") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                }
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Accessibility Step View

struct AccessibilityStepView: View {
    var viewModel: WelcomeViewModel
    @State private var accessibilityStatusMessage: String = "Status: Unknown"
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Accessibility icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "universal.access")
                    .font(.system(size: 40))
                    .foregroundColor(Color.accentColor)
            }
            .padding(.bottom, 30)
            
            // Title and description
            Text("Accessibility Permissions")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 12)
            
            Text("CodeLooper needs Accessibility permissions to monitor and interact with other applications like Cursor.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
                .padding(.bottom, 40)
            
            // Permission settings section
            VStack(spacing: 20) {
                // Open settings button
                Button(
                    action: {
                        openAccessibilitySettings()
                    },
                    label: {
                        Text("Open System Accessibility Settings")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                )
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 20)
                
                Text("After opening settings, find 'CodeLooper' in the Accessibility list and enable it.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Status section
                VStack(spacing: 12) {
                    Text(accessibilityStatusMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(accessibilityStatusMessage.contains("Granted") ? .green : .secondary)
                    
                    Button(
                        action: {
                            Task {
                                await checkAccessibilityPermissions()
                            }
                        },
                        label: {
                            Text("Check Permissions")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(6)
                        }
                    )
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 40)
            .background(Color(.windowBackgroundColor).brightness(-0.03))
            .cornerRadius(12)
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    @MainActor
    private func checkAccessibilityPermissions() async {
        let granted = AXIsProcessTrusted()
        if granted {
            accessibilityStatusMessage = "Status: Granted ✓"
        } else {
            accessibilityStatusMessage = "Status: Not Granted. Please enable in System Settings."
        }
    }
}

// MARK: - Settings Step View

struct SettingsStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Settings icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: "gearshape.2")
                    .font(.system(size: 40))
                    .foregroundColor(Color.accentColor)
            }
            .padding(.bottom, 30)

            // Title and description
            Text("Configure Settings")
                .font(.system(size: 28, weight: .bold))
                .padding(.bottom, 12)

            Text("Customize how CodeLooper works for you.")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
                .padding(.bottom, 40)

            // Settings options
            VStack(spacing: 20) {
                // Start at login option
                VStack(spacing: 8) {
                    Toggle("Start at login", isOn: Binding(
                        get: { viewModel.startAtLogin },
                        set: { viewModel.updateStartAtLogin($0) }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                    .padding(.horizontal, 20)

                    Text("Launch CodeLooper automatically when you log in")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(Color(.windowBackgroundColor).brightness(-0.03))
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    var iconName: String
    var title: String
    var description: String

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16) {
            GridRow {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: iconName)
                        .font(.system(size: 22))
                        .foregroundColor(Color.accentColor)
                }
                .gridCellAnchor(.center)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .gridCellAnchor(.leading)

                Spacer()
                    .gridCellUnsizedAxes([.horizontal])
            }
        }
    }
}

// MARK: - Completion Step View

struct CompletionStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .padding(.top, 40)

                Text("All Set! 🎉")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                Text("CodeLooper is now configured and ready to help with your coding tasks")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                    .padding(.bottom, 30)
            }

            // Main content with success message
            VStack(spacing: 30) {
                VStack(spacing: 25) {
                    // Success icon
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 120, height: 120)

                        Image(systemName: "checkmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)

                    // Success info
                    VStack(spacing: 16) {
                        Text("The app will run in your menu bar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        Text("You can access CodeLooper's features from the menu bar icon at any time")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Start at login reminder
                    if viewModel.startAtLogin {
                        Text("✓ CodeLooper will start automatically at login")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                            .padding(.top, 10)
                    }
                }
                .padding(40)
                .background(Color(.windowBackgroundColor).brightness(-0.03))
                .cornerRadius(12)
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 0)

            // Get started button
            Button(
                action: {
                    viewModel.finishOnboarding()
                },
                label: {
                    Text("Start Using CodeLooper")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 46)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }
            )
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 30)
        }
    }
}

// MARK: - Footer View

struct FooterView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Progress indicators using Grid for evenly spaced dots
            Grid(alignment: .center, horizontalSpacing: 10) {
                GridRow {
                    ForEach(WelcomeStep.allCases, id: \.self) { step in
                        let isActive = viewModel.currentStep.rawValue >= step.rawValue
                        let fillColor = isActive ? Color.accentColor : Color.gray.opacity(0.3)

                        Circle()
                            .fill(fillColor)
                            .frame(width: 8, height: 8)
                            .gridCellAnchor(.center)
                    }
                }
            }
            .padding(.bottom, 5)

            // Navigation buttons with Grid for better alignment
            Grid {
                GridRow {
                    Button(
                        action: {
                            viewModel.goToPreviousStep()
                        },
                        label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(Color.accentColor)
                            .font(.system(size: 15, weight: .medium))
                        }
                    )
                    .buttonStyle(PlainButtonStyle())
                    .gridCellAnchor(.leading)

                    Button(
                        action: {
                            viewModel.goToNextStep()
                        },
                        label: {
                            HStack(spacing: 6) {
                                Text("Continue")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                        }
                    )
                    .buttonStyle(PlainButtonStyle())
                    .gridCellAnchor(.trailing)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }
}

#Preview {
    WelcomeView(viewModel: WelcomeViewModel(
        loginItemManager: LoginItemManager.shared
    ))
}
