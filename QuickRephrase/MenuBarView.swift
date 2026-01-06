import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var promptManager: PromptManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 20, height: 20)
                Text("QuickRephrase")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // API Status Warning
            if !settingsManager.isConfigured {
                Button(action: { openSettings() }) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Configure API key in settings")
                            .font(.caption)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.1))
            }

            // Prompts List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(promptManager.prompts.filter { $0.isEnabled }) { prompt in
                        PromptRowView(prompt: prompt)
                    }

                    if promptManager.prompts.filter({ $0.isEnabled }).isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "text.bubble")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("No prompts enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical, 4)
            }

            Divider()

            // Footer with actions
            HStack(spacing: 16) {
                Button(action: { openSettings() }) {
                    Label("Settings", systemImage: "gear")
                }
                .buttonStyle(.plain)
                .foregroundColor(.primary)

                Spacer()

                Text("⌘Q to Quit")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 300, height: 360)
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

struct PromptRowView: View {
    let prompt: Prompt
    @State private var isHovered = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.name)
                    .fontWeight(.medium)

                Text(prompt.instruction)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let hotkey = prompt.hotkey {
                Text(hotkey.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color(.selectedContentBackgroundColor).opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

#Preview {
    MenuBarView()
        .environmentObject(PromptManager())
        .environmentObject(SettingsManager())
}
