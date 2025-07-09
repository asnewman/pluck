import SwiftUI

struct ConfigurationView: View {
    @ObservedObject var configManager: ConfigurationManager
    @State private var selectedSelectorCharacter: Character = "a"
    @State private var selectorCharacterInput = ""
    @State private var selectedAppName = ""
    @State private var showingAppPicker = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case selectorCharacter
        case appName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pluck Configuration")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Link("Need help? Watch tutorial", destination: URL(string: "https://youtu.be/sDkCw4IEPYo")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Text("Configure your pluck key and hotkeys to quickly open apps")
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
            
            // Pluck Key Configuration
            GroupBox("Pluck Key Configuration") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose modifier keys for your pluck key:")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
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
                            .padding(.top, 4)
                    } else {
                        Text("Current pluck key: \(configManager.pluckKey.displayText)")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
            }
            
            // Current bindings list
            GroupBox("Current Hotkeys") {
                if configManager.hotkeyBindings.isEmpty {
                    Text("No hotkeys configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(configManager.hotkeyBindings) { binding in
                                HStack(spacing: 12) {
                                    Text(binding.displayText(with: configManager.pluckKey))
                                        .font(.system(.body, design: .monospaced))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
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
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding(12)
                    }
                    .frame(minHeight: 100, maxHeight: 180)
                }
            }
            
            // Add new binding
            GroupBox("Add New Hotkey") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selector Key:")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            TextField("Press any key (a-z, 0-9, etc.)", text: $selectorCharacterInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 200)
                                .focused($focusedField, equals: .selectorCharacter)
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
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App:")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            TextField("Application name", text: $selectedAppName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($focusedField, equals: .appName)
                            
                            Button("Choose App") {
                                showAppPicker()
                            }
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
                                focusedField = nil
                            }
                        }
                        .disabled(selectedAppName.isEmpty || 
                                selectorCharacterInput.isEmpty || 
                                configManager.pluckKey.isEmpty ||
                                !configManager.isCharacterAvailable(selectedSelectorCharacter))
                    }
                }
                .padding(16)
            }
            
            Spacer()
        }
        .padding(EdgeInsets(top: 32, leading: 20, bottom: 20, trailing: 20))
        .frame(width: 600, height: 620)
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