//
//  pluckApp.swift
//  pluck
//
//  Created by Ashley Newman on 7/4/25.
//

import SwiftUI

@main
struct pluckApp: App {
    @StateObject private var hotkeyManager = HotkeyManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    hotkeyManager.registerHotkey()
                }
        }
    }
}
