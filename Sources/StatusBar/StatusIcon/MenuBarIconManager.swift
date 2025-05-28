import AppKit
import Combine
import Defaults
import Diagnostics
import Foundation
import OSLog
import SwiftUI

@_exported import class Foundation.Timer

// Import required Foundation types
@_exported import struct Foundation.URL

// StatusIconState and IconAnimator are already part of the same module
// No need to import them explicitly

/// MenuBarIconManager provides status icon handling for the menu bar status item,
/// with full support for different states, dark/light mode, and animations.
@MainActor
class MenuBarIconManager: ObservableObject {
    // MARK: - Shared Instance
    static let shared = MenuBarIconManager()

    // MARK: - Published Properties
    @Published var currentIconAttributedString = AttributedString("...")
    @Published var currentTooltip: String = CodeLooper.Constants.appName

    // MARK: - Initialization

    init(statusItem: NSStatusItem? = nil) {
        self.statusItem = statusItem
        logger.info("MenuBarIconManager initialized.")
        
        // If a statusItem is provided, configure animator (might be useful for other things)
        if let statusItem = statusItem {
            iconAnimator = IconAnimator(statusItem: statusItem)
        }

        setupAppearanceObserver()
        setupDiagnosticsObserver()

        // Set initial state
        DispatchQueue.main.async {
            self.setState(.idle)
        }
    }

    deinit {
        MainActor.assumeIsolated {
            removeAppearanceObserver()
            iconAnimator?.cleanup()
            cancellables.forEach { $0.cancel() }
        }
    }

    // MARK: Internal

    weak var statusItem: NSStatusItem?

    // MARK: - Public Methods

    /// Sets the menu bar icon state
    /// - Parameter state: The new state for the icon
    func setState(_ state: StatusIconState) {
        currentState = state
        currentTooltip = state.tooltipText
        updateIconAttributedString(for: state)
        
        // Animation logic can be re-evaluated if needed for SwiftUI
        iconAnimator?.stopAnimating()
        if state == .syncing {
            // startSyncingAnimation() // This manipulated NSImage, needs rework for SwiftUI if desired
        }
    }

    // Legacy methods for compatibility
    func setActiveIcon() { setState(.authenticated) }
    func setInactiveIcon() { setState(.unauthenticated) }
    func setUploadingIcon() { setState(.syncing) }
    func setNormalIcon() { setState(.idle) }

    /// Stops any ongoing animations and cleans up resources
    func cleanup() {
        iconAnimator?.cleanup()
        cancellables.forEach { $0.cancel() }
    }

    // MARK: Private

    private let logger = Logger(category: .statusBar)
    private var appearanceObserver: Any?
    private var diagnosticsManager = WindowAIDiagnosticsManager.shared
    private var cancellables = Set<AnyCancellable>()

    // Current state of the icon
    private var currentState: StatusIconState = .idle

    // Animator for icon animations
    private var iconAnimator: IconAnimator?

    // MARK: - Private Methods

    private func setupDiagnosticsObserver() {
        diagnosticsManager.$windowStates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] windowStates in
                guard let self = self else { return }

                if !Defaults[.isGlobalMonitoringEnabled] {
                    self.setState(.paused)
                    return
                }

                var workingCount = 0
                var notWorkingCount = 0
                var unknownCount = 0
                var activeAICount = 0

                for (_, windowInfo) in windowStates where windowInfo.isLiveWatchingEnabled {
                    activeAICount += 1
                    switch windowInfo.lastAIAnalysisStatus {
                    case .working:
                        workingCount += 1
                    case .notWorking:
                        notWorkingCount += 1
                    case .unknown:
                        unknownCount += 1
                    case .pending, .error, .off:
                        // Potentially count pending/error as unknown for icon simplicity
                        // or handle them distinctly if the icon design allows.
                        // For now, let's treat pending as unknown for the icon.
                        if windowInfo.lastAIAnalysisStatus == .pending {
                            unknownCount += 1
                        }
                        // .error and .off don't contribute to active counts for icon display
                    }
                }

                if activeAICount == 0 && Defaults[.isGlobalMonitoringEnabled] {
                    self.setState(.idle) // No windows actively AI-watched, but monitoring is on
                } else if workingCount > 0 || notWorkingCount > 0 || unknownCount > 0 {
                    self.setState(.aiStatus(working: workingCount, notWorking: notWorkingCount, unknown: unknownCount))
                } else if Defaults[.isGlobalMonitoringEnabled] {
                    // AI watching enabled, but no specific statuses yet (e.g. all off or error)
                     self.setState(.idle) // Or a more specific "no AI targets" state
                } else {
                    self.setState(.paused) // Fallback if global monitoring is off
                }
            }
            .store(in: &cancellables)
    }

    private func updateIconAttributedString(for state: StatusIconState) {
        let currentAppearance = getCurrentAppearance()
        var newAttributedString: AttributedString

        switch state {
        case let .aiStatus(working, notWorking, unknown):
            if working == 0 && notWorking == 0 && unknown == 0 && !Defaults[.isGlobalMonitoringEnabled] {
                 newAttributedString = attributedString(for: .paused, appearance: currentAppearance)
            } else if working == 0 && notWorking == 0 && unknown == 0 && Defaults[.isGlobalMonitoringEnabled] {
                 newAttributedString = attributedString(for: .idle, appearance: currentAppearance)
            } else {
                newAttributedString = createAIStatusAttributedString(working: working, notWorking: notWorking, unknown: unknown)
            }
        default:
            newAttributedString = attributedString(for: state, appearance: currentAppearance)
        }
        
        self.currentIconAttributedString = newAttributedString
        statusItem?.button?.toolTip = state.tooltipText
    }

    private func attributedString(for state: StatusIconState, appearance: NSAppearance.Name) -> AttributedString {
        var attributes = AttributeContainer()
        attributes.font = Font.system(size: 12)
        attributes.foregroundColor = appearance == .darkAqua ? .white : .black

        var iconString: String
        switch state {
        case .idle, .paused: // If idle or paused, return an empty AttributedString
            return AttributedString()
        case .error: iconString = "⚠️"
        case .syncing: iconString = "🔄"
        // Add other cases as needed
        default: iconString = "●" // Default for other unhandled states, can also be empty or specific
        }
        return AttributedString(iconString, attributes: attributes)
    }
    
    // swiftlint:disable empty_count
    private func createAIStatusAttributedString(working: Int, notWorking: Int, unknown: Int) -> AttributedString {
        var result = AttributedString()
        var hasContent = false

        func appendStatus(emoji: String, count: Int, color: Color) {
            guard count > 0 else { return }
            if hasContent {
                result.append(AttributedString(" "))
            }
            let part = AttributedString("\(emoji)\(count)")
            result.append(part)
            hasContent = true
        }

        // Define colors based on current appearance (though direct Text view modifiers are better)
        let workingColor: Color = .green
        let notWorkingColor: Color = .red
        let unknownColor: Color = .yellow
        
        if working > 0 {
            appendStatus(emoji: "🟢", count: working, color: workingColor)
        }
        if notWorking > 0 {
            appendStatus(emoji: "🔴", count: notWorking, color: notWorkingColor)
        }
        if unknown > 0 && !hasContent {
            appendStatus(emoji: "🟡", count: unknown, color: unknownColor)
        } else if unknown > 0 && Defaults[.debugModeEnabled] {
             appendStatus(emoji: "🟡", count: unknown, color: unknownColor)
        }
        
        if !hasContent {
            return AttributedString()
        }
        
        return result
    }
    // swiftlint:enable empty_count

    /// Sets up an observer to detect appearance changes (dark/light mode)
    private func setupAppearanceObserver() {
        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: OperationQueue.main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.info("System appearance changed. Re-evaluating icon.")
                self.updateIconAttributedString(for: self.currentState)
            }
        }
    }

    /// Removes the appearance observer
    private func removeAppearanceObserver() {
        if let observer = appearanceObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            appearanceObserver = nil
        }
    }

    /// Get the current effective appearance
    private func getCurrentAppearance() -> NSAppearance.Name {
        statusItem?.button?.effectiveAppearance.name ?? NSApp.effectiveAppearance.name
    }
}
