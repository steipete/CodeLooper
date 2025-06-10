import AppKit
import SwiftUI

/// Custom borderless window that appears below the menu bar icon.
@MainActor
final class CustomMenuWindow: NSPanel {
    private var eventMonitor: Any?
    private let hostingController: NSHostingController<AnyView>
    private var retainedContentView: AnyView?
    
    // Closure to be called when window hides
    var onHide: (() -> Void)?
    
    init(contentView: some View) {
        // Store the content view to prevent deallocation
        let wrappedView = AnyView(contentView)
        self.retainedContentView = wrappedView
        
        // Create content view controller
        hostingController = NSHostingController(rootView: wrappedView)
        
        // Initialize window
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false)
        
        // Configure window appearance
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        
        // Set content view controller
        contentViewController = hostingController
        
        // Force view to load immediately
        _ = hostingController.view
        
        // Add visual effect view for native appearance
        if let contentView = contentViewController?.view {
            // Create visual effect view
            let visualEffectView = NSVisualEffectView()
            visualEffectView.material = .popover
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            visualEffectView.layer?.cornerRadius = 10
            visualEffectView.layer?.masksToBounds = true
            
            // Add border for refined look
            visualEffectView.layer?.borderWidth = 0.5
            visualEffectView.layer?.borderColor = NSColor.separatorColor.cgColor
            
            // Replace content view with visual effect view
            visualEffectView.frame = contentView.bounds
            visualEffectView.autoresizingMask = [.width, .height]
            
            // Add the hosting view as a subview of the visual effect view
            contentView.removeFromSuperview()
            visualEffectView.addSubview(contentView)
            self.contentView = visualEffectView
            
            // Add shadow to the window itself for depth
            hasShadow = true
            
            // Ensure content fills the visual effect view
            contentView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                contentView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
                contentView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
                contentView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
                contentView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
            ])
        }
    }
    
    func show(relativeTo statusItemButton: NSStatusBarButton) {
        guard let statusWindow = statusItemButton.window else { return }
        
        // Get status item frame in screen coordinates
        let buttonBounds = statusItemButton.bounds
        let buttonFrameInWindow = statusItemButton.convert(buttonBounds, to: nil)
        let buttonFrameInScreen = statusWindow.convertToScreen(buttonFrameInWindow)
        
        // Layout the view first
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Determine the preferred size
        let fittingSize = hostingController.view.fittingSize
        let preferredSize = NSSize(width: max(380, fittingSize.width), height: fittingSize.height)
        
        // Update the panel's content size
        setContentSize(preferredSize)
        
        // Calculate optimal position
        let targetFrame = calculateOptimalFrame(
            relativeTo: buttonFrameInScreen,
            preferredSize: preferredSize)
        
        setFrame(targetFrame, display: false)
        
        // Ensure the view is loaded
        _ = hostingController.view
        hostingController.view.needsLayout = true
        hostingController.view.layoutSubtreeIfNeeded()
        
        // Display window safely
        displayWindowSafely()
    }
    
    private func displayWindowSafely() {
        alphaValue = 0
        
        NSApp.activate(ignoringOtherApps: true)
        orderFrontRegardless()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self else { return }
            
            if self.isVisible {
                self.animateWindowIn()
                self.setupEventMonitoring()
            } else {
                self.displayWindowFallback()
            }
        }
    }
    
    private func displayWindowFallback() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            NSApp.activate(ignoringOtherApps: true)
            self.makeKeyAndOrderFront(nil)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                
                if self.isVisible {
                    self.animateWindowIn()
                    self.setupEventMonitoring()
                } else {
                    self.orderFrontRegardless()
                    self.alphaValue = 1.0
                    self.setupEventMonitoring()
                }
            }
        }
    }
    
    private func animateWindowIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0)
            context.allowsImplicitAnimation = true
            self.animator().alphaValue = 1
        }
    }
    
    private func calculateOptimalFrame(relativeTo statusFrame: NSRect, preferredSize: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            let x = statusFrame.midX - preferredSize.width / 2
            let y = statusFrame.minY - preferredSize.height - 5
            return NSRect(origin: NSPoint(x: x, y: y), size: preferredSize)
        }
        
        let screenFrame = screen.visibleFrame
        let gap: CGFloat = 5
        
        // Start with centered position below status item
        var x = statusFrame.midX - preferredSize.width / 2
        let y = statusFrame.minY - preferredSize.height - gap
        
        // Ensure window stays within screen bounds
        let minX = screenFrame.minX + 10
        let maxX = screenFrame.maxX - preferredSize.width - 10
        x = max(minX, min(maxX, x))
        
        // Ensure window doesn't go below screen
        let finalY = max(screenFrame.minY + 10, y)
        
        return NSRect(
            origin: NSPoint(x: x, y: finalY),
            size: preferredSize)
    }
    
    func hide() {
        orderOut(nil)
        teardownEventMonitoring()
        onHide?()
    }
    
    private func setupEventMonitoring() {
        teardownEventMonitoring()
        
        guard isVisible else { return }
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.isVisible else { return }
            
            let mouseLocation = NSEvent.mouseLocation
            
            if !self.frame.contains(mouseLocation) {
                self.hide()
            }
        }
    }
    
    private func teardownEventMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    override func resignKey() {
        super.resignKey()
        hide()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    deinit {
        MainActor.assumeIsolated {
            teardownEventMonitoring()
        }
    }
}

/// A wrapper view that applies material background to menu content
struct CustomMenuContainer<Content: View>: View {
    @ViewBuilder
    let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        content
            .frame(width: 380)
            .fixedSize(horizontal: false, vertical: true)
            .background(Color.clear)
    }
}