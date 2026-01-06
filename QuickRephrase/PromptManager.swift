import Foundation
import SwiftUI
import Carbon

// MARK: - Prompt Model
struct Prompt: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var instruction: String
    var hotkey: HotkeyConfig?
    var isEnabled: Bool
    
    init(id: UUID = UUID(), name: String, instruction: String, hotkey: HotkeyConfig? = nil, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.instruction = instruction
        self.hotkey = hotkey
        self.isEnabled = isEnabled
    }
}

// MARK: - Hotkey Configuration
struct HotkeyConfig: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32
    
    var displayString: String {
        var parts: [String] = []
        
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        
        if let char = keyCodeToString(keyCode) {
            parts.append(char)
        }
        
        return parts.joined()
    }
    
    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        let keyCodeMap: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`",
            36: "↩", 48: "⇥", 51: "⌫", 53: "⎋",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return keyCodeMap[keyCode]
    }
}

// MARK: - Prompt Manager
class PromptManager: ObservableObject {
    @Published var prompts: [Prompt] = []
    
    private let saveKey = "QuickRephrase.Prompts"
    
    init() {
        loadPrompts()
        if prompts.isEmpty {
            loadDefaultPrompts()
        }
    }
    
    func loadDefaultPrompts() {
        prompts = [
            Prompt(
                name: "Fix Grammar",
                instruction: "Fix any grammar, spelling, and punctuation errors in the following text. Keep the same tone and meaning. Only output the corrected text, nothing else.",
                hotkey: HotkeyConfig(keyCode: 5, modifiers: UInt32(cmdKey | shiftKey)) // ⌘⇧G
            ),
            Prompt(
                name: "Make Professional",
                instruction: "Rewrite the following text to sound more professional and polished. Keep the same meaning. Only output the rewritten text, nothing else.",
                hotkey: HotkeyConfig(keyCode: 35, modifiers: UInt32(cmdKey | shiftKey)) // ⌘⇧P
            ),
            Prompt(
                name: "Make Concise",
                instruction: "Rewrite the following text to be more concise while keeping the key points. Only output the rewritten text, nothing else.",
                hotkey: HotkeyConfig(keyCode: 8, modifiers: UInt32(cmdKey | shiftKey)) // ⌘⇧C
            ),
            Prompt(
                name: "Make Friendly",
                instruction: "Rewrite the following text to sound friendlier and more casual. Only output the rewritten text, nothing else.",
                hotkey: HotkeyConfig(keyCode: 3, modifiers: UInt32(cmdKey | shiftKey)) // ⌘⇧F
            ),
            Prompt(
                name: "Expand",
                instruction: "Expand the following text with more detail and explanation while keeping the same meaning and tone. Only output the expanded text, nothing else.",
                hotkey: HotkeyConfig(keyCode: 14, modifiers: UInt32(cmdKey | shiftKey)) // ⌘⇧E
            )
        ]
        savePrompts()
    }
    
    func addPrompt(_ prompt: Prompt) {
        prompts.append(prompt)
        savePrompts()
    }
    
    func updatePrompt(_ prompt: Prompt) {
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            prompts[index] = prompt
            savePrompts()
        }
    }
    
    func deletePrompt(_ prompt: Prompt) {
        prompts.removeAll { $0.id == prompt.id }
        savePrompts()
    }
    
    func savePrompts() {
        if let encoded = try? JSONEncoder().encode(prompts) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    func loadPrompts() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Prompt].self, from: data) {
            prompts = decoded
        }
    }
}
