import SwiftUI

struct ConfigurationView: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var selectedSelectorCharacter: Character = "a"
    @State private var selectorCharacterInput = ""
    @State private var selectedAppName = ""
    @State private var showingAppPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pluck Configuration")
                .font(.title2)
                .bold()
            
            Text("Configure your pluck key and hotkeys to quickly open apps")
                .foregroundColor(.secondary)
            
            // Pluck Key Configuration
            GroupBox("Pluck Key Configuration") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose modifier keys for your pluck key:")
                        .font(.headline)
                    
                    HStack(spacing: 20) {
                        Toggle("⌃ Control", isOn: Binding(
                            get: { configManager.pluckKey.useControl },
                            set: { newValue in
                                var newPluckKey = configManager.pluckKey
                                newPluckKey.useControl = newValue
                                configManager.updatePluckKey(newPluckKey)
                            }
                        ))
                        
                        Toggle("⌥ Option", isOn: Binding(
                            get: { configManager.pluckKey.useOption },
                            set: { newValue in
                                var newPluckKey = configManager.pluckKey
                                newPluckKey.useOption = newValue
                                configManager.updatePluckKey(newPluckKey)
                            }
                        ))
                        
                        Toggle("⇧ Shift", isOn: Binding(
                            get: { configManager.pluckKey.useShift },
                            set: { newValue in
                                var newPluckKey = configManager.pluckKey
                                newPluckKey.useShift = newValue
                                configManager.updatePluckKey(newPluckKey)
                            }
                        ))
                        
                        Toggle("⌘ Command", isOn: Binding(
                            get: { configManager.pluckKey.useCommand },
                            set: { newValue in
                                var newPluckKey = configManager.pluckKey
                                newPluckKey.useCommand = newValue
                                configManager.updatePluckKey(newPluckKey)
                            }
                        ))
                    }
                    
                    if configManager.pluckKey.isEmpty {
                        Text("Please select at least one modifier key")
                            .foregroundColor(.red)
                            .font(.caption)
                    } else {
                        Text("Current pluck key: \(configManager.pluckKey.displayText)")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .padding()
            }
            
            // Current bindings list
            GroupBox("Current Hotkeys") {
                if configManager.hotkeyBindings.isEmpty {
                    Text("No hotkeys configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(configManager.hotkeyBindings) { binding in
                                HStack {
                                    Text(binding.displayText(with: configManager.pluckKey))
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
                                        configManager.removeBinding(for: binding.selectorCharacter)
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
                    .frame(minHeight: 100, maxHeight: 200)
                }
            }
            
            // Add new binding
            GroupBox("Add New Hotkey") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Selector Key:")
                        TextField("Press any key (a-z, 0-9, etc.)", text: $selectorCharacterInput)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                            .onChange(of: selectorCharacterInput) { newValue in
                                if let firstChar = newValue.lowercased().first,
                                   KeyMapping.shared.isValidSelectorCharacter(firstChar) {
                                    selectedSelectorCharacter = firstChar
                                    selectorCharacterInput = String(firstChar)
                                } else if newValue.count > 1 {
                                    selectorCharacterInput = String(selectorCharacterInput.prefix(1))
                                }
                            }
                        
                        if !selectorCharacterInput.isEmpty {
                            Text("Preview: \(configManager.pluckKey.displayText)+\(KeyMapping.shared.displayName(for: selectedSelectorCharacter))")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.blue)
                        }
                        
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
                        if !selectorCharacterInput.isEmpty && !configManager.isCharacterAvailable(selectedSelectorCharacter) {
                            Text("Key '\(selectedSelectorCharacter)' is already in use")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Button("Add Hotkey") {
                            if !selectedAppName.isEmpty && !selectorCharacterInput.isEmpty {
                                configManager.addBinding(
                                    selectorCharacter: selectedSelectorCharacter,
                                    appName: selectedAppName
                                )
                                selectedAppName = ""
                                selectorCharacterInput = ""
                            }
                        }
                        .disabled(selectedAppName.isEmpty || 
                                selectorCharacterInput.isEmpty || 
                                configManager.pluckKey.isEmpty ||
                                !configManager.isCharacterAvailable(selectedSelectorCharacter))
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 600, height: 550)
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