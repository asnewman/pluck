import SwiftUI
import Cocoa

class SearchWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
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
        return true // Allow focus for text input
    }
    
    override var canBecomeMain: Bool {
        return false
    }
}

class SearchWindowController: NSWindowController {
    private var hideTimer: Timer?
    
    init(onAppSelected: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        let window = SearchWindow()
        super.init(window: window)
        
        // Create SwiftUI view
        let searchView = SearchView(
            onAppSelected: { appName in
                onAppSelected(appName)
                self.hide()
            },
            onCancel: {
                onCancel()
                self.hide()
            }
        )
        
        // Wrap in hosting view
        let hostingView = NSHostingView(rootView: searchView)
        window.contentView = hostingView
        
        // Position window at center of screen
        positionWindow()
        
        // Set up key handling for escape
        setupKeyHandling()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupKeyHandling() {
        guard let window = window else { return }
        
        // Add local monitor for escape key
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape key
                self?.hide()
                return nil // Consume the event
            }
            return event
        }
    }
    
    private func positionWindow() {
        guard let window = window, let screen = NSScreen.main else { 
            print("SearchWindow: positionWindow failed - no window or screen")
            return 
        }
        
        print("SearchWindow: positioning window")
        
        // Set fixed window size
        let contentSize = NSSize(width: 320, height: 400)
        window.setContentSize(contentSize)
        
        // Center on screen
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2
        
        print("SearchWindow: setting frame origin to: \(NSPoint(x: x, y: y))")
        window.setFrameOrigin(NSPoint(x: x, y: y))
        print("SearchWindow: final window frame: \(window.frame)")
    }
    
    func show() {
        print("SearchWindow: show() called")
        window?.makeKeyAndOrderFront(nil)
        
        // Ensure the window becomes first responder to receive key events
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Find the KeyHandlerView and make it first responder
            if let contentView = self.window?.contentView {
                self.findAndFocusKeyHandler(in: contentView)
            }
        }
        
        print("SearchWindow: window made key and ordered front, isVisible: \(window?.isVisible ?? false)")
        
        // Start hide timer (hide after 15 seconds if no interaction)
        startHideTimer()
    }
    
    private func startHideTimer() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }
    
    func resetHideTimer() {
        startHideTimer()
    }
    
    func hide() {
        print("SearchWindow: hide() called")
        hideTimer?.invalidate()
        hideTimer = nil
        window?.orderOut(nil)
    }
    
    private func findAndFocusKeyHandler(in view: NSView) {
        // Look for KeyHandlerView in the view hierarchy
        for subview in view.subviews {
            if subview.className.contains("KeyHandlerView") {
                window?.makeFirstResponder(subview)
                return
            }
            findAndFocusKeyHandler(in: subview)
        }
    }
    
    deinit {
        hideTimer?.invalidate()
    }
}