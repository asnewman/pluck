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
    
    init() {
        let manager = HotkeyManager()
        self._hotkeyManager = StateObject(wrappedValue: manager)
        
        // Register hotkey when app starts
        DispatchQueue.main.async {
            manager.registerHotkey()
        }
    }
    
    var body: some Scene {
        MenuBarExtra("Pluck", systemImage: "keyboard") {
            Button(action: {
                // TODO: Add configuration functionality
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
}
