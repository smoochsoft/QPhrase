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

    var body: some View {
        Form {
            Section {
                Picker("", selection: $settingsManager.selectedProvider) {
                    ForEach(SettingsManager.AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.vertical, 4)
            } header: {
                Text("Provider")
            }

            Section {
                Picker("Model", selection: $settingsManager.selectedModel) {
                    ForEach(settingsManager.selectedProvider.models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .onChange(of: settingsManager.selectedProvider) { _ in
                    settingsManager.selectedModel = settingsManager.selectedProvider.models.first ?? ""
                    showAPIKey = false
                }

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

                Link("Get \(settingsManager.selectedProvider.rawValue) API Key →", destination: URL(string: apiKeyLink)!)
                    .font(.callout)
            } header: {
                Text("Configuration")
            } footer: {
                Text("Your API key is stored securely in the macOS Keychain.")
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
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
}

#Preview {
    SettingsView()
        .environmentObject(PromptManager())
        .environmentObject(SettingsManager())
}
