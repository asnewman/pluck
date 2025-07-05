import Cocoa
import SwiftUI
import ApplicationServices

class HotkeyManager: ObservableObject {
    private var eventMonitor: Any?
    private var configManager: ConfigurationManager?
    
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
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
            print("Key event: keyCode=\(event.keyCode), modifiers=\(event.modifierFlags)")
            if let configManager = self.configManager,
               !configManager.pluckKey.isEmpty,
               event.modifierFlags.contains(configManager.pluckKey.modifierFlags) {
                self.handleHotkeyEvent(keyCode: event.keyCode)
            }
        }
        
        if let configManager = configManager {
            print("Hotkey monitoring registered for \(configManager.pluckKey.displayText)+[character keys]")
        } else {
            print("Hotkey monitoring registered (no configuration manager)")
        }
    }
    
    func unregisterHotkey() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
    
    private func handleHotkeyEvent(keyCode: UInt16) {
        guard let configManager = configManager else {
            print("No configuration manager available")
            return
        }
        
        // Find the character for this key code
        guard let character = KeyMapping.shared.character(for: keyCode) else {
            print("No character mapping found for keyCode: \(keyCode)")
            return
        }
        
        // Find binding for this character
        if let binding = configManager.hotkeyBindings.first(where: { $0.selectorCharacter == character }) {
            print("Hotkey detected for \(binding.displayText(with: configManager.pluckKey))! Focusing \(binding.appName)...")
            focusApp(binding: binding)
        } else {
            print("No binding found for character: '\(character)' (keyCode: \(keyCode))")
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
            
            // Use AppleScript to reliably bring app to front
            let script = """
                tell application "\(binding.appName)"
                    activate
                end tell
            """
            
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                let result = appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("AppleScript error: \(error)")
                    // Fallback: try using NSWorkspace
                    print("Trying NSWorkspace fallback...")
                    NSWorkspace.shared.launchApplication(binding.appName)
                } else {
                    print("AppleScript executed successfully for \(binding.appName)")
                }
            }
        } else {
            print("\(binding.appName) not running, trying to launch...")
            
            // Try to launch app if it's not running
            if let bundleId = binding.bundleIdentifier,
               let appURL = workspace.urlForApplication(withBundleIdentifier: bundleId) {
                print("Found \(binding.appName) at: \(appURL)")
                let configuration = NSWorkspace.OpenConfiguration()
                workspace.openApplication(at: appURL, configuration: configuration) { _, _ in }
            } else {
                // Fallback to name-based launch
                print("Trying to launch by name: \(binding.appName)")
                NSWorkspace.shared.launchApplication(binding.appName)
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
            
            // Use AppleScript to reliably bring Messages to front
            let script = """
                tell application "Messages"
                    activate
                end tell
            """
            
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                let result = appleScript.executeAndReturnError(&error)
                if let error = error {
                    print("AppleScript error: \(error)")
                    // Fallback: try using NSWorkspace
                    print("Trying NSWorkspace fallback...")
                    NSWorkspace.shared.launchApplication("Messages")
                } else {
                    print("AppleScript executed successfully")
                }
            }
        } else {
            print("Messages not running, trying to launch...")
            // Try to launch Messages if it's not running
            if let messagesURL = workspace.urlForApplication(withBundleIdentifier: "com.apple.MobileSMS") {
                print("Found Messages at: \(messagesURL)")
                let configuration = NSWorkspace.OpenConfiguration()
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