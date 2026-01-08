import SwiftUI
import Carbon
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var promptManager: PromptManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // App Logo Header
            HStack(spacing: 12) {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("QPhrase")
                        .font(.title2.weight(.semibold))
                    Text("AI-Powered Text Transformation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            TabView(selection: $selectedTab) {
                GeneralSettingsView()
                    .tabItem {
                        Label("Preferences", systemImage: "gear")
                    }
                    .tag(0)

                APISettingsView()
                    .tabItem {
                        Label("Providers", systemImage: "network")
                    }
                    .tag(1)

                PromptsSettingsView()
                    .tabItem {
                        Label("Prompts", systemImage: "text.bubble")
                    }
                    .tag(2)
            }

            Divider()

            HStack {
                Button("") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()

                Spacer()

                Button("Done") {
                    NSApplication.shared.keyWindow?.close()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding()
        }
        .frame(minWidth: 550, idealWidth: 700, minHeight: 450, idealHeight: 580)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var formID = UUID()

    var body: some View {
        Form {
            Section {
                Toggle("Show notifications", isOn: $settingsManager.showNotifications)
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                Toggle("Play sounds", isOn: $settingsManager.playSound)
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                Toggle("Show overlay effects", isOn: $settingsManager.showOverlayEffects)
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                Toggle("Preview transformations", isOn: $settingsManager.showPreview)
                    .toggleStyle(.switch)
                    .controlSize(.regular)
            } header: {
                Text("Feedback")
            } footer: {
                Text("Preview lets you review and edit AI transformations before applying them. Overlay effects show sparkle animations near your cursor when transformations are active.")
                    .foregroundColor(.secondary)
            }

            Section {
                LaunchAtLoginToggle()
            } header: {
                Text("Startup")
            } footer: {
                Text("Automatically start QPhrase when you log in.")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .id(formID)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                formID = UUID()
            }
        }
    }
}

struct LaunchAtLoginToggle: View {
    @State private var launchAtLogin = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .controlSize(.regular)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(enabled: newValue)
                }
                .onAppear {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Failed: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// MARK: - Provider Tile Component
struct ProviderTile: View {
    let provider: SettingsManager.AIProvider
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(provider.theme.logoImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)

            Text(provider.theme.displayName)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? provider.theme.color.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? provider.theme.color : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
        )
        .contentShape(Rectangle())  // Make entire area clickable
        .onTapGesture {
            action()
        }
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Select \(provider.theme.displayName)")
    }
}

// MARK: - API Settings
struct APISettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showAPIKey = false
    @State private var isTestingConnection = false
    @State private var connectionTestResult: (success: Bool, message: String)?

    private var currentKeyBinding: Binding<String> {
        switch settingsManager.selectedProvider {
        case .openai:
            return $settingsManager.openAIKey
        case .anthropic:
            return $settingsManager.anthropicKey
        case .groq:
            return $settingsManager.groqKey
        case .gemini:
            return $settingsManager.geminiKey
        }
    }

    private var apiKeyLink: String {
        switch settingsManager.selectedProvider {
        case .openai:
            return "https://platform.openai.com/api-keys"
        case .anthropic:
            return "https://console.anthropic.com/settings/keys"
        case .groq:
            return "https://console.groq.com/keys"
        case .gemini:
            return "https://aistudio.google.com/apikey"
        }
    }

    var body: some View {
        Form {
            Section {
                // Provider tiles
                HStack(spacing: 12) {
                    ForEach(SettingsManager.AIProvider.allCases, id: \.self) { provider in
                        ProviderTile(
                            provider: provider,
                            isSelected: settingsManager.selectedProvider == provider,
                            action: {
                                settingsManager.selectedProvider = provider
                            }
                        )
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Select Provider")
            }

            Section {
                Picker("Model", selection: $settingsManager.selectedModel) {
                    ForEach(settingsManager.currentProviderModels, id: \.self) { model in
                        Text(settingsManager.modelDisplayName(for: model)).tag(model)
                    }
                }
                .onChange(of: settingsManager.selectedProvider) { _ in
                    DispatchQueue.main.async {
                        settingsManager.selectedModel = settingsManager.currentProviderModels.first ?? ""
                        showAPIKey = false
                    }
                }

                // Model management
                ModelManagementView()

                HStack(spacing: 12) {
                    if showAPIKey {
                        TextField("API Key", text: currentKeyBinding)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("API Key", text: currentKeyBinding)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: { showAPIKey.toggle() }) {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                            .frame(width: 20)
                    }
                    .buttonStyle(.plain)

                    if !currentKeyBinding.wrappedValue.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                // Test connection button
                HStack {
                    Button(action: { Task { await testConnection() } }) {
                        HStack(spacing: 6) {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "network")
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(currentKeyBinding.wrappedValue.isEmpty || isTestingConnection)
                    .buttonStyle(.bordered)

                    if let testResult = connectionTestResult {
                        Label(testResult.message, systemImage: testResult.success ? "checkmark.circle" : "xmark.circle")
                            .font(.caption)
                            .foregroundColor(testResult.success ? .green : .red)
                    }
                }

                Link("Get \(settingsManager.selectedProvider.rawValue) API Key →", destination: URL(string: apiKeyLink)!)
                    .font(.callout)
            } header: {
                HStack(spacing: 8) {
                    Image(systemName: settingsManager.selectedProvider.theme.icon)
                        .foregroundColor(settingsManager.selectedProvider.theme.color)
                    Text("\(settingsManager.selectedProvider.theme.displayName) Configuration")
                }
            } footer: {
                Text("Your API key is stored securely in the macOS Keychain.")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func testConnection() async {
        isTestingConnection = true
        connectionTestResult = nil

        do {
            // Create a temporary test prompt
            let testPrompt = Prompt(
                name: "Test",
                instruction: "Say 'OK' if you can read this",
                icon: "checkmark.circle"
            )
            let _ = try await AIService.shared.transform(
                text: "test",
                prompt: testPrompt,
                settings: settingsManager
            )
            connectionTestResult = (success: true, message: "Connection successful")
        } catch {
            connectionTestResult = (success: false, message: "Connection failed: \(error.localizedDescription)")
        }

        isTestingConnection = false
    }
}

// MARK: - Model Management
struct ModelManagementView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var newModelName: String = ""
    @State private var isExpanded: Bool = false

    var body: some View {
        DisclosureGroup("Manage Models", isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                // Add new model
                HStack(spacing: 8) {
                    TextField("Add custom model...", text: $newModelName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            addModel()
                        }

                    Button(action: addModel) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newModelName.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Model list
                if !settingsManager.currentProviderModels.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(settingsManager.currentProviderModels, id: \.self) { model in
                            HStack {
                                Text(model)
                                    .font(.callout)

                                if settingsManager.isDefaultModel(model, for: settingsManager.selectedProvider) {
                                    Text("default")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(Capsule())
                                }

                                Spacer()

                                if !settingsManager.isDefaultModel(model, for: settingsManager.selectedProvider) {
                                    Button(action: {
                                        settingsManager.removeCustomModel(model, for: settingsManager.selectedProvider)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove custom model")
                                }
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                settingsManager.selectedModel == model
                                    ? Color.accentColor.opacity(0.1)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                Text("Custom models allow you to use new models as they become available.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private func addModel() {
        let trimmed = newModelName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        settingsManager.addCustomModel(trimmed, for: settingsManager.selectedProvider)
        newModelName = ""
    }
}

// MARK: - Prompts Settings
struct PromptsSettingsView: View {
    @EnvironmentObject var promptManager: PromptManager
    @State private var selectedPrompt: Prompt?
    @State private var editorMode: PromptEditorMode?
    @State private var conflictingIDs: Set<UUID> = []

    enum PromptEditorMode: Identifiable {
        case new
        case edit(Prompt)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let prompt): return prompt.id.uuidString
            }
        }

        var prompt: Prompt? {
            switch self {
            case .new: return nil
            case .edit(let prompt): return prompt
            }
        }
    }

    var body: some View {
        HSplitView {
            // List
            VStack(spacing: 0) {
                List(selection: $selectedPrompt) {
                    ForEach(promptManager.prompts) { prompt in
                        PromptListRow(prompt: prompt, hasConflict: conflictingIDs.contains(prompt.id))
                            .tag(prompt)
                    }
                }
                .listStyle(.inset)
                .onReceive(NotificationCenter.default.publisher(for: .hotkeyConflictDetected)) { notification in
                    if let ids = notification.object as? Set<UUID> {
                        conflictingIDs = ids
                    }
                }

                Divider()

                HStack(spacing: 4) {
                    Button(action: { editorMode = .new }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)

                    Button(action: {
                        if let prompt = selectedPrompt {
                            promptManager.deletePrompt(prompt)
                            selectedPrompt = nil
                        }
                    }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedPrompt == nil)

                    Spacer()
                }
                .padding(8)
            }
            .frame(minWidth: 200)

            // Detail
            if let prompt = selectedPrompt {
                PromptDetailView(prompt: prompt, editorMode: $editorMode)
                    .frame(minWidth: 350)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.65))
                    Text("Select a prompt")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Choose a prompt from the list to view and edit its details.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                }
                .frame(minWidth: 350, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $editorMode) { mode in
            PromptEditorView(prompt: mode.prompt) { saved in
                if case .edit(let original) = mode {
                    let updated = Prompt(id: original.id, name: saved.name, instruction: saved.instruction, hotkey: saved.hotkey, isEnabled: saved.isEnabled, icon: saved.icon)
                    promptManager.updatePrompt(updated)
                    selectedPrompt = updated
                } else {
                    promptManager.addPrompt(saved)
                    selectedPrompt = saved
                }
                NotificationCenter.default.post(name: .refreshHotkeys, object: nil)
            }
        }
    }
}

struct PromptListRow: View {
    let prompt: Prompt
    let hasConflict: Bool

    var body: some View {
        HStack(spacing: 10) {
            // SF Symbol icon with colored circular background
            PromptIconView(
                iconName: prompt.icon,
                color: IconColorMapper.color(for: prompt.icon),
                size: 28
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.name)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                if let hotkey = prompt.hotkey {
                    HStack(spacing: 4) {
                        HotkeyBadge(hotkey: hotkey)
                        if hasConflict {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .help("Hotkey conflict - this shortcut may not work")
                        }
                    }
                }
            }
            Spacer()
            if !prompt.isEnabled {
                Image(systemName: "eye.slash")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct PromptDetailView: View {
    let prompt: Prompt
    @Binding var editorMode: PromptsSettingsView.PromptEditorMode?
    @EnvironmentObject var promptManager: PromptManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 12) {
                PromptIconView(
                    iconName: prompt.icon,
                    color: IconColorMapper.color(for: prompt.icon),
                    size: 36
                )

                Text(prompt.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { prompt.isEnabled },
                    set: { newValue in
                        var updated = prompt
                        updated.isEnabled = newValue
                        promptManager.updatePrompt(updated)
                        NotificationCenter.default.post(name: .refreshHotkeys, object: nil)
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.bottom, 20)

            // Hotkey
            VStack(alignment: .leading, spacing: 8) {
                Text("HOTKEY")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                if let hotkey = prompt.hotkey {
                    HotkeyBadge(hotkey: hotkey, style: .large)
                } else {
                    Text("No hotkey assigned")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 20)

            // Instruction
            VStack(alignment: .leading, spacing: 8) {
                Text("INSTRUCTION")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                ScrollView {
                    Text(prompt.instruction)
                        .font(.callout)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: .infinity)
                .padding(12)
                .background(Color(.textBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 16)

            // Actions
            HStack {
                Spacer()
                Button("Edit Prompt") {
                    editorMode = .edit(prompt)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct PromptEditorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var name: String
    @State private var instruction: String
    @State private var isEnabled: Bool
    @State private var icon: String
    @State private var hotkeyConfig: HotkeyConfig?
    @State private var isRecordingHotkey = false
    @State private var showEmojiPicker = false

    // Test prompt states
    @State private var testInput: String = ""
    @State private var testOutput: String = ""
    @State private var isTesting = false
    @State private var showTestSection = false

    let prompt: Prompt?
    let onSave: (Prompt) -> Void

    private let commonEmojis = ["✨", "✏️", "💼", "✂️", "😊", "📝", "🌍", "📋", "📧", "💻", "🔧", "💡", "🎯", "📊", "🔍", "✅"]

    // Common SF Symbols for quick selection - organized by category
    private let commonSymbols = [
        // Text & Writing
        "pencil.line", "pencil.tip", "square.and.pencil", "text.alignleft",
        "character.cursor.ibeam", "text.quote", "text.aligncenter", "text.alignright",

        // Communication
        "envelope", "paperplane", "bubble.left", "bubble.right",
        "ellipsis.bubble", "quote.bubble",

        // Work & Productivity
        "briefcase", "calendar", "clock", "timer", "list.bullet",
        "list.number", "checklist", "folder", "doc.text", "doc.richtext",

        // Creative
        "paintbrush", "paintpalette", "wand.and.stars", "sparkles",
        "star.fill", "lightbulb", "lightbulb.fill",

        // Technical
        "terminal", "chevron.left.forwardslash.chevron.right", "curlybraces",
        "function", "arrow.triangle.2.circlepath",

        // Science & Analysis
        "chart.bar", "chart.line.uptrend.xyaxis", "magnifyingglass",
        "cube", "atom",

        // Social & People
        "person", "person.2", "face.smiling", "hand.thumbsup",

        // Objects
        "globe", "map", "flag", "tag", "scissors",
        "wrench.and.screwdriver", "laptopcomputer", "target"
    ]

    init(prompt: Prompt?, onSave: @escaping (Prompt) -> Void) {
        self.prompt = prompt
        self.onSave = onSave
        _name = State(initialValue: prompt?.name ?? "")
        _instruction = State(initialValue: prompt?.instruction ?? "")
        _isEnabled = State(initialValue: prompt?.isEnabled ?? true)
        _icon = State(initialValue: prompt?.icon ?? "sparkles")
        _hotkeyConfig = State(initialValue: prompt?.hotkey)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(prompt == nil ? "New Prompt" : "Edit Prompt")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name and Icon row
                    HStack(spacing: 12) {
                        // Icon picker
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Icon")
                                .font(.callout)
                                .fontWeight(.medium)

                            Button(action: { showEmojiPicker.toggle() }) {
                                PromptIconView(
                                    iconName: icon,
                                    color: IconColorMapper.color(for: icon),
                                    size: 32
                                )
                                .frame(width: 44, height: 44)
                                .background(Color(.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showEmojiPicker) {
                                SFSymbolPickerView(selectedSymbol: $icon, symbols: commonSymbols)
                            }
                        }

                        // Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.callout)
                                .fontWeight(.medium)
                            TextField("e.g., Fix Grammar", text: $name)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: name) { newName in
                                    if icon == "sparkles" && !newName.isEmpty {
                                        icon = Prompt.defaultIcon(for: newName)
                                    }
                                }
                        }
                    }

                    // Hotkey
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hotkey")
                            .font(.callout)
                            .fontWeight(.medium)

                        HStack(spacing: 12) {
                            if isRecordingHotkey {
                                Text("Press keys...")
                                    .font(.callout)
                                    .foregroundColor(.accentColor)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.accentColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else if let hotkey = hotkeyConfig {
                                HStack {
                                    HotkeyBadge(hotkey: hotkey, style: .large)
                                    Spacer()
                                    Button(action: { hotkeyConfig = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Text("None")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.controlBackgroundColor))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            Button(isRecordingHotkey ? "Cancel" : "Record") {
                                isRecordingHotkey.toggle()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .hotkeyRecorded)) { notification in
                        if isRecordingHotkey, let config = notification.object as? HotkeyConfig {
                            hotkeyConfig = config
                            isRecordingHotkey = false
                        }
                    }

                    // Instruction
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Instruction")
                            .font(.callout)
                            .fontWeight(.medium)
                        TextEditor(text: $instruction)
                            .font(.callout)
                            .frame(height: 100)
                            .padding(4)
                            .background(Color(.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(.separatorColor), lineWidth: 1)
                            )
                    }

                    // Enabled toggle
                    Toggle("Enabled", isOn: $isEnabled)
                        .font(.callout)

                    // Test Prompt Section
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { withAnimation(.spring(response: 0.3)) { showTestSection.toggle() } }) {
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundColor(.accentColor)
                                Text("Test Prompt")
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: showTestSection ? "chevron.up" : "chevron.down")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if showTestSection {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sample text:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                TextField("Enter text to test...", text: $testInput, axis: .vertical)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(2...4)

                                HStack {
                                    Button(action: runTest) {
                                        HStack(spacing: 4) {
                                            if isTesting {
                                                ProgressView()
                                                    .scaleEffect(0.7)
                                            } else {
                                                Image(systemName: "play.fill")
                                            }
                                            Text(isTesting ? "Testing..." : "Run Test")
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(testInput.isEmpty || instruction.isEmpty || isTesting || !settingsManager.isConfigured)

                                    if !settingsManager.isConfigured {
                                        Text("Configure API key first")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }

                                if !testOutput.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Result:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Text(testOutput)
                                            .font(.callout)
                                            .foregroundColor(.primary)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.green.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(.controlBackgroundColor).opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            Divider()

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let newPrompt = Prompt(
                        id: prompt?.id ?? UUID(),
                        name: name,
                        instruction: instruction,
                        hotkey: hotkeyConfig,
                        isEnabled: isEnabled,
                        icon: icon
                    )
                    onSave(newPrompt)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || instruction.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 520, height: 580)
        .background(HotkeyRecorderView(isRecording: $isRecordingHotkey))
    }

    private func runTest() {
        guard !testInput.isEmpty, !instruction.isEmpty else { return }

        isTesting = true
        testOutput = ""

        let testPrompt = Prompt(name: name, instruction: instruction, icon: icon)

        Task {
            do {
                let result = try await AIService.shared.transform(
                    text: testInput,
                    prompt: testPrompt,
                    settings: settingsManager
                )
                await MainActor.run {
                    testOutput = result
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testOutput = "Error: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

// MARK: - Emoji Picker (Legacy - keeping for backward compatibility)
struct EmojiPickerView: View {
    @Binding var selectedEmoji: String
    let emojis: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Choose Icon")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 4), spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: {
                        selectedEmoji = emoji
                        dismiss()
                    }) {
                        Text(emoji)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(selectedEmoji == emoji ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
    }
}

// MARK: - SF Symbol Picker
struct SFSymbolPickerView: View {
    @Binding var selectedSymbol: String
    let symbols: [String]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Choose Icon")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 4), spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Button(action: {
                        selectedSymbol = symbol
                        dismiss()
                    }) {
                        PromptIconView(
                            iconName: symbol,
                            color: IconColorMapper.color(for: symbol),
                            size: 24
                        )
                        .frame(width: 40, height: 40)
                        .background(selectedSymbol == symbol ? Color.accentColor.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 240)
    }
}

// MARK: - Hotkey Badge Component
struct HotkeyBadge: View {
    let hotkey: HotkeyConfig
    var style: BadgeStyle = .small

    enum BadgeStyle {
        case small, large
    }

    var body: some View {
        Text(hotkey.displayString)
            .font(.system(style == .small ? .caption : .callout, design: .rounded, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, style == .small ? 6 : 10)
            .padding(.vertical, style == .small ? 3 : 5)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: style == .small ? 4 : 6))
    }
}

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> NSView {
        let view = HotkeyRecorderNSView()
        view.isRecording = isRecording
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? HotkeyRecorderNSView {
            view.isRecording = isRecording
        }
    }
}

class HotkeyRecorderNSView: NSView {
    var isRecording = false {
        didSet {
            if isRecording {
                window?.makeFirstResponder(self)
            }
        }
    }

    override var acceptsFirstResponder: Bool { isRecording }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Require at least one modifier
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !modifiers.isEmpty else { return }

        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }

        let config = HotkeyConfig(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers)
        NotificationCenter.default.post(name: .hotkeyRecorded, object: config)
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let hotkeyRecorded = Notification.Name("hotkeyRecorded")
    static let refreshHotkeys = Notification.Name("refreshHotkeys")
    static let processingStarted = Notification.Name("processingStarted")
    static let processingFinished = Notification.Name("processingFinished")
    static let hotkeyConflictDetected = Notification.Name("hotkeyConflictDetected")
    static let transformationError = Notification.Name("transformationError")
}

#Preview {
    SettingsView()
        .environmentObject(PromptManager())
        .environmentObject(SettingsManager())
}
