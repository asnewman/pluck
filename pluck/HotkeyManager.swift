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
    private var isShiftCurrentlyPressed = false
    
    // Overlay window
    private var overlayWindowController: SelectorOverlayWindowController?
    
    func setConfigurationManager(_ configManager: ConfigurationManager) {
        self.configManager = configManager
        logInfo("Configuration manager set")
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
        logInfo("Checking accessibility permissions...")
        let trusted = AXIsProcessTrusted()
        logInfo("AXIsProcessTrusted result: \(trusted)")
        
        if !trusted {
            logWarning("Accessibility permissions not granted. Requesting...")
            
            // Show informational popup when permissions are missing
            showAccessibilityMissingPopup()
            
            // Request accessibility permissions
            let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            let accessEnabled = AXIsProcessTrustedWithOptions(options)
            logInfo("AXIsProcessTrustedWithOptions result: \(accessEnabled)")
            
            if !accessEnabled {
                logError("User needs to grant accessibility permissions in System Preferences")
                logInfo("Since running from Xcode, add 'Xcode' to System Preferences > Security & Privacy > Privacy > Accessibility")
                logInfo("You may also need to add the built app itself when it appears in the list")
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
            logError("Failed to create event tap - accessibility permissions may be required")
            return
        }
        
        // Create run loop source and add to current run loop
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        // Keep local monitor for when our own app is focused (as backup)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            logDebug("Local key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags), type=\(event.type.rawValue)")
            let shouldConsume = self.handleKeyEvent(event: event)
            return shouldConsume ? nil : event
        }
        
        if let configManager = configManager {
            logInfo("Hotkey monitoring registered for \(configManager.pluckKey.displayText)+[character keys]")
        } else {
            logWarning("Hotkey monitoring registered (no configuration manager)")
        }
    }
    
    func unregisterHotkey() {
        logInfo("Unregistering hotkey monitoring")
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
        isShiftCurrentlyPressed = false
        hideSelectorOverlay()
    }
    
    private func showSelectorOverlay(isDoubleShiftMode: Bool) {
        guard let configManager = configManager else { return }
        
        logDebug("showSelectorOverlay called, isDoubleShiftMode: \(isDoubleShiftMode)")
        DispatchQueue.main.async {
            // Only hide existing overlay if there is one
            if self.overlayWindowController != nil {
                logDebug("Hiding existing overlay")
                self.overlayWindowController?.hide()
                self.overlayWindowController = nil
            }
            
            logDebug("Creating new overlay with \(configManager.hotkeyBindings.count) bindings")
            self.overlayWindowController = SelectorOverlayWindowController(
                hotkeyBindings: configManager.hotkeyBindings,
                isDoubleShiftMode: isDoubleShiftMode
            )
            logDebug("Calling show on overlay")
            self.overlayWindowController?.show()
        }
    }
    
    private func hideSelectorOverlay() {
        logDebug("hideSelectorOverlay called")
        DispatchQueue.main.async {
            logDebug("On main queue, hiding overlay")
            self.overlayWindowController?.hide()
            self.overlayWindowController = nil
        }
    }
    
    private func startSelectorTimeout() {
        cancelSelectorTimeout()
        selectorTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            logDebug("Selector timeout - resetting double-shift state")
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
        logWarning("Showing accessibility permissions popup")
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Pluck needs accessibility permissions to monitor global hotkeys. Grant access in System Preferences, then restart Pluck."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings & Quit")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                logInfo("User chose to open settings and quit")
                // Open System Preferences to Accessibility section
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                // Then quit the application
                NSApplication.shared.terminate(nil)
            } else {
                logInfo("User cancelled accessibility permissions request")
            }
        }
    }
    
    @discardableResult
    private func handleKeyEvent(event: NSEvent) -> Bool {
        guard let configManager = configManager else {
            logWarning("No configuration manager available")
            return false
        }
        
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags
        let currentTime = CACurrentMediaTime()
        let eventType = event.type
        
        // Debug: Log all key events when double-shift is enabled
        if configManager.isDoubleShiftEnabled {
            logDebug("Key event: keyCode=\(keyCode), type=\(eventType.rawValue), modifiers=\(modifierFlags), time=\(currentTime), lastShiftTime=\(lastShiftPressTime), timeDiff=\(currentTime - lastShiftPressTime)")
        }
        
        // Check for double-shift activation (left shift: 56, right shift: 60)
        // For shift keys, we need to check flagsChanged events for press/release cycles
        if configManager.isDoubleShiftEnabled && eventType == .flagsChanged && (keyCode == 56 || keyCode == 60) {
            if modifierFlags.contains(.shift) {
                // Shift key pressed down
                if !isShiftCurrentlyPressed {
                    logDebug("Shift press started")
                    isShiftCurrentlyPressed = true
                }
            } else {
                // Shift key released - this counts as one "shift press"
                if isShiftCurrentlyPressed {
                    logDebug("Shift released. Current time: \(currentTime), Last shift time: \(lastShiftPressTime), Diff: \(currentTime - lastShiftPressTime)")
                    isShiftCurrentlyPressed = false
                    
                    if currentTime - lastShiftPressTime <= doubleShiftThreshold && lastShiftPressTime > 0 {
                        // Double-shift detected
                        logInfo("Double-shift detected! Waiting for selector key...")
                        isWaitingForSelector = true
                        lastShiftPressTime = 0 // Reset to prevent triple-shift issues
                        showSelectorOverlay(isDoubleShiftMode: true)
                        startSelectorTimeout()
                        return true
                    } else {
                        logDebug("First shift or too slow, recording time")
                        lastShiftPressTime = currentTime
                    }
                }
            }
            // Don't consume shift key events
            return false
        }
        
        
        // Handle ESC key to reset double-shift state and dismiss any overlay
        if configManager.isDoubleShiftEnabled && eventType == .keyDown && keyCode == 53 { // Escape key
            if lastShiftPressTime > 0 || isWaitingForSelector || isShiftCurrentlyPressed {
                logInfo("ESC pressed, resetting double-shift state")
                lastShiftPressTime = 0
                isShiftCurrentlyPressed = false
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
            if lastShiftPressTime > 0 || isShiftCurrentlyPressed {
                logDebug("Non-shift key pressed, resetting double-shift timing")
                lastShiftPressTime = 0
                isShiftCurrentlyPressed = false
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
        
        // Handle Command+Tab disabling if enabled
        if configManager.isCommandTabDisabled && eventType == .keyDown && keyCode == 48 && modifierFlags.contains(.command) { // Tab key (48) with Command
            logInfo("Command+Tab blocked to encourage pluck hotkey usage")
            return true // Consume the event to block Command+Tab
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
            logDebug("No character mapping found for keyCode: \(keyCode)")
            return false
        }
        
        // Find binding for this character
        if let binding = configManager.hotkeyBindings.first(where: { $0.selectorCharacter == character }) {
            logInfo("Hotkey detected for '\(character)'! Focusing \(binding.appName)...")
            focusApp(binding: binding)
            return true
        } else {
            logDebug("No binding found for character: '\(character)' (keyCode: \(keyCode))")
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
        
        // Fallback to name-based search with exact match priority
        if targetApps.isEmpty {
            // First try exact match
            targetApps = workspace.runningApplications.filter { app in
                app.localizedName?.lowercased() == binding.appName.lowercased()
            }
            
            // If no exact match, fallback to contains match
            if targetApps.isEmpty {
                targetApps = workspace.runningApplications.filter { app in
                    app.localizedName?.lowercased().contains(binding.appName.lowercased()) == true
                }
            }
        }
        
        logDebug("Found \(targetApps.count) matching apps for \(binding.appName)")
        
        if let targetApp = targetApps.first {
            logInfo("Activating \(binding.appName)...")
            
            // Use NSWorkspace to activate the running app directly
            let success = targetApp.activate(options: [.activateIgnoringOtherApps])
            if success {
                logInfo("Successfully activated \(binding.appName)")
            } else {
                logWarning("Failed to activate \(binding.appName), trying alternative approach...")
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
            logInfo("\(binding.appName) not running, trying to launch...")
            
            // Try to launch app if it's not running
            if let bundleId = binding.bundleIdentifier,
               let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                logDebug("Found \(binding.appName) at: \(appURL)")
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
            } else {
                // Fallback to name-based launch - try to find exact app name in Applications
                logDebug("Trying to launch by name: \(binding.appName)")
                let appSearchPaths = ["/Applications", "/System/Applications"]
                var foundApp = false
                
                for searchPath in appSearchPaths {
                    let exactAppPath = "\(searchPath)/\(binding.appName).app"
                    if FileManager.default.fileExists(atPath: exactAppPath) {
                        if let appURL = URL(string: "file://\(exactAppPath)") {
                            logDebug("Found exact app at: \(exactAppPath)")
                            let configuration = NSWorkspace.OpenConfiguration()
                            configuration.activates = true
                            workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
                            foundApp = true
                            break
                        }
                    }
                }
                
                if !foundApp {
                    // Final fallback to NSWorkspace.launchApplication
                    logDebug("Using NSWorkspace.launchApplication as final fallback")
                    workspace.launchApplication(binding.appName)
                }
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
        
        logDebug("Found Messages apps: \(messagesApps.map { $0.localizedName ?? "Unknown" })")
        
        if let messagesApp = messagesApps.first {
            logInfo("Activating Messages app...")
            
            // Use NSWorkspace to activate the running app directly
            let success = messagesApp.activate(options: [.activateIgnoringOtherApps])
            if success {
                logInfo("Successfully activated Messages")
            } else {
                logWarning("Failed to activate Messages, trying alternative approach...")
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
            logInfo("Messages not running, trying to launch...")
            // Try to launch Messages if it's not running
            if let messagesURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.MobileSMS") {
                logDebug("Found Messages at: \(messagesURL)")
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                workspace.openApplication(at: messagesURL, configuration: configuration) { _, _ in }
            } else {
                logError("Could not find Messages app")
            }
        }
    }
    
    deinit {
        logInfo("HotkeyManager deinit")
        unregisterHotkey()
    }
}