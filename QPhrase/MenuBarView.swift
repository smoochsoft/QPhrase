import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var promptManager: PromptManager
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var history = TransformationHistory.shared
    @State private var selectedIndex: Int = 0
    @State private var showHistory = false
    @State private var successMessage: String?
    @State private var searchQuery: String = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var enabledPrompts: [Prompt] {
        promptManager.prompts.filter { $0.isEnabled }
    }

    var filteredPrompts: [Prompt] {
        guard !searchQuery.isEmpty else { return enabledPrompts }
        return enabledPrompts.filter { prompt in
            prompt.name.localizedCaseInsensitiveContains(searchQuery) ||
            prompt.instruction.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with status badge
            headerView

            Divider()
                .opacity(0.5)

            // Success toast
            if let message = successMessage {
                successToast(message: message)
            }

            // Onboarding / API Status Warning
            if !settingsManager.isConfigured {
                onboardingView
            } else {
                // Search bar
                searchBar
            }

            // History section (collapsible)
            if !history.recentRecords.isEmpty {
                historySection
            }

            // Prompts List with Settings at bottom
            promptsList
        }
        .frame(width: 300, height: 380)
        .onReceive(NotificationCenter.default.publisher(for: .transformationCompleted)) { notification in
            if let record = notification.object as? TransformationRecord {
                showSuccessToast("\(record.promptIcon) \(record.promptName) applied")
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            // App logo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .cornerRadius(6)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 2) {
                Text("QPhrase")
                    .font(QPhraseTypography.headerTitle)
                    .foregroundColor(QPhraseColors.textPrimary)

                // Provider + model info with logo
                HStack(spacing: 5) {
                    Image(settingsManager.selectedProvider.theme.logoImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                    Text(settingsManager.selectedModel)
                        .font(.caption2)
                        .foregroundColor(QPhraseColors.textSecondary)
                }
            }

            Spacer()

            // Connection status badge
            HStack(spacing: 4) {
                Circle()
                    .fill(settingsManager.isConfigured ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(settingsManager.isConfigured ? "Connected" : "Setup")
                    .font(.caption2)
                    .foregroundColor(QPhraseColors.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.1))
            )
        }
        .padding(.horizontal, QPhraseSpacing.edgePadding)
        .padding(.vertical, QPhraseSpacing.base)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.04)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 3)
    }

    private var statusBadge: some View {
        HStack(spacing: QPhraseSpacing.sm) {
            Image(systemName: settingsManager.isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(settingsManager.isConfigured ? QPhraseColors.accentSuccess : QPhraseColors.accentWarning)

            Text(settingsManager.selectedProvider.rawValue)
                .font(QPhraseTypography.badge)
                .foregroundColor(QPhraseColors.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, QPhraseSpacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: QPhraseDepth.subtleShadow, radius: QPhraseDepth.subtleShadowRadius, y: QPhraseDepth.subtleShadowY)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: QPhraseSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(QPhraseColors.textTertiary)

            TextField("Search prompts...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(QPhraseTypography.bodyText)
                .focused($isSearchFocused)
        }
        .padding(.horizontal, QPhraseSpacing.base)
        .padding(.vertical, QPhraseSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: QPhraseDepth.buttonRadius)
                .fill(QPhraseColors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: QPhraseDepth.buttonRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(
                    color: isSearchFocused ? QPhraseDepth.accentGlow : Color.clear,
                    radius: isSearchFocused ? 8 : 0
                )
        )
        .padding(.horizontal, QPhraseSpacing.edgePadding)
        .padding(.vertical, QPhraseSpacing.md)
        .animation(reduceMotion ? .none : QPhraseAnimations.easeInOut, value: isSearchFocused)
    }

    // MARK: - Success Toast
    private func successToast(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(QPhraseColors.accentSuccess)
                .symbolRenderingMode(.hierarchical)

            Text(message)
                .font(QPhraseTypography.bodyText)
                .fontWeight(.medium)
                .foregroundColor(QPhraseColors.textPrimary)
        }
        .padding(.horizontal, QPhraseSpacing.lg)
        .padding(.vertical, QPhraseSpacing.base)
        .background(
            RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius + 2)
                .fill(.ultraThinMaterial)
                .shadow(color: QPhraseDepth.successGlow, radius: QPhraseDepth.cardShadowRadius + 4, y: QPhraseDepth.hoverShadowY)
                .overlay(
                    RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius + 2)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, QPhraseSpacing.edgePadding)
        .padding(.top, QPhraseSpacing.md)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .scale(scale: 0.9)).combined(with: .opacity),
                removal: .opacity.combined(with: .scale(scale: 0.95))
            )
        )
    }

    private func showSuccessToast(_ message: String) {
        let animation: Animation? = reduceMotion ? nil : QPhraseAnimations.bouncySpring
        withAnimation(animation) {
            successMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(reduceMotion ? nil : QPhraseAnimations.easeOut) {
                successMessage = nil
            }
        }
    }

    // MARK: - Onboarding
    private var onboardingView: some View {
        VStack(spacing: 10) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(QPhraseColors.accentWarning)

            Text("Welcome to QPhrase!")
                .font(QPhraseTypography.promptName)

            Text("Add your API key to start transforming text with AI.")
                .font(QPhraseTypography.caption)
                .foregroundColor(QPhraseColors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: { openSettings() }) {
                Text("Get Started")
                    .font(QPhraseTypography.promptName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(QPhraseSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius)
                        .stroke(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, QPhraseSpacing.edgePadding)
        .padding(.vertical, QPhraseSpacing.md)
    }

    // MARK: - History Section
    private var historySection: some View {
        VStack(spacing: 0) {
            // Header
            Button(action: {
                let animation: Animation? = reduceMotion ? nil : QPhraseAnimations.spring
                withAnimation(animation) { showHistory.toggle() }
            }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(QPhraseTypography.caption)
                        .foregroundColor(QPhraseColors.textSecondary)
                    Text("Recent")
                        .font(QPhraseTypography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(QPhraseColors.textSecondary)
                    Spacer()
                    Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                        .font(QPhraseTypography.footnote)
                        .foregroundColor(QPhraseColors.textSecondary)
                }
                .padding(.horizontal, QPhraseSpacing.edgePadding)
                .padding(.vertical, QPhraseSpacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showHistory {
                VStack(spacing: QPhraseSpacing.xs) {
                    ForEach(history.recentRecords.prefix(3)) { record in
                        HistoryRow(record: record)
                    }
                }
                .padding(.vertical, QPhraseSpacing.md)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius)
                        .fill(.thinMaterial)
                        .shadow(color: QPhraseDepth.cardShadow, radius: QPhraseDepth.cardShadowRadius, y: QPhraseDepth.cardShadowY)
                )
                .padding(.horizontal, QPhraseSpacing.edgePadding)
                .padding(.bottom, QPhraseSpacing.md)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .opacity
                    )
                )
            }

            Divider()
                .padding(.top, QPhraseSpacing.xs)
        }
    }

    // MARK: - Prompts List
    private var promptsList: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(filteredPrompts.enumerated()), id: \.element.id) { index, prompt in
                        PopoverPromptRow(
                            prompt: prompt,
                            isSelected: index == selectedIndex,
                            reduceMotion: reduceMotion
                        )
                        .onTapGesture {
                            runPrompt(prompt)
                        }
                    }

                    if filteredPrompts.isEmpty && !searchQuery.isEmpty {
                        emptySearchView
                    } else if enabledPrompts.isEmpty {
                        emptyPromptsView
                    }
                }
            }

            Divider()
                .opacity(0.5)

            // Settings and Quit integrated into menu
            footerView
        }
    }

    private var emptyPromptsView: some View {
        VStack(spacing: QPhraseSpacing.md) {
            Image(systemName: "text.bubble")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(QPhraseColors.textTertiary)
            Text("No prompts enabled")
                .font(QPhraseTypography.promptName)
                .foregroundColor(QPhraseColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptySearchView: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(QPhraseColors.textTertiary)

            Text("No prompts found")
                .font(QPhraseTypography.promptName)
                .foregroundColor(QPhraseColors.textSecondary)

            Text("Try searching for something else")
                .font(QPhraseTypography.caption)
                .foregroundColor(QPhraseColors.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer
    private var footerView: some View {
        VStack(spacing: 0) {
            SettingsButton()

            Divider()
                .opacity(0.3)

            QuitButton()
        }
    }

    // MARK: - Actions
    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    private func runPrompt(_ prompt: Prompt) {
        // Close popover and run
        NotificationCenter.default.post(name: .runPromptFromPopover, object: prompt)
    }
}

// MARK: - Prompt Row
struct PopoverPromptRow: View {
    let prompt: Prompt
    var isSelected: Bool = false
    var reduceMotion: Bool = false
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: QPhraseSpacing.base) {
            // SF Symbol Icon with gradient background
            PromptIconView(
                iconName: prompt.icon,
                color: IconColorMapper.color(for: prompt.icon),
                size: 32
            )

            // Just the name, no subtitle
            Text(prompt.name)
                .font(QPhraseTypography.promptName)
                .foregroundColor(QPhraseColors.textPrimary)

            Spacer()

            // Run button on hover
            if isHovered {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .transition(.scale.combined(with: .opacity))
            }

            if let hotkey = prompt.hotkey {
                Text(hotkey.displayString)
                    .font(QPhraseTypography.badge)
                    .foregroundColor(QPhraseColors.textSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(QPhraseColors.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
        .padding(.horizontal, QPhraseSpacing.edgePadding)
        .padding(.vertical, 8)
        .background(
            Group {
                if isHovered {
                    RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius)
                        .fill(.ultraThinMaterial)
                        .shadow(
                            color: QPhraseDepth.hoverShadow,
                            radius: QPhraseDepth.hoverShadowRadius,
                            y: QPhraseDepth.hoverShadowY
                        )
                } else {
                    RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius)
                        .fill(Color.clear)
                }
            }
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .contentShape(Rectangle())
        .onHover { hovering in
            let animation: Animation? = reduceMotion ? nil : QPhraseAnimations.easeInOut
            withAnimation(animation) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let record: TransformationRecord
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: QPhraseSpacing.md) {
            // Small icon (use SF Symbol if icon looks like one, otherwise emoji)
            if record.promptIcon.count > 2 {
                // It's likely an SF Symbol name
                Image(systemName: record.promptIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(IconColorMapper.color(for: record.promptIcon))
            } else {
                // It's emoji (for backward compat)
                Text(record.promptIcon)
                    .font(QPhraseTypography.caption)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.promptName)
                    .font(QPhraseTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(QPhraseColors.textPrimary)
                Text(record.timeAgo)
                    .font(QPhraseTypography.footnote)
                    .foregroundColor(QPhraseColors.textSecondary)
            }

            Spacer()

            Button(action: { copyOriginal() }) {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isHovered ? .accentColor : QPhraseColors.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Copy original text")
            .opacity(isHovered ? 1 : 0.6)
        }
        .padding(.horizontal, QPhraseSpacing.base)
        .padding(.vertical, QPhraseSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: QPhraseDepth.buttonRadius)
                .fill(isHovered ? QPhraseColors.hoverBackground.opacity(0.5) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(QPhraseAnimations.easeInOut) {
                isHovered = hovering
            }
        }
    }

    private func copyOriginal() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.originalText, forType: .string)
    }
}

// MARK: - Settings Button
struct SettingsButton: View {
    @State private var isHovered = false

    var body: some View {
        Button(action: { openSettings() }) {
            HStack(spacing: QPhraseSpacing.base) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(QPhraseColors.textSecondary)
                    .frame(width: 32)

                Text("Settings")
                    .font(QPhraseTypography.promptName)
                    .foregroundColor(QPhraseColors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(QPhraseColors.textTertiary)
            }
            .padding(.horizontal, QPhraseSpacing.edgePadding)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius)
                    .fill(isHovered ? QPhraseColors.hoverBackground.opacity(0.5) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(QPhraseAnimations.easeInOut) {
                isHovered = hovering
            }
        }
    }

    private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

// MARK: - Quit Button
struct QuitButton: View {
    @State private var isHovered = false

    var body: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            HStack(spacing: QPhraseSpacing.base) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(QPhraseColors.textSecondary)
                    .frame(width: 32)

                Text("Quit QPhrase")
                    .font(QPhraseTypography.promptName)
                    .foregroundColor(QPhraseColors.textPrimary)

                Spacer()

                Text("⌘Q")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(QPhraseColors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(QPhraseColors.backgroundSecondary)
                    )
            }
            .padding(.horizontal, QPhraseSpacing.edgePadding)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: QPhraseDepth.cardRadius)
                    .fill(isHovered ? Color.red.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(QPhraseAnimations.easeInOut) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let runPromptFromPopover = Notification.Name("runPromptFromPopover")
}

#Preview {
    MenuBarView()
        .environmentObject(PromptManager())
        .environmentObject(SettingsManager())
}
