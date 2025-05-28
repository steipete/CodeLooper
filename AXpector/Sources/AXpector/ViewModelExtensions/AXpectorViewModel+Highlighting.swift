import AppKit // For AXUIElement, NSRect, NSScreen
import SwiftUI // For Color, NSColor

// import OSLog // For Logger // REMOVE OSLog
import AXorcist // For GlobalAXLogger and ax...Log helpers

// MARK: - Highlight Window Logic

extension AXpectorViewModel {
    func updateHighlightForNode(_ node: AXPropertyNode?, isHover: Bool = false, isFocusHighlight: Bool = false) {
        guard let targetNode = node else {
            if (isHover && isHoverModeActive) || (isFocusHighlight && isFocusTrackingModeActive) ||
                (!isHover && !isFocusHighlight)
            {
                highlightWindowController.hideHighlight()
            }
            return
        }

        var highlightColor = NSColor.blue.withAlphaComponent(0.4)
        if isFocusTrackingModeActive, isFocusHighlight {
            highlightColor = NSColor.green.withAlphaComponent(0.4)
        } else if isHoverModeActive, isHover {
            highlightColor = NSColor.orange.withAlphaComponent(0.4)
        } else if selectedNode?.id == targetNode.id, !isHoverModeActive, !isFocusTrackingModeActive {
            // Use default blue
        } else {
            if !isHoverModeActive, !isFocusTrackingModeActive {
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

    func getFrameForAXElement(_ elementRef: AXUIElement) async -> NSRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let posError = AXUIElementCopyAttributeValue(elementRef, kAXPositionAttribute as CFString, &positionValue)
        let sizeError = AXUIElementCopyAttributeValue(elementRef, kAXSizeAttribute as CFString, &sizeValue)

        guard posError == .success, let posValUnwrapped = positionValue else {
            axDebugLog("Could not get position for element (nil CFTypeRef). Error: \(posError.rawValue)")
            return nil
        }
        guard CFGetTypeID(posValUnwrapped) == AXValueGetTypeID() else {
            axDebugLog(
                "Position value is not an AXValue based on CFGetTypeID. Actual TypeID: \(CFGetTypeID(posValUnwrapped))"
            )
            return nil
        }
        let posAxValue = posValUnwrapped as! AXValue // Force cast after type check

        guard AXValueGetType(posAxValue) == .cgPoint else {
            axDebugLog("Position AXValue is not of type CGPoint. Type: \(AXValueGetType(posAxValue).rawValue)")
            return nil
        }

        guard sizeError == .success, let sizeValUnwrapped = sizeValue else {
            axDebugLog("Could not get size for element (nil CFTypeRef). Error: \(sizeError.rawValue)")
            return nil
        }
        guard CFGetTypeID(sizeValUnwrapped) == AXValueGetTypeID() else {
            axDebugLog(
                "Size value is not an AXValue based on CFGetTypeID. Actual TypeID: \(CFGetTypeID(sizeValUnwrapped))"
            )
            return nil
        }
        let sizeAxValue = sizeValUnwrapped as! AXValue // Force cast after type check

        guard AXValueGetType(sizeAxValue) == .cgSize else {
            axDebugLog("Size AXValue is not of type CGSize. Type: \(AXValueGetType(sizeAxValue).rawValue)")
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posAxValue, .cgPoint, &point)
        AXValueGetValue(sizeAxValue, .cgSize, &size)

        guard size.width > 0, size.height > 0 else {
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
