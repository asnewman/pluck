import Cocoa
import SwiftUI
import ApplicationServices

class HotkeyManager: ObservableObject {
    private var eventMonitor: Any?
    
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
            if event.modifierFlags.contains([.command, .option]) && event.keyCode == 18 { // keyCode 18 = '1'
                print("Hotkey detected! Focusing Messages...")
                self.focusMessages()
            }
        }
        print("Hotkey registered for Command+Option+1")
    }
    
    func unregisterHotkey() {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
    
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