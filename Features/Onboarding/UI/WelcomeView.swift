import ApplicationServices
import AXorcist
import Defaults
import DesignSystem
import KeyboardShortcuts
import OSLog
import SwiftUI

// MARK: - Welcome View

struct WelcomeView: View {
    // Use ObservedObject instead of StateObject to allow creating a binding
    @ObservedObject var viewModel: WelcomeViewModel

    var body: some View {
        ZStack {
            // Modern gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    ColorPalette.background,
                    ColorPalette.backgroundSecondary.opacity(0.3)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                // Progress bar at top
                ProgressBar(currentStep: viewModel.currentStep)
                    .padding(.horizontal, Spacing.xLarge)
                    .padding(.top, Spacing.large)
                    .padding(.bottom, Spacing.medium)

                // Step content
                ZStack {
                    if viewModel.currentStep == .welcome {
                        WelcomeStepView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if viewModel.currentStep == .accessibility {
                        AccessibilityStepView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if viewModel.currentStep == .settings {
                        SettingsStepView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    } else if viewModel.currentStep == .complete {
                        CompletionStepView(viewModel: viewModel)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.currentStep)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Footer with navigation
                if viewModel.currentStep != .complete {
                    ModernFooterView(viewModel: viewModel)
                        .padding(.horizontal, Spacing.xLarge)
                        .padding(.bottom, Spacing.large)
                }
            }
        }
        .withDesignSystem()
    }
}

// MARK: - Welcome Step View

struct WelcomeStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            Spacer()
            
            // Logo and header area
            VStack(spacing: Spacing.large) {
                // Animated logo
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorPalette.primary.opacity(0.2),
                                    ColorPalette.primaryLight.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    
                    Image("logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                }
                .shadow(color: ColorPalette.primary.opacity(0.3), radius: 20, y: 10)

                VStack(spacing: Spacing.small) {
                    Text("Welcome to CodeLooper")
                        .font(Typography.largeTitle(.bold))
                        .foregroundColor(ColorPalette.text)

                    Text("Your intelligent AI assistant for Cursor IDE supervision")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, Spacing.xLarge)
                }
            }

            // Features in cards
            VStack(spacing: Spacing.medium) {
                ModernFeatureCard(
                    icon: "brain.filled.head.profile",
                    iconColor: ColorPalette.primary,
                    title: "AI-Powered Monitoring",
                    description: "Advanced detection and automatic recovery from stuck states"
                )
                
                ModernFeatureCard(
                    icon: "wand.and.rays",
                    iconColor: ColorPalette.success,
                    title: "Intelligent Automation",
                    description: "Handles connection errors and UI conflicts automatically"
                )
                
                ModernFeatureCard(
                    icon: "lock.shield.fill",
                    iconColor: ColorPalette.info,
                    title: "Privacy-First Design",
                    description: "All processing happens locally on your Mac"
                )
            }
            .padding(.horizontal, Spacing.medium)

            Spacer()

            // Get Started button
            DSButton("Get Started", style: .primary) {
                viewModel.goToNextStep()
            }
            .frame(width: 200)
            
            // Help link
            HStack(spacing: Spacing.xSmall) {
                Image(systemName: "questionmark.circle")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textTertiary)
                
                Link("Learn more", destination: URL(string: Constants.githubRepositoryURL)!)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.primary)
            }
            .padding(.bottom, Spacing.medium)
        }
        .frame(maxWidth: 600)
        .padding(.horizontal, Spacing.xLarge)
    }
}

// MARK: - Accessibility Step View

struct AccessibilityStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xLarge) {
                // Header
                VStack(spacing: Spacing.large) {
                    // Icon with gradient background
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        ColorPalette.primary.opacity(0.2),
                                        ColorPalette.primaryLight.opacity(0.1)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 90, height: 90)
                        
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 45))
                            .foregroundColor(ColorPalette.primary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .shadow(color: ColorPalette.primary.opacity(0.2), radius: 15, y: 5)
                    
                    VStack(spacing: Spacing.small) {
                        Text("Grant Required Permissions")
                            .font(Typography.title2(.bold))
                            .foregroundColor(ColorPalette.text)
                        
                        Text("CodeLooper needs these permissions to monitor and assist with Cursor IDE")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, Spacing.large)
                    }
                }
                .padding(.top, Spacing.large)

                // Permissions cards
                VStack(spacing: Spacing.large) {
                    // Accessibility Permission
                    PermissionCard(
                        icon: "hand.tap.fill",
                        iconColor: ColorPalette.primary,
                        title: "Accessibility Access",
                        description: "Required to detect and interact with Cursor's UI elements",
                        content: {
                            PermissionsView(showTitle: false, compact: false)
                        }
                    )
                    
                    // Automation Permission
                    PermissionCard(
                        icon: "gearshape.2.fill",
                        iconColor: ColorPalette.success,
                        title: "Automation Permission",
                        description: "Enables JavaScript injection and advanced Cursor control",
                        content: {
                            AutomationPermissionsView(showTitle: false, compact: false)
                        }
                    )
                    
                    // Screen Recording Permission
                    PermissionCard(
                        icon: "rectangle.dashed.badge.record",
                        iconColor: ColorPalette.info,
                        title: "Screen Recording",
                        description: "Allows AI analysis of Cursor windows for intelligent assistance",
                        content: {
                            ScreenRecordingPermissionsView(showTitle: false, compact: false)
                        }
                    )
                }
                .padding(.horizontal, Spacing.large)
                
                // Info box
                DSCard(style: .filled) {
                    HStack(spacing: Spacing.medium) {
                        Image(systemName: "info.circle.fill")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.info)
                        
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Privacy First")
                                .font(Typography.caption1(.medium))
                                .foregroundColor(ColorPalette.text)
                            
                            Text("All permissions are used locally. No data leaves your Mac.")
                                .font(Typography.caption2())
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, Spacing.large)
                .padding(.bottom, Spacing.xLarge)
            }
        }
        .frame(maxWidth: 700)
    }
}

// MARK: - Settings Step View

struct SettingsStepView: View {
    var viewModel: WelcomeViewModel

    var body: some View {
        VStack(spacing: Spacing.xLarge) {
            Spacer()
            
            // Header
            VStack(spacing: Spacing.large) {
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    ColorPalette.success.opacity(0.2),
                                    ColorPalette.success.opacity(0.1)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 45))
                        .foregroundColor(ColorPalette.success)
                        .symbolRenderingMode(.hierarchical)
                }
                .shadow(color: ColorPalette.success.opacity(0.2), radius: 15, y: 5)
                
                VStack(spacing: Spacing.small) {
                    Text("Initial Setup")
                        .font(Typography.title2(.bold))
                        .foregroundColor(ColorPalette.text)
                    
                    Text("Configure your preferences. You can change these anytime in settings.")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, Spacing.large)
                }
            }

            // Settings cards
            VStack(spacing: Spacing.medium) {
                // Launch at login
                DSCard(style: .outlined) {
                    HStack(spacing: Spacing.medium) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.small)
                                .fill(ColorPalette.primary.opacity(0.1))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "power.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(ColorPalette.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Launch at Login")
                                .font(Typography.body(.medium))
                                .foregroundColor(ColorPalette.text)
                            
                            Text("Start CodeLooper automatically when you log in")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        
                        Spacer()
                        
                        DSToggle(
                            "",
                            isOn: Binding(
                                get: { viewModel.startAtLogin },
                                set: { viewModel.updateStartAtLogin($0) }
                            )
                        )
                    }
                }
                
                // Menu bar icon
                DSCard(style: .outlined) {
                    HStack(spacing: Spacing.medium) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.small)
                                .fill(ColorPalette.info.opacity(0.1))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 20))
                                .foregroundColor(ColorPalette.info)
                        }
                        
                        VStack(alignment: .leading, spacing: Spacing.xSmall) {
                            Text("Menu Bar Access")
                                .font(Typography.body(.medium))
                                .foregroundColor(ColorPalette.text)
                            
                            Text("Access CodeLooper from your menu bar")
                                .font(Typography.caption1())
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(ColorPalette.success)
                    }
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, Spacing.large)
            
            // Keyboard shortcut info
            DSCard(style: .filled) {
                HStack(spacing: Spacing.medium) {
                    Image(systemName: "keyboard")
                        .font(Typography.body())
                        .foregroundColor(ColorPalette.primary)
                    
                    Text("You can set up keyboard shortcuts in the settings after setup")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Spacer()
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, Spacing.large)
            
            Spacer()
        }
        .frame(maxWidth: 700)
    }
}

// MARK: - Modern Feature Card

struct ModernFeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: Spacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.CornerRadius.medium)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                iconColor.opacity(0.15),
                                iconColor.opacity(0.05)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(iconColor)
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(title)
                    .font(Typography.body(.semibold))
                    .foregroundColor(ColorPalette.text)
                
                Text(description)
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(Spacing.medium)
        .background(ColorPalette.background)
        .cornerRadius(Layout.CornerRadius.medium)
        .shadow(color: ColorPalette.shadowLight, radius: 5, y: 2)
    }
}

// MARK: - Permission Card

struct PermissionCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let content: () -> Content
    
    var body: some View {
        DSCard(style: .outlined) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                HStack(spacing: Spacing.medium) {
                    ZStack {
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.small)
                            .fill(iconColor.opacity(0.1))
                            .frame(width: 45, height: 45)
                        
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(iconColor)
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.xSmall) {
                        Text(title)
                            .font(Typography.body(.semibold))
                            .foregroundColor(ColorPalette.text)
                        
                        Text(description)
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Spacer()
                }
                
                content()
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
                    .lineSpacing(4)
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
                            .lineSpacing(3)
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
        loginItemManager: LoginItemManager.shared,
        windowManager: nil // Preview doesn't need actual WindowManager
    ))
}
