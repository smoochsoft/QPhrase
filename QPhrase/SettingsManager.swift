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
    @Published var showPreview: Bool {
        didSet { UserDefaults.standard.set(showPreview, forKey: "showPreview") }
    }
    @Published var showOverlayEffects: Bool {
        didSet { UserDefaults.standard.set(showOverlayEffects, forKey: "showOverlayEffects") }
    }

    // Custom models per provider (user-added)
    @Published var customModels: [String: [String]] = [:] {
        didSet { saveCustomModels() }
    }

    enum AIProvider: String, CaseIterable {
        case openai = "OpenAI"
        case anthropic = "Anthropic"
        case groq = "Groq"
        case gemini = "Gemini"

        var defaultModels: [String] {
            switch self {
            case .openai:
                return ["gpt-4.1-nano", "gpt-4.1-mini", "gpt-5-nano", "gpt-4.1", "gpt-5-mini"]
            case .anthropic:
                return ["claude-opus-4.5", "claude-sonnet-4.5", "claude-3.7-sonnet", "claude-3-5-haiku-20241022"]
            case .groq:
                return ["llama-3.3-70b-versatile", "llama-4-scout-17b", "gpt-oss-120b", "qwen-qwq-32b", "llama-3.1-8b-instant"]
            case .gemini:
                return ["gemini-flash-lite-latest", "gemini-flash-latest", "gemini-2.5-flash", "gemini-3-flash-preview", "gemini-3-pro-preview"]
            }
        }

        var theme: ProviderTheme {
            switch self {
            case .openai:
                return ProviderTheme(
                    icon: "sparkles.rectangle.stack",
                    logoImage: "OpenAILogo",
                    color: .blue,
                    displayName: "OpenAI"
                )
            case .anthropic:
                return ProviderTheme(
                    icon: "star.leadinghalf.filled",
                    logoImage: "ClaudeLogo",
                    color: Color(hex: "#C15F3C"),
                    displayName: "Claude"
                )
            case .gemini:
                return ProviderTheme(
                    icon: "star.circle.fill",
                    logoImage: "GeminiLogo",
                    color: Color(hex: "#4285F4"),
                    displayName: "Gemini"
                )
            case .groq:
                return ProviderTheme(
                    icon: "bolt.horizontal.fill",
                    logoImage: "GroqLogo",
                    color: Color(hex: "#F55036"),
                    displayName: "Groq"
                )
            }
        }
    }
    
    init() {
        self.openAIKey = ""
        self.anthropicKey = ""
        self.groqKey = ""
        self.geminiKey = ""
        self.selectedProvider = .openai
        self.selectedModel = "gpt-4.1-nano"
        self.showNotifications = true
        self.playSound = true
        self.showPreview = true
        self.showOverlayEffects = true

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
        showPreview = UserDefaults.standard.object(forKey: "showPreview") as? Bool ?? true
        showOverlayEffects = UserDefaults.standard.object(forKey: "showOverlayEffects") as? Bool ?? true

        loadCustomModels()
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

    // MARK: - Model Management

    /// Returns all models for a provider (default + custom)
    func modelsForProvider(_ provider: AIProvider) -> [String] {
        let custom = customModels[provider.rawValue] ?? []
        return provider.defaultModels + custom
    }

    /// Returns all models for the currently selected provider
    var currentProviderModels: [String] {
        modelsForProvider(selectedProvider)
    }

    /// Add a custom model for a provider
    func addCustomModel(_ model: String, for provider: AIProvider) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Don't add if it already exists
        let allModels = modelsForProvider(provider)
        guard !allModels.contains(trimmed) else { return }

        var models = customModels[provider.rawValue] ?? []
        models.append(trimmed)
        customModels[provider.rawValue] = models
    }

    /// Remove a custom model (cannot remove default models)
    func removeCustomModel(_ model: String, for provider: AIProvider) {
        guard var models = customModels[provider.rawValue] else { return }
        models.removeAll { $0 == model }
        customModels[provider.rawValue] = models

        // If selected model was removed, switch to first available
        if selectedModel == model {
            selectedModel = modelsForProvider(provider).first ?? ""
        }
    }

    /// Check if a model is a default (non-removable) model
    func isDefaultModel(_ model: String, for provider: AIProvider) -> Bool {
        provider.defaultModels.contains(model)
    }

    /// Returns a speed badge for the model (⚡ Fast, ✨ Balanced, 🧠 Quality)
    func modelBadge(for model: String) -> String {
        // Fast models (nano, lite variants)
        if model.contains("nano") || model.contains("lite") {
            return "⚡"
        }
        // Quality models (pro, full gpt-5-mini)
        if model.contains("pro") || model == "gpt-5-mini" {
            return "🧠"
        }
        // Fast (mini, flash variants)
        if model.contains("mini") || model.contains("flash") {
            return "⚡"
        }
        // Default for custom/unknown models
        return ""
    }

    /// Returns the model name with its speed badge
    func modelDisplayName(for model: String) -> String {
        let badge = modelBadge(for: model)
        return badge.isEmpty ? model : "\(badge) \(model)"
    }

    private func saveCustomModels() {
        if let data = try? JSONEncoder().encode(customModels) {
            UserDefaults.standard.set(data, forKey: "customModels")
        }
    }

    private func loadCustomModels() {
        if let data = UserDefaults.standard.data(forKey: "customModels"),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            customModels = decoded
        }
    }

    // MARK: - Keychain Helpers
    @discardableResult
    private func saveToKeychain(key: String, value: String) -> Bool {
        let service = "com.qphrase.api"

        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // If value is empty, we just wanted to delete - that's success
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return true }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status != errSecSuccess {
            NSLog("QPhrase: Failed to save API key to Keychain (status: \(status))")
        }
        return status == errSecSuccess
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let service = "com.qphrase.api"
        
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
