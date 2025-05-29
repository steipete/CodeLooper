import AppKit
import Diagnostics
import Foundation
import Defaults

/// Coordinates supervision and monitoring functionality for Cursor IDE instances.
///
/// This coordinator manages the setup and lifecycle of monitoring services,
/// intervention systems, and AI analysis to reduce complexity in AppDelegate.
@MainActor
final class AppSupervisionCoordinator {
    // MARK: - Initialization
    
    init() {
        logger.info("AppSupervisionCoordinator initialized")
    }
    
    // MARK: - Public API
    
    /// Initialize supervision services and monitoring
    func setupSupervision() {
        logger.info("🔍 Setting up supervision services...")
        
        setupMonitoringPreferences()
        setupInitialSupervisionState()
        
        logger.info("✅ Supervision services configured")
    }
    
    /// Start supervision if enabled
    func startSupervisionIfEnabled() {
        guard Defaults[.isGlobalMonitoringEnabled] else {
            logger.info("🚫 Global monitoring disabled at startup")
            return
        }
        
        logger.info("🚀 Global monitoring enabled - starting supervision")
        
        Task { @MainActor in
            // Give the monitoring system time to detect existing windows
            try? await Task.sleep(for: .seconds(1))
            WindowAIDiagnosticsManager.shared.enableLiveWatchingForAllWindows()
            logger.info("✅ Enabled AI live watching for existing windows at startup")
        }
    }
    
    /// Toggle monitoring state programmatically
    func toggleMonitoringState() {
        let currentState = Defaults[.isGlobalMonitoringEnabled]
        Defaults[.isGlobalMonitoringEnabled] = !currentState
        
        let newState = !currentState ? "enabled" : "disabled"
        logger.info("🔄 Global monitoring toggled: \(newState)")
    }
    
    /// Stop all supervision activities
    func stopSupervision() {
        logger.info("🛑 Stopping supervision services...")
        
        CursorMonitor.shared.stopMonitoringLoop()
        WindowAIDiagnosticsManager.shared.disableLiveWatchingForAllWindows()
        
        // Stop JavaScript hooks
        JSHookCoordinator.shared.stopAllHooks()
        
        logger.info("✅ Supervision stopped")
    }
    
    // MARK: - Development Support
    
    #if DEBUG
    /// Start accessibility observation for development/debugging
    func startDevelopmentObservation() {
        logger.info("🔧 Starting development AX observation...")
        
        // This would contain the AX observation setup that was in AppDelegate
        // for debugging purposes in development builds
    }
    #endif
    
    // MARK: - Private Implementation
    
    private let logger = Logger(category: .supervision)
    
    /// Setup monitoring preference observers
    private func setupMonitoringPreferences() {
        logger.info("⚙️ Setting up monitoring preferences...")
        
        // This observer is set up separately in AppNotificationCoordinator
        // to avoid duplication, but we document the behavior here
        logger.info("✅ Monitoring preferences configured")
    }
    
    /// Configure initial supervision state based on user preferences
    private func setupInitialSupervisionState() {
        let isEnabled = Defaults[.isGlobalMonitoringEnabled]
        logger.info("🎯 Initial supervision state: \(isEnabled ? "enabled" : "disabled")")
        
        if isEnabled {
            logger.info("📡 Supervision enabled - monitoring will start when Cursor instances are detected")
        } else {
            logger.info("⏸️ Supervision disabled - no monitoring will occur")
        }
    }
}

// MARK: - Supporting Types

/// Supervision state management
enum SupervisionState {
    case disabled
    case enabled
    case monitoring
    case paused
    
    var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .enabled: return "Enabled"
        case .monitoring: return "Monitoring"
        case .paused: return "Paused"
        }
    }
}