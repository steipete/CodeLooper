import DesignSystem
import SwiftUI
import Defaults
import Lottie
import Diagnostics

struct DebugSettingsView: View {
    @Default(.useDynamicMenuBarIcon) private var useDynamicMenuBarIcon
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xLarge) {
            // Menu Bar Icon Settings
            DSSettingsSection("Menu Bar Icon") {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    DSToggle(
                        "Use Dynamic Lottie Icon",
                        isOn: $useDynamicMenuBarIcon,
                        description: "Use animated Lottie icon instead of static PNG image in menu bar"
                    )
                    
                    HStack {
                        Text("Current icon type:")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                        
                        Spacer()
                        
                        Text(useDynamicMenuBarIcon ? "Dynamic (Lottie)" : "Static (PNG)")
                            .font(Typography.caption1(.medium))
                            .foregroundColor(useDynamicMenuBarIcon ? ColorPalette.success : ColorPalette.primary)
                    }
                }
            }
            
            // Lottie Animation Test Section
            DSSettingsSection("Lottie Animation Test") {
                LottieTestView()
            }
            
            // Debug Information
            DSSettingsSection("Build Information") {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Text("Build Configuration:")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                        Spacer()
                        Text("Debug")
                            .font(Typography.body())
                            .foregroundColor(ColorPalette.success)
                    }
                    
                    HStack {
                        Text("Bundle Identifier:")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                        Spacer()
                        Text(Bundle.main.bundleIdentifier ?? "Unknown")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    HStack {
                        Text("Version:")
                            .font(Typography.body(.medium))
                            .foregroundColor(ColorPalette.text)
                        Spacer()
                        Text("\(appVersion) (\(buildNumber))")
                            .font(Typography.caption1())
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                }
            }
            
            // Debug Actions
            DSSettingsSection("Debug Actions") {
                VStack(spacing: Spacing.medium) {
                    DSButton("Clear All UserDefaults", style: .destructive) {
                        clearUserDefaults()
                    }
                    .frame(maxWidth: .infinity)
                    
                    DSButton("Trigger Test Notification", style: .secondary) {
                        triggerTestNotification()
                    }
                    .frame(maxWidth: .infinity)
                    
                    DSButton("Print Window Hierarchy", style: .secondary) {
                        printWindowHierarchy()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.background)
        .withDesignSystem()
    }
    
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }
    
    private func clearUserDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        print("DEBUG: Cleared all UserDefaults for domain: \(domain)")
    }
    
    private func triggerTestNotification() {
        NotificationCenter.default.post(name: .init("DebugTestNotification"), object: nil)
        print("DEBUG: Triggered test notification")
    }
    
    private func printWindowHierarchy() {
        print("DEBUG: Current window hierarchy:")
        for (index, window) in NSApp.windows.enumerated() {
            print("  \(index): \(window.title) - \(window.className) - Visible: \(window.isVisible)")
        }
    }
}

// MARK: - Lottie Test View (moved from AboutSettingsView)

private struct LottieTestView: View {
    @Default(.isGlobalMonitoringEnabled) private var isWatchingEnabled
    @State private var testSize: CGFloat = 32
    @State private var localAnimationEnabled = true
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text("Menu Bar Icon Test")
                .font(Typography.body(.medium))
                .foregroundColor(ColorPalette.text)
            
            // Animation analysis
            VStack(spacing: Spacing.small) {
                Text("Animation Analysis:")
                    .font(Typography.caption1(.medium))
                    .foregroundColor(ColorPalette.text)
                
                if let animation = LottieAnimation.named("chain_link_lottie") {
                    let duration = animation.duration
                    let frameRate = animation.framerate
                    let totalFrames = Int(duration * frameRate)
                    
                    Text("Duration: \(String(format: "%.2f", duration))s, FPS: \(frameRate), Frames: \(totalFrames)")
                        .font(Typography.caption2())
                        .foregroundColor(ColorPalette.textSecondary)
                } else {
                    Text("Failed to load animation")
                        .font(Typography.caption2())
                        .foregroundColor(.red)
                }
            }
            
            // Animation test views
            HStack(spacing: Spacing.large) {
                VStack(spacing: Spacing.small) {
                    Text("Menu Bar Size (16x16)")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    LottieMenuBarView()
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.red, width: 1) // Debug border
                }
                
                VStack(spacing: Spacing.small) {
                    Text("Test Size (\(Int(testSize))x\(Int(testSize)))")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    LottieTestAnimationView(isEnabled: localAnimationEnabled)
                        .frame(width: testSize, height: testSize)
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.blue, width: 1) // Debug border
                }
                
                VStack(spacing: Spacing.small) {
                    Text("Rotating Icon Test")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Image(systemName: "link")
                        .renderingMode(.template)
                        .foregroundColor(Color.primary)
                        .font(.system(size: testSize / 2))
                        .frame(width: testSize, height: testSize)
                        .rotationEffect(.degrees(localAnimationEnabled ? rotationAngle : 0))
                        .animation(localAnimationEnabled ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: localAnimationEnabled)
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.green, width: 1)
                        .onAppear {
                            if localAnimationEnabled {
                                rotationAngle = 360
                            }
                        }
                        .onChange(of: localAnimationEnabled) { oldValue, newValue in
                            if newValue {
                                rotationAngle = 360
                            } else {
                                rotationAngle = 0
                            }
                        }
                }
                
                VStack(spacing: Spacing.small) {
                    Text("Your Custom Icon")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    CustomChainLinkIcon(size: testSize)
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.purple, width: 1)
                }
                
                VStack(spacing: Spacing.small) {
                    Text("Simplified Test")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    SimplifiedChainLinkIcon(size: testSize)
                        .background(ColorPalette.backgroundSecondary)
                        .border(Color.orange, width: 1)
                }
            }
            
            DSDivider()
            
            // Controls section
            VStack(spacing: Spacing.medium) {
                // Animation toggle buttons
                HStack(spacing: Spacing.medium) {
                    Text("Local Animation:")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Button("Enable") {
                        localAnimationEnabled = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(localAnimationEnabled)
                    
                    Button("Disable") {
                        localAnimationEnabled = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(!localAnimationEnabled)
                }
                
                // Global monitoring toggle
                HStack(spacing: Spacing.medium) {
                    Text("Global Monitoring:")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Button("Enable") {
                        Defaults[.isGlobalMonitoringEnabled] = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWatchingEnabled)
                    
                    Button("Disable") {
                        Defaults[.isGlobalMonitoringEnabled] = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isWatchingEnabled)
                }
                
                // Size controls
                HStack(spacing: Spacing.medium) {
                    Text("Test Size:")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Button("16") { testSize = 16 }
                        .buttonStyle(.bordered)
                    
                    Button("24") { testSize = 24 }
                        .buttonStyle(.bordered)
                    
                    Button("32") { testSize = 32 }
                        .buttonStyle(.bordered)
                    
                    Button("64") { testSize = 64 }
                        .buttonStyle(.bordered)
                    
                    Button("128") { testSize = 128 }
                        .buttonStyle(.bordered)
                }
                
                // Size slider
                HStack(spacing: Spacing.medium) {
                    Text("Custom:")
                        .font(Typography.caption1())
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Slider(value: $testSize, in: 16...128, step: 1) {
                        Text("Size")
                    } minimumValueLabel: {
                        Text("16")
                            .font(Typography.caption2())
                    } maximumValueLabel: {
                        Text("128")
                            .font(Typography.caption2())
                    }
                    .frame(width: 200)
                    
                    Text("\(Int(testSize))")
                        .font(Typography.caption1(.medium))
                        .frame(width: 30)
                }
            }
            
            DSDivider()
            
            // Status section
            VStack(spacing: Spacing.small) {
                Text("Current State:")
                    .font(Typography.caption1())
                    .foregroundColor(ColorPalette.textSecondary)
                
                HStack(spacing: Spacing.medium) {
                    Text("Global Watching: \(isWatchingEnabled ? "Enabled" : "Disabled")")
                        .font(Typography.caption1(.medium))
                        .foregroundColor(isWatchingEnabled ? .green : .red)
                    
                    Text("Local Animation: \(localAnimationEnabled ? "Enabled" : "Disabled")")
                        .font(Typography.caption1(.medium))
                        .foregroundColor(localAnimationEnabled ? .green : .red)
                }
            }
        }
        .padding(Spacing.medium)
    }
}

// MARK: - Lottie Test Animation View

private struct LottieTestAnimationView: View {
    let isEnabled: Bool
    private let logger = Logger(category: .statusBar)
    
    var body: some View {
        Group {
            if let animation = loadAnimation() {
                LottieView(animation: animation)
                    .playing(loopMode: isEnabled ? .loop : .playOnce)
                    .animationSpeed(0.3)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorMultiply(Color.primary)
                    .clipped()
                    .onAppear {
                        logger.info("Test Lottie animation view appeared, enabled: \(isEnabled)")
                    }
            } else {
                Image(systemName: "link")
                    .renderingMode(.template)
                    .foregroundColor(Color.primary)
                    .onAppear {
                        logger.error("Test animation failed to load, using fallback")
                    }
            }
        }
    }
    
    private func loadAnimation() -> LottieAnimation? {
        return LottieAnimation.named("chain_link_lottie") ?? 
               LottieAnimation.filepath(Bundle.main.path(forResource: "chain_link_lottie", ofType: "json") ?? "")
    }
}

// MARK: - Custom Chain Link Icon

private struct CustomChainLinkIcon: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Custom chain link path
            ChainLinkShape()
                .stroke(Color.primary, style: StrokeStyle(lineWidth: max(2, size / 16), lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.6, height: size * 0.6)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Chain Link Shape

private struct ChainLinkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let linkWidth = width * 0.3
        let linkHeight = height * 0.15
        
        // First link (left)
        let link1Center = CGPoint(x: width * 0.3, y: height * 0.5)
        path.addEllipse(in: CGRect(
            x: link1Center.x - linkWidth/2,
            y: link1Center.y - linkHeight/2,
            width: linkWidth,
            height: linkHeight
        ))
        
        // Second link (right, rotated)
        let link2Center = CGPoint(x: width * 0.7, y: height * 0.5)
        let link2Rect = CGRect(
            x: link2Center.x - linkHeight/2,
            y: link2Center.y - linkWidth/2,
            width: linkHeight,
            height: linkWidth
        )
        path.addEllipse(in: link2Rect)
        
        return path
    }
}

// MARK: - Simplified Chain Link Icon

private struct SimplifiedChainLinkIcon: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // First oval link
            Ellipse()
                .stroke(Color.primary, lineWidth: max(2, size / 12))
                .frame(width: size * 0.4, height: size * 0.2)
                .offset(x: -size * 0.15, y: 0)
            
            // Second oval link (rotated and offset)
            Ellipse()
                .stroke(Color.primary, lineWidth: max(2, size / 12))
                .frame(width: size * 0.2, height: size * 0.4)
                .offset(x: size * 0.15, y: 0)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

struct DebugSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DebugSettingsView()
            .frame(width: 600, height: 800)
            .padding()
            .background(ColorPalette.background)
            .withDesignSystem()
    }
}