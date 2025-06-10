import AppKit
import SwiftUI

/// HUD-style window that mimics macOS HUD panels
@MainActor
final class HUDMenuWindow: NSPanel {
    private let hostingController: NSHostingController<AnyView>
    var onHide: (() -> Void)?
    
    init(contentView: some View) {
        let wrappedView = AnyView(contentView)
        hostingController = NSHostingController(rootView: wrappedView)
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.hudWindow, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false)
        
        // HUD windows have their own styling
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        
        contentViewController = hostingController
    }
    
    // Rest of implementation similar to CustomMenuWindow...
}