import Foundation
import Cocoa

struct HotkeyBinding: Codable, Identifiable {
    let id = UUID()
    private var _selectorCharacter: String
    var appName: String
    var bundleIdentifier: String?
    
    var selectorCharacter: Character {
        get { _selectorCharacter.first ?? "a" }
        set { _selectorCharacter = String(newValue) }
    }
    
    init(selectorCharacter: Character, appName: String, bundleIdentifier: String? = nil) {
        self._selectorCharacter = String(selectorCharacter)
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
    }
    
    var keyCode: UInt16? {
        return KeyMapping.shared.keyCode(for: selectorCharacter)
    }
    
    func displayText(with pluckKey: PluckKeyConfiguration) -> String {
        let selectorDisplay = KeyMapping.shared.displayName(for: selectorCharacter)
        return "\(pluckKey.displayText)+\(selectorDisplay)"
    }
}

class ConfigurationManager: ObservableObject {
    @Published var hotkeyBindings: [HotkeyBinding] = []
    @Published var pluckKey = PluckKeyConfiguration()
    @Published var isDoubleShiftEnabled = false
    @Published var isCommandTabDisabled = false
    
    private let userDefaults = UserDefaults.standard
    private let bindingsKey = "HotkeyBindings"
    private let pluckKeyKey = "PluckKeyConfiguration"
    private let doubleShiftKey = "DoubleShiftEnabled"
    private let commandTabDisabledKey = "CommandTabDisabled"
    
    init() {
        loadConfiguration()
        
        // Set default binding for Messages if no bindings exist
        if hotkeyBindings.isEmpty {
            hotkeyBindings = [
                HotkeyBinding(selectorCharacter: Character("m"), appName: "Messages", bundleIdentifier: "com.apple.MobileSMS")
            ]
            saveConfiguration()
        }
    }
    
    func addBinding(selectorCharacter: Character, appName: String, bundleIdentifier: String? = nil) {
        // Remove existing binding for this selector character
        hotkeyBindings.removeAll { $0.selectorCharacter == selectorCharacter }
        
        // Add new binding
        let newBinding = HotkeyBinding(selectorCharacter: selectorCharacter, appName: appName, bundleIdentifier: bundleIdentifier)
        hotkeyBindings.append(newBinding)
        hotkeyBindings.sort { $0.selectorCharacter < $1.selectorCharacter }
        
        saveConfiguration()
    }
    
    func removeBinding(for selectorCharacter: Character) {
        hotkeyBindings.removeAll { $0.selectorCharacter == selectorCharacter }
        saveConfiguration()
    }
    
    func getBinding(for selectorCharacter: Character) -> HotkeyBinding? {
        return hotkeyBindings.first { $0.selectorCharacter == selectorCharacter }
    }
    
    func updatePluckKey(_ newPluckKey: PluckKeyConfiguration) {
        pluckKey = newPluckKey
        saveConfiguration()
    }
    
    func updateDoubleShiftEnabled(_ enabled: Bool) {
        isDoubleShiftEnabled = enabled
        saveConfiguration()
    }
    
    func updateCommandTabDisabled(_ disabled: Bool) {
        isCommandTabDisabled = disabled
        saveConfiguration()
    }
    
    private func saveConfiguration() {
        // Save hotkey bindings
        if let encoded = try? JSONEncoder().encode(hotkeyBindings) {
            userDefaults.set(encoded, forKey: bindingsKey)
        }
        
        // Save pluck key configuration
        if let encoded = try? JSONEncoder().encode(pluckKey) {
            userDefaults.set(encoded, forKey: pluckKeyKey)
        }
        
        // Save double-shift setting
        userDefaults.set(isDoubleShiftEnabled, forKey: doubleShiftKey)
        
        // Save command+tab disabled setting
        userDefaults.set(isCommandTabDisabled, forKey: commandTabDisabledKey)
    }
    
    private func loadConfiguration() {
        // Load hotkey bindings
        if let data = userDefaults.data(forKey: bindingsKey),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            hotkeyBindings = decoded
        }
        
        // Load pluck key configuration
        if let data = userDefaults.data(forKey: pluckKeyKey),
           let decoded = try? JSONDecoder().decode(PluckKeyConfiguration.self, from: data) {
            pluckKey = decoded
        }
        
        // Load double-shift setting
        isDoubleShiftEnabled = userDefaults.bool(forKey: doubleShiftKey)
        
        // Load command+tab disabled setting
        isCommandTabDisabled = userDefaults.bool(forKey: commandTabDisabledKey)
    }
    
    func isCharacterAvailable(_ character: Character) -> Bool {
        return !hotkeyBindings.contains { $0.selectorCharacter == character }
    }
}