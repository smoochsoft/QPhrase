import SwiftUI

// MARK: - Tab Selection
enum PopoverTab: String, CaseIterable {
    case prompts = "Prompts"
    case history = "History"
}

// MARK: - Main Menu Bar View
struct MenuBarView: View {
    @EnvironmentObject var promptManager: PromptManager
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var historyManager: HistoryManager
    @State private var selectedTab: PopoverTab = .prompts
    @State private var clipboardText: String = ""
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            PopoverHeader(selectedTab: $selectedTab)

            Divider().opacity(0.5)

            // Onboarding / API Status Warning
            if !settingsManager.isConfigured {
                OnboardingBanner()
            }

            // Clipboard preview (if has content)
            if !clipboardText.isEmpty && selectedTab == .prompts {
                ClipboardPreview(text: clipboardText) {
                    clipboardText = ""
                }
            }

            // Content based on tab
            switch selectedTab {
            case .prompts:
                PromptsListView(clipboardText: clipboardText)
            case .history:
                HistoryListView()
            }

            Divider().opacity(0.5)

            // Footer
            PopoverFooter()
        }
        .frame(width: 320, height: 420)
        .onAppear {
            loadClipboard()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSPasteboard.didChangeNotification)) { _ in
            loadClipboard()
        }
    }

    private func loadClipboard() {
        if let text = NSPasteboard.general.string(forType: .string), !text.isEmpty {
            clipboardText = String(text.prefix(200))
        } else {
            clipboardText = ""
        }
    }
}

// MARK: - Header with Tabs
struct PopoverHeader: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var selectedTab: PopoverTab

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("QPhrase")
                    .font(.system(.headline, weight: .semibold))

                Spacer()

                // Provider indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(settingsManager.isConfigured ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(settingsManager.selectedProvider.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Tab picker
            Picker("", selection: $selectedTab) {
                ForEach(PopoverTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Onboarding Banner
struct OnboardingBanner: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "key.fill")
                .font(.system(size: 24))
                .foregroundColor(.orange)

            Text("Welcome to QPhrase!")
                .font(.system(.subheadline, weight: .semibold))

            Text("Add your API key to start transforming text with AI.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { openSettings() }) {
                Text("Get Started")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(16)
        .background(Color.orange.opacity(0.06))
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

// MARK: - Clipboard Preview
struct ClipboardPreview: View {
    let text: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Prompts List
struct PromptsListView: View {
    @EnvironmentObject var promptManager: PromptManager
    @EnvironmentObject var settingsManager: SettingsManager
    let clipboardText: String

    var body: some View {
        ScrollView {
            let enabledPrompts = promptManager.prompts.filter { $0.isEnabled }
            LazyVStack(spacing: 2) {
                ForEach(enabledPrompts) { prompt in
                    ClickablePromptRow(
                        prompt: prompt,
                        clipboardText: clipboardText,
                        isConfigured: settingsManager.isConfigured
                    )
                }

                if enabledPrompts.isEmpty {
                    EmptyPromptsView()
                }
            }
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Clickable Prompt Row
struct ClickablePromptRow: View {
    let prompt: Prompt
    let clipboardText: String
    let isConfigured: Bool

    @State private var isHovered = false
    @State private var isRunning = false

    var body: some View {
        HStack(spacing: 10) {
            // Icon based on prompt name
            promptIcon
                .font(.system(size: 16))
                .foregroundColor(isHovered ? .accentColor : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.name)
                    .font(.system(.subheadline, weight: .medium))

                Text(prompt.instruction)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isHovered && isConfigured && !clipboardText.isEmpty {
                Button(action: runPrompt) {
                    if isRunning {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 40, height: 24)
                    } else {
                        Text("Run")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .transition(.scale.combined(with: .opacity))
            } else if let hotkey = prompt.hotkey {
                Text(hotkey.displayString)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color(.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHovered ? Color(.selectedContentBackgroundColor).opacity(0.3) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    private var promptIcon: Image {
        let name = prompt.name.lowercased()
        if name.contains("grammar") || name.contains("fix") {
            return Image(systemName: "textformat.abc")
        } else if name.contains("professional") {
            return Image(systemName: "briefcase")
        } else if name.contains("concise") || name.contains("short") {
            return Image(systemName: "arrow.down.right.and.arrow.up.left")
        } else if name.contains("friendly") || name.contains("casual") {
            return Image(systemName: "face.smiling")
        } else if name.contains("expand") {
            return Image(systemName: "arrow.up.left.and.arrow.down.right")
        } else if name.contains("translate") {
            return Image(systemName: "globe")
        } else {
            return Image(systemName: "sparkles")
        }
    }

    private func runPrompt() {
        guard !isRunning else { return }
        isRunning = true

        NotificationCenter.default.post(
            name: .executePrompt,
            object: nil,
            userInfo: ["prompt": prompt, "text": clipboardText]
        )

        // Reset after a delay (actual completion handled by notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            isRunning = false
        }
    }
}

// MARK: - Empty Prompts View
struct EmptyPromptsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No prompts enabled")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - History List
struct HistoryListView: View {
    @EnvironmentObject var historyManager: HistoryManager

    var body: some View {
        ScrollView {
            if historyManager.entries.isEmpty {
                EmptyHistoryView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(historyManager.entries) { entry in
                        HistoryEntryRow(entry: entry)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
        }
    }
}

// MARK: - History Entry Row
struct HistoryEntryRow: View {
    let entry: HistoryEntry
    @EnvironmentObject var historyManager: HistoryManager
    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.promptName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)

                Spacer()

                Text(entry.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Transformation preview
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.originalText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.transformedText)
                        .font(.caption)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Action buttons on hover
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: copyOriginal) {
                        Label("Original", systemImage: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button(action: copyTransformed) {
                        Label(showCopied ? "Copied!" : "Result", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)

                    Spacer()

                    Button(action: deleteEntry) {
                        Image(systemName: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.red)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(10)
        .background(Color(.controlBackgroundColor).opacity(isHovered ? 0.8 : 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private func copyOriginal() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.originalText, forType: .string)
        SoundManager.shared.playClick()
    }

    private func copyTransformed() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.transformedText, forType: .string)
        SoundManager.shared.playClick()

        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showCopied = false
            }
        }
    }

    private func deleteEntry() {
        withAnimation {
            historyManager.deleteEntry(entry)
        }
    }
}

// MARK: - Empty History View
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))

            Text("No history yet")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Your text transformations will appear here")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

// MARK: - Footer
struct PopoverFooter: View {
    @EnvironmentObject var historyManager: HistoryManager

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { openSettings() }) {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                    Text("Settings")
                        .font(.subheadline)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            if !historyManager.entries.isEmpty {
                Button(action: clearHistory) {
                    Text("Clear History")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }

            Text("\u{2318}Q to Quit")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.windowBackgroundColor))
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    private func clearHistory() {
        withAnimation {
            historyManager.clearHistory()
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

// MARK: - Pasteboard Change Notification
extension NSPasteboard {
    static let didChangeNotification = Notification.Name("NSPasteboardDidChangeNotification")
}

#Preview {
    MenuBarView()
        .environmentObject(PromptManager())
        .environmentObject(SettingsManager())
        .environmentObject(HistoryManager())
}
