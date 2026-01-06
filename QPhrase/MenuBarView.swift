import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var promptManager: PromptManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 18, height: 18)
                Text("QPhrase")
                    .font(.system(.headline, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.windowBackgroundColor))

            Divider()
                .opacity(0.5)

            // Onboarding / API Status Warning
            if !settingsManager.isConfigured {
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

            // Prompts List
            ScrollView {
                let enabledPrompts = promptManager.prompts.filter { $0.isEnabled }
                LazyVStack(spacing: 0) {
                    ForEach(enabledPrompts) { prompt in
                        PopoverPromptRow(prompt: prompt)
                    }

                    if enabledPrompts.isEmpty {
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
                .padding(.vertical, 6)
            }

            Divider()
                .opacity(0.5)

            // Footer
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

                Text("⌘Q to Quit")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 280, height: 340)
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

struct PopoverPromptRow: View {
    let prompt: Prompt
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.name)
                    .font(.system(.subheadline, weight: .medium))

                Text(prompt.instruction)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let hotkey = prompt.hotkey {
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
        .background(isHovered ? Color(.selectedContentBackgroundColor).opacity(0.4) : Color.clear)
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
