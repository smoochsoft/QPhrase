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
                Text("QPhrase")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Onboarding / API Status Warning
            if !settingsManager.isConfigured {
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.orange)

                    Text("Welcome to QPhrase!")
                        .font(.headline)

                    Text("Add your API key to start transforming text with AI.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: { openSettings() }) {
                        Text("Get Started")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.08))
            }

            // Prompts List
            ScrollView {
                let enabledPrompts = promptManager.prompts.filter { $0.isEnabled }
                LazyVStack(spacing: 0) {
                    ForEach(enabledPrompts) { prompt in
                        PromptRowView(prompt: prompt)
                    }

                    if enabledPrompts.isEmpty {
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
