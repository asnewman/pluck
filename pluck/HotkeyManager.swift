import Cocoa
import SwiftUI
import ApplicationServices

class HotkeyManager: ObservableObject {
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var configManager: ConfigurationManager?
    
    // Double-shift detection properties
    private var lastShiftPressTime: CFTimeInterval = 0
    private var isWaitingForSelector = false
    private let doubleShiftThreshold: CFTimeInterval = 0.5 // 500ms window for double-shift
    
    func setConfigurationManager(_ configManager: ConfigurationManager) {
        self.configManager = configManager
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
        
        // Global monitor for when other apps are focused
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            print("Global key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags), type=\(event.type.rawValue)")
            self.handleKeyEvent(event: event)
        }
        
        // Local monitor for when our own app is focused
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
        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
        
        if let localEventMonitor = localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }
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
        if configManager.isDoubleShiftEnabled && eventType == .flagsChanged && modifierFlags.contains(.shift) && (keyCode == 56 || keyCode == 60) {
            if currentTime - lastShiftPressTime <= doubleShiftThreshold {
                // Double-shift detected
                print("Double-shift detected! Waiting for selector key...")
                isWaitingForSelector = true
                lastShiftPressTime = 0 // Reset to prevent triple-shift issues
                return true
            } else {
                lastShiftPressTime = currentTime
                return false
            }
        }
        
        // Handle selector key after double-shift (only for keyDown events)
        if isWaitingForSelector && eventType == .keyDown {
            isWaitingForSelector = false
            return handleSelectorKey(keyCode: keyCode)
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