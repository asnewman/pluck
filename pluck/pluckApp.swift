//
//  pluckApp.swift
//  pluck
//
//  Created by Ashley Newman on 7/4/25.
//

import SwiftUI

@main
struct pluckApp: App {
    @StateObject private var hotkeyManager: HotkeyManager
    @StateObject private var configManager = ConfigurationManager()
    @State private var configWindowController: NSWindowController?
    
    init() {
        logInfo("Pluck app initializing")
        let manager = HotkeyManager()
        let config = ConfigurationManager()
        
        self._hotkeyManager = StateObject(wrappedValue: manager)
        self._configManager = StateObject(wrappedValue: config)
        
        // Register hotkey when app starts
        DispatchQueue.main.async {
            manager.setConfigurationManager(config)
            manager.registerHotkey()
        }
    }
    
    var body: some Scene {
        MenuBarExtra("Pluck", image: "MenuBarIcon") {
            Button(action: {
                showConfigurationWindow()
            }) {
                Label("Configure", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            Button(action: {
                if let url = URL(string: "https://github.com/asnewman/pluck") {
                    NSWorkspace.shared.open(url)
                }
            }) {
                Label("Report Bug", systemImage: "ladybug")
            }
            
            Button(action: {
                exportLogs()
            }) {
                Label("Export Logs", systemImage: "doc.on.doc")
            }
            
            Divider()
            
            Button(action: {
                logInfo("User quit app from menu")
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit Pluck", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
    }
    
    private func showConfigurationWindow() {
        logInfo("Opening configuration window")
        // Close existing window if open
        configWindowController?.close()
        
        // Create new configuration window
        let configView = ConfigurationView(configManager: configManager)
        let hostingController = NSHostingController(rootView: configView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 580),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Pluck Configuration"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("ConfigurationWindow")
        
        configWindowController = NSWindowController(window: window)
        configWindowController?.showWindow(nil)
        
        // Bring window to front
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    private func exportLogs() {
        logInfo("User requested log export")
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let zipFileURL = Logger.shared.exportLogs() else {
                DispatchQueue.main.async {
                    self.showExportError()
                }
                return
            }
            
            DispatchQueue.main.async {
                let savePanel = NSSavePanel()
                savePanel.title = "Export Pluck Logs"
                savePanel.nameFieldStringValue = zipFileURL.lastPathComponent
                savePanel.allowedContentTypes = [.zip]
                savePanel.canCreateDirectories = true
                
                let response = savePanel.runModal()
                if response == .OK {
                    if let destinationURL = savePanel.url {
                        do {
                            // Remove file if it exists
                            if FileManager.default.fileExists(atPath: destinationURL.path) {
                                try FileManager.default.removeItem(at: destinationURL)
                            }
                            try FileManager.default.moveItem(at: zipFileURL, to: destinationURL)
                            logInfo("Logs exported to: \(destinationURL.path)")
                            self.showExportSuccess(at: destinationURL)
                        } catch {
                            logError("Failed to save exported logs: \(error)")
                            self.showExportError()
                        }
                    }
                } else {
                    // Clean up temp file if user cancelled
                    try? FileManager.default.removeItem(at: zipFileURL)
                }
            }
        }
    }
    
    private func showExportSuccess(at url: URL) {
        let alert = NSAlert()
        alert.messageText = "Logs Exported Successfully"
        alert.informativeText = "Your Pluck logs have been exported to:\n\(url.path)\n\nYou can now send this file to the developer for debugging."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "OK")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }
    
    private func showExportError() {
        let alert = NSAlert()
        alert.messageText = "Export Failed"
        alert.informativeText = "Unable to export logs. Please try again or contact support."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
