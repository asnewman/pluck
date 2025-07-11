import Cocoa
import SwiftUI
import ApplicationServices

class HotkeyManager: ObservableObject {
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var eventTap: CFMachPort?
    private var configManager: ConfigurationManager?
    
    // Double-shift detection properties
    private var lastShiftPressTime: CFTimeInterval = 0
    private var isWaitingForSelector = false
    private let doubleShiftThreshold: CFTimeInterval = 0.5 // 500ms window for double-shift
    private var selectorTimeoutTimer: Timer?
    
    // Overlay window
    private var overlayWindowController: SelectorOverlayWindowController?
    
    func setConfigurationManager(_ configManager: ConfigurationManager) {
        self.configManager = configManager
    }
    
    // Event tap callback for consuming events system-wide
    private let eventTapCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
        return hotkeyManager.handleCGEvent(proxy: proxy, type: type, event: event)
    }
    
    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard configManager != nil else {
            return Unmanaged.passUnretained(event)
        }
        
        // Convert CGEvent to NSEvent for compatibility with existing logic
        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }
        
        let shouldConsume = handleKeyEvent(event: nsEvent)
        return shouldConsume ? nil : Unmanaged.passUnretained(event)
    }
    
    func registerHotkey() {
        // Check if we have accessibility permissions
        print("Checking accessibility permissions...")
        let trusted = AXIsProcessTrusted()
        print("AXIsProcessTrusted result: \(trusted)")
        
        if !trusted {
            print("Accessibility permissions not granted. Requesting...")
            
            // Show informational popup when permissions are missing
            showAccessibilityMissingPopup()
            
            // Request accessibility permissions
            let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            let accessEnabled = AXIsProcessTrustedWithOptions(options)
            print("AXIsProcessTrustedWithOptions result: \(accessEnabled)")
            
            if !accessEnabled {
                print("User needs to grant accessibility permissions in System Preferences")
                print("Since running from Xcode, add 'Xcode' to System Preferences > Security & Privacy > Privacy > Accessibility")
                print("You may also need to add the built app itself when it appears in the list")
                return
            }
        }
        
        // Create event tap for system-wide event consumption
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: selfPtr
        )
        
        guard let eventTap = eventTap else {
            print("Failed to create event tap - accessibility permissions may be required")
            return
        }
        
        // Create run loop source and add to current run loop
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        // Keep local monitor for when our own app is focused (as backup)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            print("Local key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags), type=\(event.type.rawValue)")
            let shouldConsume = self.handleKeyEvent(event: event)
            return shouldConsume ? nil : event
        }
        
        if let configManager = configManager {
            print("Hotkey monitoring registered for \(configManager.pluckKey.displayText)+[character keys]")
        } else {
            print("Hotkey monitoring registered (no configuration manager)")
        }
    }
    
    func unregisterHotkey() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
        
        cancelSelectorTimeout()
        isWaitingForSelector = false
        hideSelectorOverlay()
    }
    
    private func showSelectorOverlay(isDoubleShiftMode: Bool) {
        guard let configManager = configManager else { return }
        
        print("HotkeyManager: showSelectorOverlay called, isDoubleShiftMode: \(isDoubleShiftMode)")
        DispatchQueue.main.async {
            // Only hide existing overlay if there is one
            if self.overlayWindowController != nil {
                print("HotkeyManager: Hiding existing overlay")
                self.overlayWindowController?.hide()
                self.overlayWindowController = nil
            }
            
            print("HotkeyManager: Creating new overlay with \(configManager.hotkeyBindings.count) bindings")
            self.overlayWindowController = SelectorOverlayWindowController(
                hotkeyBindings: configManager.hotkeyBindings,
                isDoubleShiftMode: isDoubleShiftMode
            )
            print("HotkeyManager: Calling show on overlay")
            self.overlayWindowController?.show()
        }
    }
    
    private func hideSelectorOverlay() {
        print("HotkeyManager: hideSelectorOverlay called")
        DispatchQueue.main.async {
            print("HotkeyManager: On main queue, hiding overlay")
            self.overlayWindowController?.hide()
            self.overlayWindowController = nil
        }
    }
    
    private func startSelectorTimeout() {
        cancelSelectorTimeout()
        selectorTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            print("HotkeyManager: Selector timeout - resetting double-shift state")
            self?.isWaitingForSelector = false
            self?.hideSelectorOverlay()
            self?.selectorTimeoutTimer = nil
        }
    }
    
    private func cancelSelectorTimeout() {
        selectorTimeoutTimer?.invalidate()
        selectorTimeoutTimer = nil
    }
    
    private func showAccessibilityMissingPopup() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Pluck needs accessibility permissions to monitor global hotkeys. Grant access in System Preferences, then restart Pluck."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings & Quit")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Preferences to Accessibility section
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                // Then quit the application
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    @discardableResult
    private func handleKeyEvent(event: NSEvent) -> Bool {
        guard let configManager = configManager else {
            print("No configuration manager available")
            return false
        }
        
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        let currentTime = CACurrentMediaTime()
        let eventType = event.type
        
        // Debug: Log all key events when double-shift is enabled
        if configManager.isDoubleShiftEnabled {
            print("Key event: keyCode=\(keyCode), type=\(eventType.rawValue), modifiers=\(modifierFlags), time=\(currentTime), lastShiftTime=\(lastShiftPressTime), timeDiff=\(currentTime - lastShiftPressTime)")
        }
        
        // Check for double-shift activation (left shift: 56, right shift: 60)
        // For shift keys, we need to check flagsChanged events when shift is pressed
        if configManager.isDoubleShiftEnabled && eventType == .flagsChanged && (keyCode == 56 || keyCode == 60) {
            // Only trigger on shift key press (when shift modifier is present)
            if modifierFlags.contains(.shift) {
                print("Shift press detected. Current time: \(currentTime), Last shift time: \(lastShiftPressTime), Diff: \(currentTime - lastShiftPressTime)")
                if currentTime - lastShiftPressTime <= doubleShiftThreshold && lastShiftPressTime > 0 {
                    // Double-shift detected
                    print("Double-shift detected! Waiting for selector key...")
                    isWaitingForSelector = true
                    lastShiftPressTime = 0 // Reset to prevent triple-shift issues
                    showSelectorOverlay(isDoubleShiftMode: true)
                    startSelectorTimeout()
                    return true
                } else {
                    print("First shift or too slow, recording time")
                    lastShiftPressTime = currentTime
                }
            } else {
                print("Shift released")
            }
            // Don't consume shift key events
            return false
        }
        
        
        // Handle ESC key to reset double-shift state and dismiss any overlay
        if configManager.isDoubleShiftEnabled && eventType == .keyDown && keyCode == 53 { // Escape key
            if lastShiftPressTime > 0 || isWaitingForSelector {
                print("ESC pressed, resetting double-shift state")
                lastShiftPressTime = 0
                if isWaitingForSelector {
                    cancelSelectorTimeout()
                    isWaitingForSelector = false
                    hideSelectorOverlay()
                }
                return true // Consume the escape key
            }
        }
        
        // Reset double-shift timing if any non-shift key is pressed
        if configManager.isDoubleShiftEnabled && eventType == .keyDown && keyCode != 56 && keyCode != 60 {
            if lastShiftPressTime > 0 {
                print("Non-shift key pressed, resetting double-shift timing")
                lastShiftPressTime = 0
            }
        }
        
        // Handle selector key after double-shift (only for keyDown events)
        if isWaitingForSelector && eventType == .keyDown {
            // Reset the timer to give user more time to select
            overlayWindowController?.resetHideTimer()
            
            // Only hide overlay and reset state if we successfully handle the selector key
            let handledSuccessfully = handleSelectorKey(keyCode: keyCode)
            if handledSuccessfully {
                cancelSelectorTimeout()
                isWaitingForSelector = false
                hideSelectorOverlay()
            }
            return handledSuccessfully
        }
        
        // Handle regular pluck key combinations (only for keyDown events)
        if eventType == .keyDown && !configManager.pluckKey.isEmpty && modifierFlags.contains(configManager.pluckKey.modifierFlags) {
            return handleSelectorKey(keyCode: keyCode)
        }
        
        return false
    }
    
    private func handleSelectorKey(keyCode: UInt16) -> Bool {
        guard let configManager = configManager else { return false }
        
        // Find the character for this key code
        guard let character = KeyMapping.shared.character(for: keyCode) else {
            print("No character mapping found for keyCode: \(keyCode)")
            return false
        }
        
        // Find binding for this character
        if let binding = configManager.hotkeyBindings.first(where: { $0.selectorCharacter == character }) {
            print("Hotkey detected for '\(character)'! Focusing \(binding.appName)...")
            focusApp(binding: binding)
            return true
        } else {
            print("No binding found for character: '\(character)' (keyCode: \(keyCode))")
            return false
        }
    }
    
    private func focusApp(binding: HotkeyBinding) {
        let workspace = NSWorkspace.shared
        
        // First try to find running app by bundle identifier
        var targetApps: [NSRunningApplication] = []
        
        if let bundleId = binding.bundleIdentifier {
            targetApps = workspace.runningApplications.filter { $0.bundleIdentifier == bundleId }
        }
        
        // Fallback to name-based search
        if targetApps.isEmpty {
            targetApps = workspace.runningApplications.filter { app in
                app.localizedName?.lowercased().contains(binding.appName.lowercased()) == true
            }
        }
        
        print("Found \(targetApps.count) matching apps for \(binding.appName)")
        
        if let targetApp = targetApps.first {
            print("Activating \(binding.appName)...")
            
            // Use NSWorkspace to activate the running app directly
            let success = targetApp.activate(options: [.activateIgnoringOtherApps])
            if success {
                print("Successfully activated \(binding.appName)")
            } else {
                print("Failed to activate \(binding.appName), trying alternative approach...")
                // Alternative: try to launch which will also activate
                if let bundleId = binding.bundleIdentifier,
                   let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.activates = true
                    workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
                } else {
                    workspace.launchApplication(binding.appName)
                }
            }
        } else {
            print("\(binding.appName) not running, trying to launch...")
            
            // Try to launch app if it's not running
            if let bundleId = binding.bundleIdentifier,
               let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                print("Found \(binding.appName) at: \(appURL)")
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
            } else {
                // Fallback to name-based launch
                print("Trying to launch by name: \(binding.appName)")
                workspace.launchApplication(binding.appName)
            }
        }
    }
    
    // Legacy method for backwards compatibility
    private func focusMessages() {
        let workspace = NSWorkspace.shared
        let messagesApps = workspace.runningApplications.filter { app in
            app.bundleIdentifier == "com.apple.MobileSMS" || 
            app.localizedName?.lowercased().contains("messages") == true
        }
        
        print("Found Messages apps: \(messagesApps.map { $0.localizedName ?? "Unknown" })")
        
        if let messagesApp = messagesApps.first {
            print("Activating Messages app...")
            
            // Use NSWorkspace to activate the running app directly
            let success = messagesApp.activate(options: [.activateIgnoringOtherApps])
            if success {
                print("Successfully activated Messages")
            } else {
                print("Failed to activate Messages, trying alternative approach...")
                // Alternative: try to launch which will also activate
                if let messagesURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.MobileSMS") {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.activates = true
                    workspace.openApplication(at: messagesURL, configuration: configuration) { _, _ in }
                } else {
                    workspace.launchApplication("Messages")
                }
            }
        } else {
            print("Messages not running, trying to launch...")
            // Try to launch Messages if it's not running
            if let messagesURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.MobileSMS") {
                print("Found Messages at: \(messagesURL)")
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                workspace.openApplication(at: messagesURL, configuration: configuration) { _, _ in }
            } else {
                print("Could not find Messages app")
            }
        }
    }
    
    deinit {
        unregisterHotkey()
    }
}