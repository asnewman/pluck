import Foundation
import Cocoa

struct PluckKeyConfiguration: Codable {
    var useCommand: Bool = false
    var useOption: Bool = true
    var useControl: Bool = true
    var useShift: Bool = false
    
    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if useCommand { flags.insert(.command) }
        if useOption { flags.insert(.option) }
        if useControl { flags.insert(.control) }
        if useShift { flags.insert(.shift) }
        return flags
    }
    
    var displayText: String {
        var parts: [String] = []
        if useControl { parts.append("⌃") }
        if useOption { parts.append("⌥") }
        if useShift { parts.append("⇧") }
        if useCommand { parts.append("⌘") }
        return parts.joined()
    }
    
    var isEmpty: Bool {
        return !useCommand && !useOption && !useControl && !useShift
    }
}

class KeyMapping {
    static let shared = KeyMapping()
    
    private let characterKeyMap: [Character: UInt16] = [
        // Letters
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4,
        "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45, "o": 31,
        "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9,
        "w": 13, "x": 7, "y": 16, "z": 6,
        
        // Numbers
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25,
        
        // Special characters
        "`": 50, "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42,
        ";": 41, "'": 39, ",": 43, ".": 47, "/": 44,
        
        // Space
        " ": 49
    ]
    
    private let keyCodeToCharacterMap: [UInt16: Character] = [
        // Letters
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g", 4: "h",
        34: "i", 38: "j", 40: "k", 37: "l", 46: "m", 45: "n", 31: "o",
        35: "p", 12: "q", 15: "r", 1: "s", 17: "t", 32: "u", 9: "v",
        13: "w", 7: "x", 16: "y", 6: "z",
        
        // Numbers
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9",
        
        // Special characters
        50: "`", 27: "-", 24: "=", 33: "[", 30: "]", 42: "\\",
        41: ";", 39: "'", 43: ",", 47: ".", 44: "/",
        
        // Space
        49: " "
    ]
    
    func keyCode(for character: Character) -> UInt16? {
        return characterKeyMap[character.lowercased().first ?? character]
    }
    
    func character(for keyCode: UInt16) -> Character? {
        return keyCodeToCharacterMap[keyCode]
    }
    
    func isValidSelectorCharacter(_ character: Character) -> Bool {
        return characterKeyMap[character.lowercased().first ?? character] != nil
    }
    
    func displayName(for character: Character) -> String {
        switch character {
        case " ": return "Space"
        case "`": return "Backtick"
        case "-": return "Minus"
        case "=": return "Equals"
        case "[": return "Left Bracket"
        case "]": return "Right Bracket"
        case "\\": return "Backslash"
        case ";": return "Semicolon"
        case "'": return "Quote"
        case ",": return "Comma"
        case ".": return "Period"
        case "/": return "Slash"
        default: return String(character).uppercased()
        }
    }
}