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
                    // Header for current step (optional, could be nice)
                    Text(viewModel.currentStep.description)
                        .font(.title2.weight(.semibold))
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        .opacity(viewModel.currentStep == .welcome ? 0 : 1) // Hide for initial welcome step

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
                            .padding(.bottom, 20) // Add some bottom padding for the footer
                    }
                }
                .padding(.horizontal, 20) // Add horizontal padding to the main VStack
                .frame(
                    width: geometry.size.width, // Use full geometry width
                    height: geometry.size.height // Use full geometry height
                )
            }
        }
    }
}

// MARK: - Welcome Step View

struct WelcomeStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: 20) { // Increased main spacing
            // Logo and header area
            VStack(spacing: 15) { // Adjusted spacing
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70) // Slightly smaller logo
                    .padding(.top, 20) // Reduced top padding

                Text("Welcome to CodeLooper")
                    .font(.title.weight(.bold)) // Larger font
                    .foregroundColor(.primary)

                Text("Your intelligent assistant for macOS automation and workflow enhancement.") // Slightly more descriptive
                    .font(.headline.weight(.regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30) // Ensure text wraps nicely
            }
            .padding(.bottom, 20)

            // Main content area with features
            VStack(alignment: .leading, spacing: 25) { // Adjusted spacing, alignment
                FeatureRow(
                    iconName: "sparkles.rectangle.stack", // More relevant icon
                    title: "Automated Workflow Assistance",
                    description: "CodeLooper monitors and assists with repetitive tasks."
                )

                FeatureRow(
                    iconName: "keyboard.badge.eye", // More relevant icon
                    title: "Cursor Supervision Engine",
                    description: "Keeps an eye on Cursor instances to ensure smooth operation."
                )

                FeatureRow(
                    iconName: "lock.shield.fill", // Using filled variant
                    title: "Privacy First",
                    description: "All processing happens locally on your Mac."
                )
            }
            .padding(.vertical, 25) // Adjusted padding
            .padding(.horizontal, 20)

            Spacer(minLength: 20) // Ensure some space

            // Bottom button area
            VStack(spacing: 15) {
                Button {
                    viewModel.goToNextStep()
                } label: {
                    Text("Get Started")
                        .fontWeight(.medium)
                        .frame(maxWidth: 220) // Set a max width for the button
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain) // Use plain to allow custom background
                .padding(.top, 10)

                HStack(spacing: 4) {
                    Text("Need help?")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    Link("Visit our GitHub", destination: URL(string: "https://github.com/steipete/CodeLooper")!) // Updated link
                        .font(.callout)
                        .foregroundColor(Color.accentColor)
                        .underline()
                }
                .padding(.bottom, 10) // Reduced bottom padding
            }
        }
        .padding(.bottom, 10) // Padding for the whole step view
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Allow it to fill available space
    }
}

// MARK: - Accessibility Step View

struct AccessibilityStepView: View {
    var viewModel: WelcomeViewModel
    @State private var accessibilityStatusMessage: String = "Status: Unknown"
    
    var body: some View {
        VStack(spacing: 20) { // Consistent spacing
            Spacer(minLength: 10) // Add a little space at the top
            
            // Accessibility icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 70, height: 70) // Slightly smaller icon
                
                Image(systemName: "figure.hand.tap.computer") // More descriptive icon
                    .font(.system(size: 36))
                    .foregroundColor(Color.accentColor)
            }
            .padding(.bottom, 20)
            
            // Title and description (using .title3 for consistency with other potential step titles)
            // Title is now handled by the parent WelcomeView if the new structure is kept.
            // Text("Accessibility Permissions")
            // .font(.title3.weight(.semibold))
            // .padding(.bottom, 8)
            
            Text("CodeLooper needs Accessibility permissions to monitor and interact with other applications on your behalf. This is essential for its core functionality.")
                .font(.headline.weight(.regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40) // Adjusted padding
                .padding(.bottom, 30)
            
            // Permission settings section
            VStack(spacing: 15) { // Adjusted spacing
                // Open settings button
                Button {
                    viewModel.handleOpenAccessibilitySettingsAndPrompt()
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Open System Accessibility Settings")
                    }
                    .fontWeight(.medium)
                    .frame(maxWidth: 300) // Consistent button width
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                
                Text("After opening settings, find CodeLooper in the list and enable the switch.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                // Status section
                VStack(spacing: 10) { // Adjusted spacing
                    Text(accessibilityStatusMessage)
                        .font(.callout.weight(.medium))
                        .foregroundColor(accessibilityStatusMessage.contains("Granted") ? .green : (accessibilityStatusMessage.contains("Not Granted") ? .orange : .secondary))
                        .onAppear { Task { await checkAccessibilityPermissions() } } // Check on appear
                    
                    Button {
                        Task {
                            await checkAccessibilityPermissions()
                        }
                    } label: {
                        Text("Re-check Permissions")
                            .font(.caption.weight(.medium))
                            // .foregroundColor(Color.accentColor)
                            // .padding(.horizontal, 12)
                            // .padding(.vertical, 6)
                            // .background(Color.accentColor.opacity(0.1))
                            // .cornerRadius(6)
                    }
                    // .buttonStyle(PlainButtonStyle()) // Using default link style now
                }
                .padding(.top, 5)
            }
            .padding(.vertical, 20) // Adjusted padding
            .padding(.horizontal, 30)
            // .background(Color(.windowBackgroundColor).brightness(-0.03)) // Removing background
            // .cornerRadius(12) // Removing corner radius
            .padding(.horizontal, 20)
            
            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { // Initial check when the view appears
            Task { await checkAccessibilityPermissions() }
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
        VStack(spacing: 20) { // Consistent spacing
            Spacer(minLength: 10)

            // Settings icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 70, height: 70) // Slightly smaller icon

                Image(systemName: "slider.horizontal.3") // More fitting icon
                    .font(.system(size: 36))
                    .foregroundColor(Color.accentColor)
            }
            .padding(.bottom, 20)

            // Title and description
            // Title is now handled by the parent WelcomeView if the new structure is kept.
            // Text("Configure Settings")
            // .font(.title3.weight(.semibold))
            // .padding(.bottom, 8)

            Text("Customize CodeLooper to fit your workflow. You can change these settings later.")
                .font(.headline.weight(.regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 30)

            // Settings options
            VStack(spacing: 20) {
                // Start at login option
                Toggle("Launch CodeLooper automatically at Login", isOn: Binding(
                    get: { viewModel.startAtLogin },
                    set: { viewModel.updateStartAtLogin($0) }
                ))
                .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
                .padding(.horizontal, 20) // Padding for the toggle row

                // Potentially add another key setting here if desired for the welcome flow
                // For example, a shortcut recorder if it's critical for first use.
                // KeyboardShortcuts.Recorder("Toggle Monitoring Shortcut:", name: .toggleMonitoring)
                // .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 20)
            // .background(Color(.windowBackgroundColor).brightness(-0.03)) // Removing background
            // .cornerRadius(12) // Removing corner radius
            .frame(maxWidth: 400) // Constrain width of this section

            Spacer(minLength: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(spacing: 20) { // Consistent spacing
            Spacer(minLength: 10)
            // Header
            VStack(spacing: 15) { // Adjusted spacing
                Image("logo") // Keep logo for brand reinforcement
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 70, height: 70)
                    .padding(.top, 20)

                // Title is now handled by the parent WelcomeView if the new structure is kept.
                // Text("All Set! 🎉")
                // .font(.title3.weight(.semibold))
                // .padding(.bottom, 8)

                Text("CodeLooper is now configured and ready to assist you!")
                    .font(.headline.weight(.regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }

            // Main content with success message
            VStack(spacing: 25) { // Adjusted spacing
                VStack(spacing: 20) { // Adjusted spacing
                    // Success icon
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.8))
                            .frame(width: 90, height: 90) // Slightly smaller

                        Image(systemName: "checkmark.circle.fill") // Using a filled system icon
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50) // Adjusted size
                            .foregroundColor(.white)
                    }
                    .padding(.top, 10)

                    // Success info
                    VStack(spacing: 12) { // Adjusted spacing
                        Text("CodeLooper will run quietly in your menu bar.")
                            .font(.callout.weight(.medium))
                            .foregroundColor(.primary)

                        Text("Access its features and settings from the menu bar icon at any time.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }

                    // Start at login reminder
                    if viewModel.startAtLogin {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("CodeLooper will start automatically at login.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 5)
                    }
                }
                .padding(30) // Adjusted padding
                // .background(Color(.windowBackgroundColor).brightness(-0.03)) // Removing background
                // .cornerRadius(12) // Removing corner radius
                .frame(maxWidth: 400)
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 20)

            // Get started button
            Button {
                viewModel.finishOnboarding()
            } label: {
                Text("Start Using CodeLooper")
                    .fontWeight(.medium)
                    .frame(maxWidth: 250) // Consistent button width
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
