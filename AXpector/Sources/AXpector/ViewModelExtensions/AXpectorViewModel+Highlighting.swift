import SwiftUI // For Color, NSColor
import AppKit // For AXUIElement, NSRect, NSScreen
// import OSLog // For Logger // REMOVE OSLog
import AXorcist // For GlobalAXLogger and ax...Log helpers

// MARK: - Highlight Window Logic
extension AXpectorViewModel {
    internal func updateHighlightForNode(_ node: AXPropertyNode?, isHover: Bool = false, isFocusHighlight: Bool = false) {
        guard let targetNode = node else {
            if (isHover && isHoverModeActive) || (isFocusHighlight && isFocusTrackingModeActive) || (!isHover && !isFocusHighlight) { 
                 highlightWindowController.hideHighlight()
            }
            return
        }

        var highlightColor = NSColor.blue.withAlphaComponent(0.4) 
        if isFocusTrackingModeActive && isFocusHighlight { 
            highlightColor = NSColor.green.withAlphaComponent(0.4) 
        } else if isHoverModeActive && isHover { 
            highlightColor = NSColor.orange.withAlphaComponent(0.4) 
        } else if selectedNode?.id == targetNode.id && !isHoverModeActive && !isFocusTrackingModeActive { 
            // Use default blue
        } else { 
            if !isHoverModeActive && !isFocusTrackingModeActive { 
                 highlightWindowController.hideHighlight()
            }
            return 
        }

        Task {
            let frame = await getFrameForAXElement(targetNode.axElementRef)
            if let nsRectFrame = frame {
                highlightWindowController.showHighlight(at: nsRectFrame, color: highlightColor)
            } else {
                highlightWindowController.hideHighlight()
            }
        }
    }

    private func getFrameForAXElement(_ elementRef: AXUIElement) async -> NSRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let posError = AXUIElementCopyAttributeValue(elementRef, kAXPositionAttribute as CFString, &positionValue)
        let sizeError = AXUIElementCopyAttributeValue(elementRef, kAXSizeAttribute as CFString, &sizeValue)

        guard posError == .success, let posVal = positionValue, AXValueGetType(posVal) == .cgPoint else {
            axDebugLog("Could not get position for element or wrong type. Error: \(posError.rawValue)")
            if let pv = positionValue { CFRelease(pv) }
            if let sv = sizeValue { CFRelease(sv) }
            return nil
        }
        defer { CFRelease(posVal) }

        guard sizeError == .success, let sizeVal = sizeValue, AXValueGetType(sizeVal) == .cgSize else {
            axDebugLog("Could not get size for element or wrong type. Error: \(sizeError.rawValue)")
            if let sv = sizeValue { CFRelease(sv) }
            return nil
        }
        defer { CFRelease(sizeVal) }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posVal, .cgPoint, &point)
        AXValueGetValue(sizeVal, .cgSize, &size)

        guard size.width > 0 && size.height > 0 else {
            axDebugLog("Element has zero or negative size: \(size)")
            return nil
        }
        
        guard let mainScreen = NSScreen.main else {
            axErrorLog("Cannot get main screen for coordinate conversion.")
            return nil
        }
        let screenHeight = mainScreen.frame.height
        let convertedY = screenHeight - point.y - size.height
        
        return NSRect(x: point.x, y: convertedY, width: size.width, height: size.height)
    }
} 