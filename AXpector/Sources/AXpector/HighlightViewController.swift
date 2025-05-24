import Cocoa

// The custom view that will draw the highlight
class HighlightView: NSView {
    var highlightColor: NSColor = NSColor.red.withAlphaComponent(0.3) {
        didSet {
            needsDisplay = true // Redraw if color changes
        }
    }
    var borderWidth: CGFloat = 3.0 {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Draw a border
        context.setStrokeColor(highlightColor.cgColor)
        context.setLineWidth(borderWidth)
        let borderInset = borderWidth / 2.0 // Inset to keep border within bounds
        let borderRect = bounds.insetBy(dx: borderInset, dy: borderInset)
        context.stroke(borderRect)
        
        // Optionally, fill the rect with a very light color
        // highlightColor.withAlphaComponent(0.1).setFill()
        // NSBezierPath(rect: bounds).fill()
    }

    // Ensure the view is transparent where not drawn
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // No specific setup needed here for transparency, as the window is transparent.
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// The view controller for the highlight window
class HighlightViewController: NSViewController {
    private var highlightView: HighlightView!

    override func loadView() {
        highlightView = HighlightView()
        self.view = highlightView
    }

    func updateHighlight(color: NSColor? = nil, borderWidth: CGFloat? = nil) {
        if let color = color {
            highlightView.highlightColor = color
        }
        if let borderWidth = borderWidth {
            highlightView.borderWidth = borderWidth
        }
        // The view will redraw itself due to didSet in HighlightView
    }
}

// Controller for the highlight window itself
class HighlightWindowController: NSWindowController {
    private var highlightViewController: HighlightViewController!

    convenience init() {
        let highlightVC = HighlightViewController()
        let window = HighlightWindow(contentViewController: highlightVC)
        // Set initial size or let it be set dynamically.
        // window.setContentSize(NSSize(width: 100, height: 100))
        self.init(window: window)
        self.highlightViewController = highlightVC
    }

    func showHighlight(at frame: NSRect, color: NSColor? = nil, borderWidth: CGFloat? = nil) {
        guard let window = self.window as? HighlightWindow else { return }
        
        // Ensure frame is valid
        guard frame.width > 0 && frame.height > 0 else {
            hideHighlight()
            return
        }
        
        highlightViewController.updateHighlight(color: color, borderWidth: borderWidth)
        
        // Order the window out before setting the frame to prevent animation artifacts
        // if it was previously visible at a different location/size.
        window.orderOut(nil)
        window.setFrame(frame, display: true, animate: false) // Animate can be true if desired
        window.orderFrontRegardless() // Ensure it's visible
    }

    func hideHighlight() {
        self.window?.orderOut(nil)
    }
} 