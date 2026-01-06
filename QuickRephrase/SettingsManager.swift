import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    @Published var openAIKey: String {
        didSet { saveToKeychain(key: "openai", value: openAIKey) }
    }
    @Published var anthropicKey: String {
        didSet { saveToKeychain(key: "anthropic", value: anthropicKey) }
    }
    @Published var groqKey: String {
        didSet { saveToKeychain(key: "groq", value: groqKey) }
    }
    @Published var geminiKey: String {
        didSet { saveToKeychain(key: "gemini", value: geminiKey) }
    }
    @Published var selectedProvider: AIProvider {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider") }
    }
    @Published var selectedModel: String {
        didSet { UserDefaults.standard.set(selectedModel, forKey: "selectedModel") }
    }
    @Published var showNotifications: Bool {
        didSet { UserDefaults.standard.set(showNotifications, forKey: "showNotifications") }
    }
    @Published var playSound: Bool {
        didSet { UserDefaults.standard.set(playSound, forKey: "playSound") }
    }
    
    enum AIProvider: String, CaseIterable {
        case openai = "OpenAI"
        case anthropic = "Anthropic"
        case groq = "Groq"
        case gemini = "Gemini"

        var models: [String] {
            switch self {
            case .openai:
                return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"]
            case .anthropic:
                return ["claude-sonnet-4-20250514", "claude-3-5-haiku-20241022", "claude-3-opus-20240229"]
            case .groq:
                return ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768", "gemma2-9b-it"]
            case .gemini:
                return ["gemini-2.0-flash-exp", "gemini-1.5-pro", "gemini-1.5-flash"]
            }
        }
    }
    
    init() {
        self.openAIKey = ""
        self.anthropicKey = ""
        self.groqKey = ""
        self.geminiKey = ""
        self.selectedProvider = .openai
        self.selectedModel = "gpt-4o-mini"
        self.showNotifications = true
        self.playSound = true

        loadSettings()
    }
    
    func loadSettings() {
        openAIKey = loadFromKeychain(key: "openai") ?? ""
        anthropicKey = loadFromKeychain(key: "anthropic") ?? ""
        groqKey = loadFromKeychain(key: "groq") ?? ""
        geminiKey = loadFromKeychain(key: "gemini") ?? ""

        if let providerRaw = UserDefaults.standard.string(forKey: "selectedProvider"),
           let provider = AIProvider(rawValue: providerRaw) {
            selectedProvider = provider
        }

        if let model = UserDefaults.standard.string(forKey: "selectedModel") {
            selectedModel = model
        }

        showNotifications = UserDefaults.standard.object(forKey: "showNotifications") as? Bool ?? true
        playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
    }

    var currentAPIKey: String {
        switch selectedProvider {
        case .openai: return openAIKey
        case .anthropic: return anthropicKey
        case .groq: return groqKey
        case .gemini: return geminiKey
        }
    }
    
    var isConfigured: Bool {
        return !currentAPIKey.isEmpty
    }
    
    // MARK: - Keychain Helpers
    private func saveToKeychain(key: String, value: String) {
        let service = "com.quickrephrase.api"
        let data = value.data(using: .utf8)!
        
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new
        if !value.isEmpty {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let service = "com.quickrephrase.api"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
