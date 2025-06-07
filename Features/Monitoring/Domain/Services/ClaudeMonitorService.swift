import Foundation
import Diagnostics
import Defaults

private let logger = Logger(category: .supervision)

@MainActor
public final class ClaudeMonitorService: ObservableObject, Sendable, Loggable {
    
    // MARK: - Singleton
    
    public static let shared = ClaudeMonitorService()
    
    // MARK: - Published Properties
    
    @Published public private(set) var instances: [ClaudeInstance] = []
    @Published public private(set) var state: ClaudeMonitoringState = .idle
    @Published public private(set) var isMonitoring = false
    
    // MARK: - Services
    
    private let processDetector = ClaudeProcessDetector()
    private let statusExtractor = ClaudeStatusExtractor()
    private let titleManager = ClaudeTerminalTitleManager()
    
    // MARK: - Configuration
    
    private struct Configuration {
        static let monitoringInterval: TimeInterval = 5.0
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 1.0
    }
    
    // MARK: - Private State
    
    private var monitoringTask: Task<Void, Never>?
    private var titleOverrideEnabled = false
    private var retryCount = 0
    
    // MARK: - Initialization
    
    private init() {
        logger.info("ClaudeMonitorService initialized")
    }
    
    // MARK: - Public API
    
    /// Synchronize monitoring state with user preferences
    public func syncWithUserDefaults() {
        let shouldMonitor = Defaults[.enableClaudeMonitoring]
        let shouldOverrideTitles = Defaults[.enableClaudeTitleOverride]
        
        logger.info("🔄 Syncing Claude monitoring state:")
        logger.info("   shouldMonitor: \(shouldMonitor)")
        logger.info("   isCurrentlyMonitoring: \(isMonitoring)")
        logger.info("   shouldOverrideTitles: \(shouldOverrideTitles)")
        
        if shouldMonitor && !isMonitoring {
            logger.info("✅ Starting Claude monitoring to match user preferences")
            startMonitoring(enableTitleOverride: shouldOverrideTitles)
        } else if !shouldMonitor && isMonitoring {
            logger.info("⏹️ Stopping Claude monitoring to match user preferences")
            stopMonitoring()
        } else if shouldMonitor, isMonitoring {
            // Already monitoring, but check if title override setting changed
            if titleOverrideEnabled != shouldOverrideTitles {
                logger.info("🔄 Updating title override setting")
                titleOverrideEnabled = shouldOverrideTitles
            }
            logger.info("✅ Claude monitoring already active")
        } else {
            logger.info("ℹ️ Claude monitoring disabled in user preferences")
        }
    }
    
    /// Start monitoring Claude instances
    public func startMonitoring(enableTitleOverride: Bool = true) {
        guard !isMonitoring else { 
            logger.debug("Monitoring already active")
            return 
        }
        
        logger.info("🚀 Starting Claude monitoring (titleOverride: \(enableTitleOverride))")
        isMonitoring = true
        titleOverrideEnabled = enableTitleOverride
        retryCount = 0
        
        // Start the monitoring loop
        monitoringTask = Task { [weak self] in
            self?.logger.info("🔄 Claude monitoring task created and starting...")
            await self?.runMonitoringLoop()
        }
    }
    
    /// Stop monitoring Claude instances
    public func stopMonitoring() {
        logger.info("Stopping Claude monitoring")
        
        isMonitoring = false
        state = .idle
        retryCount = 0
        
        monitoringTask?.cancel()
        monitoringTask = nil
        
        instances.removeAll()
    }
    
    // MARK: - Private Implementation
    
    /// Main monitoring loop
    private func runMonitoringLoop() async {
        logger.info("Starting Claude monitoring loop")
        state = .monitoring(instanceCount: 0)
        
        while !Task.isCancelled && isMonitoring {
            do {
                await performMonitoringCycle()
                retryCount = 0  // Reset retry count on success
                
                // Wait for next cycle
                try await Task.sleep(for: .seconds(Configuration.monitoringInterval))
            } catch {
                await handleMonitoringError(error)
            }
        }
        
        logger.info("Claude monitoring loop ended")
    }
    
    /// Perform a single monitoring cycle
    private func performMonitoringCycle() async {
        logger.debug("Starting monitoring cycle")
        
        // Step 1: Detect running Claude processes
        let detectedInstances = await processDetector.detectClaudeInstances()
        logger.debug("Process detector found \(detectedInstances.count) instances")
        
        // Step 2: Extract current activity status for each instance
        var updatedInstances: [ClaudeInstance] = []
        
        for instance in detectedInstances {
            let currentActivity = await statusExtractor.extractStatus(for: instance)
            
            let updatedInstance = ClaudeInstance(
                id: instance.id,
                pid: instance.pid,
                ttyPath: instance.ttyPath,
                workingDirectory: instance.workingDirectory,
                folderName: instance.folderName,
                status: instance.status,
                currentActivity: currentActivity,
                lastUpdated: Date()
            )
            
            updatedInstances.append(updatedInstance)
        }
        
        // Step 3: Update state
        instances = updatedInstances
        state = .monitoring(instanceCount: updatedInstances.count)
        
        logger.debug("Monitoring cycle complete: \(updatedInstances.count) instances detected")
        
        // Step 4: Update terminal titles if enabled
        if titleOverrideEnabled && !updatedInstances.isEmpty {
            await titleManager.updateTitles(for: updatedInstances)
        }
    }
    
    /// Handle monitoring errors with retry logic
    private func handleMonitoringError(_ error: Error) async {
        retryCount += 1
        
        logger.warning("Monitoring cycle failed (attempt \(retryCount)/\(Configuration.maxRetries)): \(error)")
        
        if retryCount >= Configuration.maxRetries {
            logger.error("Max retries reached, stopping monitoring")
            state = .error(error.localizedDescription, retryCount: retryCount)
            stopMonitoring()
            return
        }
        
        state = .error(error.localizedDescription, retryCount: retryCount)
        
        // Wait before retrying
        do {
            try await Task.sleep(for: .seconds(Configuration.retryDelay))
        } catch {
            // Task was cancelled during retry delay
            return
        }
    }
}