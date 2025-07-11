import SwiftUI
import Cocoa

class SelectorOverlayWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.hasShadow = true
        self.level = .floating
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
    
    override var canBecomeKey: Bool {
        return false
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

class SelectorOverlayWindowController: NSWindowController {
    private var hideTimer: Timer?
    
    init(hotkeyBindings: [HotkeyBinding], isDoubleShiftMode: Bool = true) {
        let window = SelectorOverlayWindow()
        super.init(window: window)
        
        // Create SwiftUI view
        let overlayView = SelectorOverlayView(
            hotkeyBindings: hotkeyBindings.sorted { $0.selectorCharacter < $1.selectorCharacter },
            isDoubleShiftMode: isDoubleShiftMode
        )
        
        // Wrap in hosting view
        let hostingView = NSHostingView(rootView: overlayView)
        window.contentView = hostingView
        
        // Position window at center of screen
        positionWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func positionWindow() {
        guard let window = window, let screen = NSScreen.main else { 
            print("SelectorOverlayWindow: positionWindow failed - no window or screen")
            return 
        }
        
        print("SelectorOverlayWindow: positioning window")
        
        // Calculate size needed for content
        window.contentView?.layoutSubtreeIfNeeded()
        let contentSize = window.contentView?.fittingSize ?? NSSize(width: 300, height: 200)
        
        print("SelectorOverlayWindow: content size: \(contentSize)")
        
        // Set window size
        window.setContentSize(contentSize)
        
        // Center on screen
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2
        
        print("SelectorOverlayWindow: setting frame origin to: \(NSPoint(x: x, y: y))")
        window.setFrameOrigin(NSPoint(x: x, y: y))
        print("SelectorOverlayWindow: final window frame: \(window.frame)")
    }
    
    func show() {
        print("SelectorOverlayWindow: show() called")
        window?.orderFrontRegardless()
        print("SelectorOverlayWindow: window ordered front, isVisible: \(window?.isVisible ?? false)")
        
        // Start hide timer (hide after 5 seconds if no interaction)
        startHideTimer()
    }
    
    private func startHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
    
    func resetHideTimer() {
        startHideTimer()
    }
    
    func hide() {
        print("SelectorOverlayWindow: hide() called")
        hideTimer?.invalidate()
        hideTimer = nil
        window?.orderOut(nil)
    }
    
    deinit {
        hideTimer?.invalidate()
    }
}