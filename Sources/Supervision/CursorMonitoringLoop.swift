import Combine
import Defaults
import Diagnostics
import Foundation

/// Manages the monitoring loop and cycle logic for CursorMonitor
@MainActor
extension CursorMonitor {
    /// Starts the monitoring loop
    public func startMonitoringLoop() {
        guard !isMonitoringActive else {
            logger.info("Monitoring loop already active, ignoring start request.")
            return
        }

        logger.info("Starting monitoring loop...")
        sessionLogger.log(level: .info, message: "Starting monitoring loop...")
        isMonitoringActive = true

        monitoringTask = Task { @MainActor in
            logger.info("Monitoring task started successfully.")

            while self.isMonitoringActive, !Task.isCancelled {
                // Check global monitoring setting on each cycle
                let isGlobalEnabled = Defaults[.isGlobalMonitoringEnabled]

                if isGlobalEnabled {
                    await self.performMonitoringCycle()
                } else {
                    // When global monitoring is disabled, sleep longer to reduce overhead
                    logger.debug("Global monitoring disabled, skipping monitoring cycle")
                    try? await Task.sleep(for: .seconds(10))
                }

                // Sleep between monitoring cycles
                try? await Task.sleep(for: .seconds(5))
            }

            // Cleanup when monitoring stops
            logger.info("Monitoring task ended.")
            sessionLogger.log(level: .info, message: "Monitoring task ended.")
        }
    }

    /// Stops the monitoring loop
    public func stopMonitoringLoop() {
        guard isMonitoringActive else {
            logger.info("Monitoring loop not active, ignoring stop request.")
            return
        }

        logger.info("Stopping monitoring loop...")
        sessionLogger.log(level: .info, message: "Stopping monitoring loop...")
        isMonitoringActive = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    /// Performs a single monitoring cycle
    func performMonitoringCycle() async {
        guard !monitoredApps.isEmpty else {
            logger.info("No monitored apps, skipping monitoring cycle.")
            return
        }

        // Only log every 10th cycle to reduce verbosity
        if monitoringCycleCount % 10 == 0 {
            logger.debug("Monitoring cycle #\(monitoringCycleCount): \(monitoredApps.count) app(s)")
        }
        monitoringCycleCount += 1

        // First, update window information for all monitored apps
        await processMonitoredApps()

        // Process each monitored app for interventions
        for appInfo in monitoredApps {
            if monitoringCycleCount % 10 == 0 {
                logger.debug(
                    "Processing app: \(appInfo.displayName) (PID: \(appInfo.pid)) with \(appInfo.windows.count) windows."
                )
            }

            // Log window information periodically
            if monitoringCycleCount % 10 == 0 {
                for windowInfo in appInfo.windows {
                    logger.debug("  Window: \(windowInfo.windowTitle ?? "N/A")")
                }
            }
        }

        // Update total intervention count for display
        totalAutomaticInterventionsThisSessionDisplay = instanceStateManager
            .getTotalAutomaticInterventionsThisSession()
    }

    /// Sets up subscription for monitoring loop management
    func setupMonitoringLoopSubscription() {
        // Subscribe to own monitoredApps to manage the monitoring loop
        $monitoredApps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self else { return }
                self.handleMonitoredAppsChange(apps)
            }
            .store(in: &cancellables)
    }

    /// Handles changes to the monitored apps list
    func handleMonitoredAppsChange(_ apps: [MonitoredAppInfo]) {
        if !apps.isEmpty, !self.isMonitoringActive {
            self.logger.info("Monitored apps list became non-empty. Starting monitoring loop.")
            self.startMonitoringLoop()
        } else if apps.isEmpty, self.isMonitoringActive {
            self.logger.info("Monitored apps list became empty. Stopping monitoring loop.")
            self.stopMonitoringLoop()
        }
    }
}
