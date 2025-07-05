import SwiftUI

struct ConfigurationView: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var selectedKeyNumber = 1
    @State private var selectedAppName = ""
    @State private var showingAppPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Hotkey Configuration")
                .font(.title2)
                .bold()
            
            Text("Configure hotkeys to quickly open your favorite apps")
                .foregroundColor(.secondary)
            
            // Current bindings list
            GroupBox("Current Hotkeys") {
                if configManager.hotkeyBindings.isEmpty {
                    Text("No hotkeys configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(configManager.hotkeyBindings) { binding in
                            HStack {
                                Text(binding.displayText)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                
                                Text("→")
                                    .foregroundColor(.secondary)
                                
                                Text(binding.appName)
                                    .bold()
                                
                                Spacer()
                                
                                Button("Remove") {
                                    configManager.removeBinding(for: binding.keyNumber)
                                }
                                .foregroundColor(.red)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
            
            // Add new binding
            GroupBox("Add New Hotkey") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Key:")
                        Picker("Key Number", selection: $selectedKeyNumber) {
                            ForEach(configManager.getAvailableKeyNumbers(), id: \.self) { number in
                                Text("⌃⌥\(number)").tag(number)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .disabled(configManager.getAvailableKeyNumbers().isEmpty)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text("App:")
                        TextField("Application name", text: $selectedAppName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Choose App") {
                            showAppPicker()
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Button("Add Hotkey") {
                            if !selectedAppName.isEmpty {
                                configManager.addBinding(
                                    keyNumber: selectedKeyNumber,
                                    appName: selectedAppName
                                )
                                selectedAppName = ""
                                if let nextAvailable = configManager.getAvailableKeyNumbers().first {
                                    selectedKeyNumber = nextAvailable
                                }
                            }
                        }
                        .disabled(selectedAppName.isEmpty || configManager.getAvailableKeyNumbers().isEmpty)
                    }
                }
                .padding()
            }
            
            if configManager.getAvailableKeyNumbers().isEmpty {
                Text("All hotkey slots (1-9) are in use")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
        .onAppear {
            if let firstAvailable = configManager.getAvailableKeyNumbers().first {
                selectedKeyNumber = firstAvailable
            }
        }
    }
    
    private func showAppPicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedAppName = url.deletingPathExtension().lastPathComponent
        }
    }
}

#Preview {
    ConfigurationView(configManager: ConfigurationManager())
}