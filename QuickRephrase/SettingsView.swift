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
                PromptsSettingsView()
                    .tabItem {
                        Label("Prompts", systemImage: "text.bubble")
                    }
                    .tag(0)

                APISettingsView()
                    .tabItem {
                        Label("API", systemImage: "key")
                    }
                    .tag(1)

                GeneralSettingsView()
                    .tabItem {
                        Label("General", systemImage: "gear")
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
        .frame(width: 600, height: 520)
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
            VStack(alignment: .leading) {
                List(selection: $selectedPrompt) {
                    ForEach(promptManager.prompts) { prompt in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(prompt.name)
                                    .fontWeight(.medium)
                                if let hotkey = prompt.hotkey {
                                    HStack(spacing: 4) {
                                        Text(hotkey.displayString)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        if conflictingIDs.contains(prompt.id) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .font(.caption)
                                                .foregroundColor(.orange)
                                                .help("Hotkey conflict - this shortcut may not work")
                                        }
                                    }
                                }
                            }
                            Spacer()
                            if !prompt.isEnabled {
                                Image(systemName: "eye.slash")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(prompt)
                    }
                }
                .listStyle(.inset)
                .onReceive(NotificationCenter.default.publisher(for: .hotkeyConflictDetected)) { notification in
                    if let ids = notification.object as? Set<UUID> {
                        conflictingIDs = ids
                    }
                }

                HStack {
                    Button(action: {
                        editorMode = .new
                    }) {
                        Image(systemName: "plus")
                    }

                    Button(action: {
                        if let prompt = selectedPrompt {
                            promptManager.deletePrompt(prompt)
                            selectedPrompt = nil
                        }
                    }) {
                        Image(systemName: "minus")
                    }
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
                VStack {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a prompt to view details")
                        .foregroundColor(.secondary)
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

struct PromptDetailView: View {
    let prompt: Prompt
    @Binding var editorMode: PromptsSettingsView.PromptEditorMode?
    @EnvironmentObject var promptManager: PromptManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(prompt.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Toggle("Enabled", isOn: Binding(
                    get: { prompt.isEnabled },
                    set: { newValue in
                        var updated = prompt
                        updated.isEnabled = newValue
                        promptManager.updatePrompt(updated)
                        NotificationCenter.default.post(name: .refreshHotkeys, object: nil)
                    }
                ))
                .toggleStyle(.switch)
            }

            GroupBox("Hotkey") {
                HStack {
                    if let hotkey = prompt.hotkey {
                        Text(hotkey.displayString)
                            .font(.system(.title3, design: .monospaced))
                    } else {
                        Text("No hotkey assigned")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(8)
            }

            GroupBox("Instruction") {
                ScrollView {
                    Text(prompt.instruction)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("Edit Prompt") {
                    editorMode = .edit(prompt)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(spacing: 16) {
            Text(prompt == nil ? "New Prompt" : "Edit Prompt")
                .font(.headline)
            
            Form {
                TextField("Name", text: $name)
                
                VStack(alignment: .leading) {
                    Text("Instruction")
                    TextEditor(text: $instruction)
                        .font(.body)
                        .frame(height: 150)
                        .border(Color(.separatorColor))
                }
                
                HStack {
                    Text("Hotkey")
                    Spacer()
                    
                    if isRecordingHotkey {
                        Text("Press keys...")
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(6)
                    } else if let hotkey = hotkeyConfig {
                        HStack {
                            Text(hotkey.displayString)
                                .font(.system(.body, design: .monospaced))
                            Button(action: { hotkeyConfig = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.controlBackgroundColor))
                        .cornerRadius(6)
                    } else {
                        Text("None")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(isRecordingHotkey ? "Cancel" : "Record") {
                        isRecordingHotkey.toggle()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .hotkeyRecorded)) { notification in
                    if isRecordingHotkey, let config = notification.object as? HotkeyConfig {
                        hotkeyConfig = config
                        isRecordingHotkey = false
                    }
                }
                
                Toggle("Enabled", isOn: $isEnabled)
            }
            
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
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || instruction.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
        .background(HotkeyRecorderView(isRecording: $isRecordingHotkey))
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

// MARK: - API Settings
struct APISettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false
    @State private var showGroqKey = false
    @State private var showGeminiKey = false

    var body: some View {
        Form {
            Section {
                Picker("AI Provider", selection: $settingsManager.selectedProvider) {
                    ForEach(SettingsManager.AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }

                Picker("Model", selection: $settingsManager.selectedModel) {
                    ForEach(settingsManager.selectedProvider.models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .onChange(of: settingsManager.selectedProvider) { _ in
                    settingsManager.selectedModel = settingsManager.selectedProvider.models.first ?? ""
                }
            }

            Section("API Keys") {
                APIKeyRow(
                    label: "OpenAI",
                    key: $settingsManager.openAIKey,
                    showKey: $showOpenAIKey,
                    link: "https://platform.openai.com/api-keys"
                )

                APIKeyRow(
                    label: "Anthropic",
                    key: $settingsManager.anthropicKey,
                    showKey: $showAnthropicKey,
                    link: "https://console.anthropic.com/settings/keys"
                )

                APIKeyRow(
                    label: "Groq",
                    key: $settingsManager.groqKey,
                    showKey: $showGroqKey,
                    link: "https://console.groq.com/keys"
                )

                APIKeyRow(
                    label: "Gemini",
                    key: $settingsManager.geminiKey,
                    showKey: $showGeminiKey,
                    link: "https://aistudio.google.com/apikey"
                )
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct APIKeyRow: View {
    let label: String
    @Binding var key: String
    @Binding var showKey: Bool
    let link: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .frame(width: 80, alignment: .leading)

                if showKey {
                    TextField("API Key", text: $key)
                        .textFieldStyle(.roundedBorder)
                } else {
                    SecureField("API Key", text: $key)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: { showKey.toggle() }) {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if !key.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Link("Get \(label) API Key →", destination: URL(string: link)!)
                .font(.caption)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - General Settings
struct GeneralSettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    
    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Show notifications", isOn: $settingsManager.showNotifications)
                Toggle("Play sounds", isOn: $settingsManager.playSound)
            }
            
            Section("Startup") {
                LaunchAtLoginToggle()
            }
            
            Section("About") {
                HStack {
                    Text("QuickRephrase")
                        .fontWeight(.medium)
                    Spacer()
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Text("A simple macOS app for instant text transformation using AI.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
            // Revert the toggle state
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
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
