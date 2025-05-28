import Diagnostics
import Foundation

/// Manages JavaScript hook connections and port assignments for monitored windows
@MainActor
class JSHookManager {
    // MARK: Internal

    // MARK: - Public Properties

    var jsHooks: [String: CursorJSHook] = [:]
    private(set) var hookedWindows: Set<String> = []
    var windowPorts: [String: UInt16] = [:]
    var nextPort: UInt16 = 9001

    // MARK: - Public Methods

    func getOrAssignPort(for windowId: String) -> UInt16 {
        if let existingPort = windowPorts[windowId] {
            logger.debug("🔄 Reusing existing port \(existingPort) for window \(windowId)")
            return existingPort
        }

        let assignedPort = nextPort
        windowPorts[windowId] = assignedPort
        nextPort += 1
        
        logger.info("🆕 Assigned new port \(assignedPort) to window \(windowId)")
        logger.debug("🔢 Next available port will be: \(nextPort)")

        return assignedPort
    }

    func hasHookForWindow(_ windowId: String) -> Bool {
        hookedWindows.contains(windowId)
    }

    func installHook(for window: MonitoredWindowInfo) async throws {
        guard !hasHookForWindow(window.id) else {
            logger.debug("🔄 Hook already exists for window \(window.id) - skipping installation")
            return
        }

        let port = getOrAssignPort(for: window.id)
        let windowTitle = window.windowTitle ?? "Unknown"
        
        logger.info("🔨 Installing CodeLooper JS hook")
        logger.info("🧾 Window: \(windowTitle)")
        logger.info("🆔 Window ID: \(window.id)")
        logger.info("🔌 Port: \(port)")

        do {
            logger.info("🚀 Creating CursorJSHook instance...")
            let hook = try await CursorJSHook(
                applicationName: "Cursor",
                port: port,
                targetWindowTitle: window.windowTitle
            )

            jsHooks[window.id] = hook
            hookedWindows.insert(window.id)
            
            logger.info("💾 Saving port mappings...")
            savePortMappings()

            logger.info("✅ JS Hook installed successfully!")
            logger.info("🎉 Window '\(windowTitle)' is now hooked on port \(port)")
            logger.info("📋 Total hooked windows: \(hookedWindows.count)")
        } catch {
            logger.error("❌ Failed to install JS hook: \(error)")
            logger.error("🔍 Error details: \(error.localizedDescription)")
            throw error
        }
    }

    func probeForExistingHooks(windows: [MonitoredWindowInfo]) async {
        await withTaskGroup(of: Void.self) { group in
            for window in windows {
                guard !hasHookForWindow(window.id) else { continue }

                group.addTask { [weak self] in
                    await self?.probePort(window)
                }
            }
        }
    }

    func updateHookStatuses() {
        for windowId in hookedWindows {
            if let hook = jsHooks[windowId] {
                if !hook.isHooked {
                    // Hook was lost, remove it
                    hookedWindows.remove(windowId)
                    jsHooks.removeValue(forKey: windowId)
                    logger.warning("Hook lost for window \(windowId)")
                }
            }
        }
    }

    @available(*, deprecated, message: "Use specific command methods instead of arbitrary JavaScript")
    func runJavaScript(_ script: String, on windowId: String) async throws -> String {
        guard let hook = jsHooks[windowId] else {
            throw JSHookError.noHookForWindow(windowId)
        }

        // This will return an error due to Trusted Types, but maintains backward compatibility
        return try await hook.runJS(script)
    }

    /// Send a command to a specific window's hook
    func sendCommand(_ command: [String: Any], to windowId: String) async throws -> String {
        guard let hook = jsHooks[windowId] else {
            throw JSHookError.noHookForWindow(windowId)
        }

        return try await hook.sendCommand(command)
    }

    func addHookedWindow(_ windowId: String) {
        hookedWindows.insert(windowId)
    }

    func removeHookedWindow(_ windowId: String) {
        hookedWindows.remove(windowId)
    }

    func incrementPort() {
        nextPort += 1
    }

    func loadPortMappings() {
        if let data = UserDefaults.standard.data(forKey: "CursorJSHookPortMappings"),
           let mappings = try? JSONDecoder().decode([String: UInt16].self, from: data)
        {
            windowPorts = mappings

            // Update nextPort to avoid conflicts
            if let maxPort = mappings.values.max() {
                nextPort = maxPort + 1
            }

            logger.debug("Loaded port mappings: \(mappings)")
        }
    }

    func savePortMappings() {
        do {
            let data = try JSONEncoder().encode(windowPorts)
            UserDefaults.standard.set(data, forKey: "CursorJSHookPortMappings")
            logger.debug("Saved port mappings: \(windowPorts)")
        } catch {
            logger.error("Failed to save port mappings: \(error.localizedDescription)")
        }
    }

    // MARK: Private

    private let logger = Logger(category: .settings)

    // MARK: - Private Methods

    private func probePort(_ window: MonitoredWindowInfo) async {
        let startPort: UInt16 = 9001
        let endPort: UInt16 = 9050

        for port in startPort ... endPort {
            do {
                let probeHook = try await CursorJSHook(
                    applicationName: "Cursor",
                    port: port,
                    skipInjection: true,
                    targetWindowTitle: window.windowTitle
                )

                logger.debug("🔍 Probing port \(port) for window \(window.windowTitle ?? "Unknown")...")
                
                if await probeHook.probeForExistingHook(timeout: 2.0) {
                    jsHooks[window.id] = probeHook
                    hookedWindows.insert(window.id)
                    windowPorts[window.id] = port

                    logger.info("🎆 Found existing hook for window \(window.windowTitle ?? "Unknown") on port \(port)!")
                    logger.info("🔗 Reconnected to existing JS hook")
                    savePortMappings()
                    break
                } else {
                    logger.debug("🔕 No hook found on port \(port)")
                }
            } catch {
                // Continue to next port
                continue
            }
        }
    }
}

// MARK: - Errors

enum JSHookError: Error, LocalizedError {
    case noHookForWindow(String)
    case hookNotConnected

    // MARK: Internal

    var errorDescription: String? {
        switch self {
        case let .noHookForWindow(windowId):
            "No JavaScript hook available for window: \(windowId)"
        case .hookNotConnected:
            "JavaScript hook is not connected"
        }
    }
}
