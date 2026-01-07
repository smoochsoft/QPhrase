import SwiftUI
import Carbon
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var promptManager: PromptManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                GeneralSettingsView()
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                    .tag(0)

                APISettingsView()
                    .tabItem {
                        Label("API", systemImage: "key")
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
                // Hidden keyboard shortcuts for tab switching
                Button("") { selectedTab = 0 }
                    .keyboardShortcut("1", modifiers: .command)
                    .hidden()
                Button("") { selectedTab = 1 }
                    .keyboardShortcut("2", modifiers: .command)
                    .hidden()
                Button("") { selectedTab = 2 }
                    .keyboardShortcut("3", modifiers: .command)
                    .hidden()

                Button("") {
                    NSApplication.shared.keyWindow?.close()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()

                Spacer()

                // Keyboard shortcut hint
                Text("\u{2318}1/2/3 to switch tabs")
                    .font(.caption)
                    .foregroundColor(.secondary)

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

    var body: some View {
        Form {
            Section {
                Toggle("Show notifications", isOn: $settingsManager.showNotifications)
                Toggle("Play sounds", isOn: $settingsManager.playSound)
            } header: {
                Text("Feedback")
            } footer: {
                Text("Get notified when transformations complete or encounter errors.")
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("Preview before applying", isOn: $settingsManager.showPreview)
            } header: {
                Text("Behavior")
            } footer: {
                Text("Show a preview window before replacing text. Hold \u{2325} (Option) when pressing hotkey to temporarily toggle this setting.")
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
    }
}

struct LaunchAtLoginToggle: View {
    @State private var launchAtLogin = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch at login", isOn: $launchAtLogin)
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

// MARK: - API Settings
struct APISettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showAPIKey = false

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

    private func hasKeyForProvider(_ provider: SettingsManager.AIProvider) -> Bool {
        switch provider {
        case .openai: return !settingsManager.openAIKey.isEmpty
        case .anthropic: return !settingsManager.anthropicKey.isEmpty
        case .groq: return !settingsManager.groqKey.isEmpty
        case .gemini: return !settingsManager.geminiKey.isEmpty
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Provider Cards
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose your AI provider")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(SettingsManager.AIProvider.allCases, id: \.self) { provider in
                            ProviderCard(
                                provider: provider,
                                isSelected: settingsManager.selectedProvider == provider,
                                hasKey: hasKeyForProvider(provider)
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    settingsManager.selectedProvider = provider
                                    settingsManager.selectedModel = provider.models.first ?? ""
                                    showAPIKey = false
                                }
                            }
                        }
                    }
                }

                Divider()

                // Configuration
                VStack(alignment: .leading, spacing: 16) {
                    Text("Configuration")
                        .font(.headline)

                    // Model picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("", selection: $settingsManager.selectedModel) {
                            ForEach(settingsManager.selectedProvider.models, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .labelsHidden()
                    }

                    // API Key
                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            if showAPIKey {
                                TextField("Enter your API key", text: currentKeyBinding)
                                    .textFieldStyle(.roundedBorder)
                            } else {
                                SecureField("Enter your API key", text: currentKeyBinding)
                                    .textFieldStyle(.roundedBorder)
                            }

                            Button(action: { showAPIKey.toggle() }) {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.plain)

                            if !currentKeyBinding.wrappedValue.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }

                        Link(destination: URL(string: apiKeyLink)!) {
                            HStack(spacing: 4) {
                                Text("Get \(settingsManager.selectedProvider.rawValue) API Key")
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                            .font(.callout)
                        }
                        .padding(.top, 4)
                    }
                }

                // Security note
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("Your API key is stored securely in the macOS Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
    }
}

// MARK: - Provider Card
struct ProviderCard: View {
    let provider: SettingsManager.AIProvider
    let isSelected: Bool
    let hasKey: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var providerIcon: String {
        switch provider {
        case .openai: return "circle.hexagongrid"
        case .anthropic: return "a.circle"
        case .groq: return "bolt.circle"
        case .gemini: return "sparkle"
        }
    }

    private var providerColor: Color {
        switch provider {
        case .openai: return .green
        case .anthropic: return .orange
        case .groq: return .purple
        case .gemini: return .blue
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // Icon
                Image(systemName: providerIcon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? providerColor : .secondary)

                // Name
                Text(provider.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(hasKey ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(hasKey ? "Ready" : "Set up")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? providerColor.opacity(0.1) : Color(.controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? providerColor : Color.clear, lineWidth: 2)
            }
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
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
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a prompt")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Choose a prompt from the list to view and edit its details.")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 200)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $editorMode) { mode in
            PromptEditorView(prompt: mode.prompt) { saved in
                if case .edit(let original) = mode {
                    let updated = Prompt(id: original.id, name: saved.name, instruction: saved.instruction, hotkey: saved.hotkey, isEnabled: saved.isEnabled)
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
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.name)
                    .fontWeight(.medium)
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
            HStack(alignment: .center) {
                Text(prompt.name)
                    .font(.title2)
                    .fontWeight(.semibold)

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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: .infinity)
                .padding(12)
                .background(Color(.textBackgroundColor).opacity(0.5))
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
    @State private var name: String
    @State private var instruction: String
    @State private var isEnabled: Bool
    @State private var hotkeyConfig: HotkeyConfig?
    @State private var isRecordingHotkey = false

    let prompt: Prompt?
    let onSave: (Prompt) -> Void

    init(prompt: Prompt?, onSave: @escaping (Prompt) -> Void) {
        self.prompt = prompt
        self.onSave = onSave
        _name = State(initialValue: prompt?.name ?? "")
        _instruction = State(initialValue: prompt?.instruction ?? "")
        _isEnabled = State(initialValue: prompt?.isEnabled ?? true)
        _hotkeyConfig = State(initialValue: prompt?.hotkey)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(prompt == nil ? "New Prompt" : "Edit Prompt")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)

            // Form
            VStack(alignment: .leading, spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name")
                        .font(.callout)
                        .fontWeight(.medium)
                    TextField("e.g., Fix Grammar", text: $name)
                        .textFieldStyle(.roundedBorder)
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
                        .frame(height: 120)
                        .padding(4)
                        .background(Color(.textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(.separatorColor), lineWidth: 1)
                        )
                }

                // Enabled
                Toggle("Enabled", isOn: $isEnabled)
                    .font(.callout)
            }
            .padding(.horizontal, 24)

            Spacer()

            Divider()
                .padding(.top, 16)

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
                        isEnabled: isEnabled
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
        .frame(width: 480, height: 450)
        .background(HotkeyRecorderView(isRecording: $isRecordingHotkey))
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

    override var acceptsFirstResponder: Bool { true }

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
    static let transformSuccess = Notification.Name("transformSuccess")
    static let transformError = Notification.Name("transformError")
    static let executePrompt = Notification.Name("executePrompt")
    static let showHistory = Notification.Name("showHistory")
}

#Preview {
    SettingsView()
        .environmentObject(PromptManager())
        .environmentObject(SettingsManager())
        .environmentObject(HistoryManager())
}
