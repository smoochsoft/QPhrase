import SwiftUI

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var currentPage = 0
    @Binding var isPresented: Bool

    private let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            // Content
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)

                HowItWorksPage()
                    .tag(1)

                PermissionsPage()
                    .tag(2)

                APIKeyPage(isPresented: $isPresented)
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            Divider()

            // Navigation
            HStack {
                // Page indicators
                HStack(spacing: 6) {
                    ForEach(0..<totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                // Navigation buttons
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!settingsManager.isConfigured)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 450)
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 80, height: 80)

            VStack(spacing: 8) {
                Text("Welcome to QPhrase")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Transform text anywhere with AI")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "sparkles", title: "AI-Powered", description: "Fix grammar, rewrite professionally, and more")
                FeatureRow(icon: "keyboard", title: "Global Hotkeys", description: "Works in any app with keyboard shortcuts")
                FeatureRow(icon: "bolt", title: "Instant", description: "Select text, press hotkey, done")
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

// MARK: - How It Works Page
struct HowItWorksPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("How It Works")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 24) {
                StepView(
                    number: 1,
                    icon: "text.cursor",
                    title: "Select Text",
                    description: "Highlight any text in any application"
                )

                Image(systemName: "arrow.down")
                    .foregroundColor(.secondary)

                StepView(
                    number: 2,
                    icon: "command",
                    title: "Press Hotkey",
                    description: "Use \u{2318}\u{21E7}G to fix grammar, or other shortcuts"
                )

                Image(systemName: "arrow.down")
                    .foregroundColor(.secondary)

                StepView(
                    number: 3,
                    icon: "sparkles",
                    title: "Magic!",
                    description: "Text is transformed and replaced instantly"
                )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Permissions Page
struct PermissionsPage: View {
    @State private var hasAccessibility = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            VStack(spacing: 8) {
                Text("Accessibility Permission")
                    .font(.title)
                    .fontWeight(.bold)

                Text("QPhrase needs accessibility access to read selected text and paste results.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 350)
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: hasAccessibility ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(hasAccessibility ? .green : .secondary)

                    Text("Accessibility Access")
                        .font(.subheadline)

                    Spacer()

                    if !hasAccessibility {
                        Button("Grant Access") {
                            requestAccessibility()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("Granted")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 40)

            Text("You can change this later in System Settings > Privacy & Security > Accessibility")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)

            Spacer()
        }
        .padding()
        .onAppear {
            checkAccessibility()
        }
    }

    private func checkAccessibility() {
        hasAccessibility = AXIsProcessTrusted()
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)

        // Poll for changes
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                hasAccessibility = true
                timer.invalidate()
            }
        }
    }
}

// MARK: - API Key Page
struct APIKeyPage: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var isPresented: Bool
    @State private var showKey = false

    private var currentKeyBinding: Binding<String> {
        switch settingsManager.selectedProvider {
        case .openai: return $settingsManager.openAIKey
        case .anthropic: return $settingsManager.anthropicKey
        case .groq: return $settingsManager.groqKey
        case .gemini: return $settingsManager.geminiKey
        }
    }

    private var apiKeyLink: String {
        switch settingsManager.selectedProvider {
        case .openai: return "https://platform.openai.com/api-keys"
        case .anthropic: return "https://console.anthropic.com/settings/keys"
        case .groq: return "https://console.groq.com/keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Connect Your AI")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Choose a provider and enter your API key")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 16) {
                // Provider picker
                Picker("Provider", selection: $settingsManager.selectedProvider) {
                    ForEach(SettingsManager.AIProvider.allCases, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)

                // API Key input
                VStack(spacing: 8) {
                    HStack {
                        if showKey {
                            TextField("Enter API Key", text: currentKeyBinding)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("Enter API Key", text: currentKeyBinding)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showKey.toggle() }) {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)

                        if settingsManager.isConfigured {
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
                }
                .padding(.horizontal, 40)
            }

            if settingsManager.isConfigured {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("You're all set! Click 'Get Started' to begin.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Supporting Views
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StepView: View {
    let number: Int
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 40, height: 40)

                Text("\(number)")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.accentColor)
                    Text(title)
                        .font(.headline)
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
        .environmentObject(SettingsManager())
}
