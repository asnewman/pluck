import Foundation
import Cocoa

struct HotkeyBinding: Codable, Identifiable {
    let id = UUID()
    var keyNumber: Int // 1-9
    var appName: String
    var bundleIdentifier: String?
    
    var keyCode: UInt16 {
        // Map 1-9 to their respective key codes
        switch keyNumber {
        case 1: return 18  // kVK_ANSI_1
        case 2: return 19  // kVK_ANSI_2
        case 3: return 20  // kVK_ANSI_3
        case 4: return 21  // kVK_ANSI_4
        case 5: return 23  // kVK_ANSI_5
        case 6: return 22  // kVK_ANSI_6
        case 7: return 26  // kVK_ANSI_7
        case 8: return 28  // kVK_ANSI_8
        case 9: return 25  // kVK_ANSI_9
        default: return 18
        }
    }
    
    var displayText: String {
        "⌃⌥\(keyNumber)"
    }
}

class ConfigurationManager: ObservableObject {
    @Published var hotkeyBindings: [HotkeyBinding] = []
    
    private let userDefaults = UserDefaults.standard
    private let bindingsKey = "HotkeyBindings"
    
    init() {
        loadBindings()
        
        // Set default binding for Messages if no bindings exist
        if hotkeyBindings.isEmpty {
            hotkeyBindings = [
                HotkeyBinding(keyNumber: 1, appName: "Messages", bundleIdentifier: "com.apple.MobileSMS")
            ]
            saveBindings()
        }
    }
    
    func addBinding(keyNumber: Int, appName: String, bundleIdentifier: String? = nil) {
        // Remove existing binding for this key number
        hotkeyBindings.removeAll { $0.keyNumber == keyNumber }
        
        // Add new binding
        let newBinding = HotkeyBinding(keyNumber: keyNumber, appName: appName, bundleIdentifier: bundleIdentifier)
        hotkeyBindings.append(newBinding)
        hotkeyBindings.sort { $0.keyNumber < $1.keyNumber }
        
        saveBindings()
    }
    
    func removeBinding(for keyNumber: Int) {
        hotkeyBindings.removeAll { $0.keyNumber == keyNumber }
        saveBindings()
    }
    
    func getBinding(for keyNumber: Int) -> HotkeyBinding? {
        return hotkeyBindings.first { $0.keyNumber == keyNumber }
    }
    
    private func saveBindings() {
        if let encoded = try? JSONEncoder().encode(hotkeyBindings) {
            userDefaults.set(encoded, forKey: bindingsKey)
        }
    }
    
    private func loadBindings() {
        if let data = userDefaults.data(forKey: bindingsKey),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            hotkeyBindings = decoded
        }
    }
    
    func getAvailableKeyNumbers() -> [Int] {
        let usedNumbers = Set(hotkeyBindings.map { $0.keyNumber })
        return Array(1...9).filter { !usedNumbers.contains($0) }
    }
}