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
        logInfo("ConfigurationManager initializing")
        loadConfiguration()
        
        // Set default binding for Messages if no bindings exist
        if hotkeyBindings.isEmpty {
            logInfo("No bindings found, creating default Messages binding")
            hotkeyBindings = [
                HotkeyBinding(selectorCharacter: Character("m"), appName: "Messages", bundleIdentifier: "com.apple.MobileSMS")
            ]
            saveConfiguration()
        } else {
            logInfo("Loaded \(hotkeyBindings.count) hotkey bindings")
        }
    }
    
    func addBinding(selectorCharacter: Character, appName: String, bundleIdentifier: String? = nil) {
        logInfo("Adding binding: '\(selectorCharacter)' -> \(appName)")
        // Remove existing binding for this selector character
        hotkeyBindings.removeAll { $0.selectorCharacter == selectorCharacter }
        
        // Add new binding
        let newBinding = HotkeyBinding(selectorCharacter: selectorCharacter, appName: appName, bundleIdentifier: bundleIdentifier)
        hotkeyBindings.append(newBinding)
        hotkeyBindings.sort { $0.selectorCharacter < $1.selectorCharacter }
        
        saveConfiguration()
    }
    
    func removeBinding(for selectorCharacter: Character) {
        logInfo("Removing binding for character: '\(selectorCharacter)'")
        hotkeyBindings.removeAll { $0.selectorCharacter == selectorCharacter }
        saveConfiguration()
    }
    
    func getBinding(for selectorCharacter: Character) -> HotkeyBinding? {
        return hotkeyBindings.first { $0.selectorCharacter == selectorCharacter }
    }
    
    func updatePluckKey(_ newPluckKey: PluckKeyConfiguration) {
        logInfo("Updating pluck key to: \(newPluckKey.displayText)")
        pluckKey = newPluckKey
        saveConfiguration()
    }
    
    func updateDoubleShiftEnabled(_ enabled: Bool) {
        logInfo("Double-shift enabled: \(enabled)")
        isDoubleShiftEnabled = enabled
        saveConfiguration()
    }
    
    func updateCommandTabDisabled(_ disabled: Bool) {
        logInfo("Command+Tab disabled: \(disabled)")
        isCommandTabDisabled = disabled
        saveConfiguration()
    }
    
    private func saveConfiguration() {
        logDebug("Saving configuration")
        // Save hotkey bindings
        do {
            let encoded = try JSONEncoder().encode(hotkeyBindings)
            userDefaults.set(encoded, forKey: bindingsKey)
        } catch {
            logError("Failed to encode hotkey bindings: \(error)")
        }
        
        // Save pluck key configuration
        do {
            let encoded = try JSONEncoder().encode(pluckKey)
            userDefaults.set(encoded, forKey: pluckKeyKey)
        } catch {
            logError("Failed to encode pluck key configuration: \(error)")
        }
        
        // Save double-shift setting
        userDefaults.set(isDoubleShiftEnabled, forKey: doubleShiftKey)
        
        // Save command+tab disabled setting
        userDefaults.set(isCommandTabDisabled, forKey: commandTabDisabledKey)
    }
    
    private func loadConfiguration() {
        logDebug("Loading configuration")
        // Load hotkey bindings
        if let data = userDefaults.data(forKey: bindingsKey) {
            do {
                let decoded = try JSONDecoder().decode([HotkeyBinding].self, from: data)
                hotkeyBindings = decoded
                logDebug("Loaded \(hotkeyBindings.count) hotkey bindings from storage")
            } catch {
                logError("Failed to decode hotkey bindings: \(error)")
            }
        }
        
        // Load pluck key configuration
        if let data = userDefaults.data(forKey: pluckKeyKey) {
            do {
                let decoded = try JSONDecoder().decode(PluckKeyConfiguration.self, from: data)
                pluckKey = decoded
                logDebug("Loaded pluck key configuration: \(pluckKey.displayText)")
            } catch {
                logError("Failed to decode pluck key configuration: \(error)")
            }
        }
        
        // Load double-shift setting
        isDoubleShiftEnabled = userDefaults.bool(forKey: doubleShiftKey)
        logDebug("Double-shift enabled: \(isDoubleShiftEnabled)")
        
        // Load command+tab disabled setting
        isCommandTabDisabled = userDefaults.bool(forKey: commandTabDisabledKey)
        logDebug("Command+Tab disabled: \(isCommandTabDisabled)")
    }
    
    func isCharacterAvailable(_ character: Character) -> Bool {
        return !hotkeyBindings.contains { $0.selectorCharacter == character }
    }
}