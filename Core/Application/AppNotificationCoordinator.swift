import AppKit
import Diagnostics
import Foundation
import Defaults

/// Coordinates application-wide notification observers and system events.
///
/// This coordinator manages notification subscriptions, system sleep/wake events,
/// and preference changes to reduce complexity in AppDelegate.
@MainActor
final class AppNotificationCoordinator {
    // MARK: - Initialization
    
    init() {
        logger.info("AppNotificationCoordinator initialized")
    }
    
    deinit {
        // Cleanup handled externally to avoid capture issues
    }
    
    // MARK: - Public API
    
    /// Setup all notification observers and system event monitoring
    func setupNotifications() {
        logger.info("🔔 Setting up notification observers...")
        
        setupMenuBarHighlightObserver()
        setupAXpectorWindowObserver()
        setupSystemSleepWakeObservers()
        setupPreferenceObservers()
        setupExceptionHandling()
        
        logger.info("✅ Notification observers configured")
    }
    
    /// Clean up all notification observers
    func cleanup() {
        logger.info("🧹 Cleaning up notification observers...")
        
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        
        // Remove workspace observers
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        
        logger.info("✅ Notification cleanup complete")
    }
    
    // MARK: - Action Handlers
    
    /// Set the window manager for handling window-related notifications
    func setWindowManager(_ windowManager: WindowManager?) {
        self.windowManager = windowManager
    }
    
    // MARK: - Private Implementation
    
    private let logger = Logger(category: .appDelegate)
    private var notificationObservers: [NSObjectProtocol] = []
    private weak var windowManager: WindowManager?
    
    /// Setup menu bar highlight notification observer
    private func setupMenuBarHighlightObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: .highlightMenuBarIcon,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.handleMenuBarHighlight(notification)
            }
        }
        notificationObservers.append(observer)
    }
    
    /// Setup AXpector window notification observer
    private func setupAXpectorWindowObserver() {
        let observer = NotificationCenter.default.addObserver(
            forName: .showAXpectorWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleShowAXpectorWindow()
            }
        }
        notificationObservers.append(observer)
    }
    
    /// Setup system sleep and wake observers
    private func setupSystemSleepWakeObservers() {
        let sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemWillSleep()
            }
        }
        notificationObservers.append(sleepObserver)
        
        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSystemDidWake()
            }
        }
        notificationObservers.append(wakeObserver)
    }
    
    /// Setup preference change observers
    private func setupPreferenceObservers() {
        // Global monitoring preference observer
        Defaults.observe(.isGlobalMonitoringEnabled) { [weak self] change in
            Task { @MainActor in
                self?.handleMonitoringPreferenceChange(enabled: change.newValue)
            }
        }
        .tieToLifetime(of: self)
        
        // Dock visibility preference observer
        Defaults.observe(.showInDock) { [weak self] change in
            Task { @MainActor in
                self?.handleDockVisibilityChange(visible: change.newValue)
            }
        }
        .tieToLifetime(of: self)
    }
    
    /// Setup global exception handling
    private func setupExceptionHandling() {
        logger.info("🛡️ Setting up exception handling...")
        
        NSSetUncaughtExceptionHandler { exception in
            let exceptionLogger = Logger(category: .general)
            exceptionLogger.critical("Uncaught exception: \(exception.name.rawValue)")
            exceptionLogger.critical("Reason: \(exception.reason ?? "unknown")")
            exceptionLogger.critical("Stack trace: \(exception.callStackSymbols.joined(separator: "\n"))")
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleMenuBarHighlight(_ notification: Notification) {
        guard let duration = notification.userInfo?["duration"] as? TimeInterval else {
            logger.warning("Menu bar highlight notification missing duration")
            return
        }
        
        logger.info("📍 Menu bar highlight requested for \(duration) seconds")
        // TODO: Implement menu bar highlighting animation
    }
    
    private func handleShowAXpectorWindow() {
        logger.info("🔍 Request to show AXpector window")
        windowManager?.showAXpectorWindow()
    }
    
    private func handleSystemWillSleep() {
        logger.info("💤 System going to sleep - pausing monitoring")
        // Pause all monitored apps
        for app in CursorMonitor.shared.monitoredApps {
            CursorMonitor.shared.pauseMonitoring(for: app.pid)
        }
    }
    
    private func handleSystemDidWake() {
        logger.info("⏰ System waking up - resuming monitoring")
        
        Task { @MainActor in
            // Give system time to stabilize after wake
            try? await Task.sleep(for: .seconds(2))
            // Resume all monitored apps
            for app in CursorMonitor.shared.monitoredApps {
                CursorMonitor.shared.resumeMonitoring(for: app.pid)
            }
        }
    }
    
    private func handleMonitoringPreferenceChange(enabled: Bool) {
        logger.info("🔄 Global monitoring preference changed to: \(enabled)")
        
        if enabled {
            logger.info("📡 Enabling monitoring - will start when Cursor instances are detected")
            WindowAIDiagnosticsManager.shared.enableLiveWatchingForAllWindows()
        } else {
            logger.info("🛑 Disabling monitoring and stopping all services")
            CursorMonitor.shared.stopMonitoringLoop()
            WindowAIDiagnosticsManager.shared.disableLiveWatchingForAllWindows()
        }
    }
    
    private func handleDockVisibilityChange(visible: Bool) {
        logger.info("🎯 Dock visibility changed to: \(visible)")
        
        if visible {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

