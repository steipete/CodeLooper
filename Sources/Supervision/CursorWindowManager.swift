import ApplicationServices
import AXorcist
import Diagnostics
import Foundation

/// Manages window-related operations for CursorMonitor
@MainActor
extension CursorMonitor {
    /// Updates windows for a given app
    internal func updateWindows(for appInfo: inout MonitoredAppInfo) async {
        guard let appElement = applicationElement(forProcessID: appInfo.pid) else {
            logger.warning("Could not get application element for PID \(appInfo.pid) to fetch windows.")
            appInfo.windows = []
            return
        }

        if monitoringCycleCount % 10 == 0 {
            logger.debug(
                "Attempting to fetch windows for PID \(appInfo.pid) using element: \(appElement.briefDescription())"
            )
        }

        guard let windowElements: [Element] = appElement.windows() else {
            if monitoringCycleCount % 10 == 0 {
                logger.debug(
                    "Application PID \(appInfo.pid) has no windows or failed to fetch (appElement.windows() returned nil)."
                )
            }
            appInfo.windows = []
            return
        }

        if monitoringCycleCount % 10 == 0 {
            logger.debug("Fetched \(windowElements.count) raw window elements for PID \(appInfo.pid).")
        }

        var newWindowInfos: [MonitoredWindowInfo] = []
        for (index, windowElement) in windowElements.enumerated() {
            let title: String? = windowElement.title()
            let windowId = "\(appInfo.pid)-window-\(title ?? "untitled")-\(index)"

            // Fetch the document path
            var documentPath: String? = nil
            if let docURLString: String = windowElement
                .attribute(Attribute<String>(AXAttributeNames.kAXDocumentAttribute))
            {
                documentPath = docURLString
                // Convert file URL to standard path
                if let url = URL(string: docURLString), url.isFileURL {
                    documentPath = url.path
                }
            } else {
                // Log missing document attribute periodically
                if monitoringCycleCount % 20 == 0 {
                    logger.debug(
                        "Window element (Title: \(title ?? "N/A"), ID: \(windowId)) does not have kAXDocumentAttribute or it's nil."
                    )
                }
            }

            newWindowInfos.append(MonitoredWindowInfo(
                id: windowId,
                windowTitle: title,
                axElement: windowElement,
                documentPath: documentPath,
                isPaused: false
            ))
        }

        appInfo.windows = newWindowInfos
        if monitoringCycleCount % 10 == 0 {
            logger.debug("""
            Updated \(newWindowInfos.count) windows for PID \(appInfo.pid). \
            Titles: \(newWindowInfos.map { $0.windowTitle ?? "N/A" })
            """)
        }
    }

    /// Processes all monitored apps to update their window information
    internal func processMonitoredApps() async {
        var newMonitoredApps = self.monitoredApps
        for i in newMonitoredApps.indices {
            await updateWindows(for: &newMonitoredApps[i])
        }
        self.monitoredApps = newMonitoredApps
    }

    /// Gets primary displayable text from an AX element
    internal func getPrimaryDisplayableText(axElement: AXElement?) -> String {
        guard let element = axElement else { return "" }
        let attributeKeysInOrder: [String] = [
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXPlaceholderValueAttribute as String,
            kAXHelpAttribute as String,
        ]
        for key in attributeKeysInOrder {
            if let anyCodableInstance = element.attributes?[key] {
                if let stringValue = anyCodableInstance.value as? String, !stringValue.isEmpty {
                    return stringValue
                }
            }
        }
        return ""
    }

    /// Gets secondary displayable text from an AX element
    internal func getSecondaryDisplayableText(axElement: AXElement?) -> String {
        guard let element = axElement else { return "" }
        let attributeKeysInOrder: [String] = [
            kAXValueAttribute as String,
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
        ]
        for key in attributeKeysInOrder {
            if let anyCodableInstance = element.attributes?[key] {
                if let stringValue = anyCodableInstance.value as? String, !stringValue.isEmpty {
                    return stringValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                }
            }
        }
        return ""
    }
}