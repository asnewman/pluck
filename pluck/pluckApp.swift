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
            
            Divider()
            
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit Pluck", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)
    }
    
    private func showConfigurationWindow() {
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
}
