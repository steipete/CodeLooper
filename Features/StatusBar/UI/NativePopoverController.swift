import AppKit
import SwiftUI

/// Controller for native NSPopover with proper styling
@MainActor
final class NativePopoverController: NSObject {
    private var popover: NSPopover?
    
    func showPopover(relativeTo button: NSStatusBarButton, content: some View) {
        // Close any existing popover
        popover?.close()
        
        // Create new popover
        let newPopover = NSPopover()
        newPopover.contentViewController = NSHostingController(rootView: content)
        newPopover.behavior = .transient
        newPopover.animates = true
        
        // Show with native styling
        newPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        
        self.popover = newPopover
    }
    
    func closePopover() {
        popover?.close()
        popover = nil
    }
    
    var isShown: Bool {
        popover?.isShown ?? false
    }
}