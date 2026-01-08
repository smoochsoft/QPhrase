import SwiftUI

// MARK: - Diff Helpers
struct CharDiff {
    let char: Character
    let isChanged: Bool
}

/// Computes character-level diff between two strings
func computeCharacterDiff(original: String, transformed: String) -> [CharDiff] {
    var result: [CharDiff] = []

    let origChars = Array(original)
    let transChars = Array(transformed)

    // Simple character-by-character comparison
    // This will highlight additions and character changes
    var i = 0
    var j = 0

    while i < origChars.count || j < transChars.count {
        if i >= origChars.count {
            // Additions at the end
            result.append(CharDiff(char: transChars[j], isChanged: true))
            j += 1
        } else if j >= transChars.count {
            // Deletions (skip original chars)
            i += 1
        } else if origChars[i] == transChars[j] {
            // Same character
            result.append(CharDiff(char: transChars[j], isChanged: false))
            i += 1
            j += 1
        } else {
            // Different character - try to find match ahead
            var foundMatch = false

            // Look ahead up to 3 characters for insertions
            for lookAhead in 1...min(3, transChars.count - j) {
                if i < origChars.count && j + lookAhead < transChars.count &&
                   origChars[i] == transChars[j + lookAhead] {
                    // Found insertion(s)
                    for k in 0..<lookAhead {
                        result.append(CharDiff(char: transChars[j + k], isChanged: true))
                    }
                    j += lookAhead
                    foundMatch = true
                    break
                }
            }

            // Look ahead in original for deletions
            if !foundMatch {
                for lookAhead in 1...min(3, origChars.count - i) {
                    if j < transChars.count && i + lookAhead < origChars.count &&
                       origChars[i + lookAhead] == transChars[j] {
                        // Found deletion(s) - skip original chars
                        i += lookAhead
                        foundMatch = true
                        break
                    }
                }
            }

            // If no match found, treat as replacement
            if !foundMatch {
                result.append(CharDiff(char: transChars[j], isChanged: true))
                i += 1
                j += 1
            }
        }
    }

    return result
}

/// Creates AttributedString with green highlighting for changed characters
func createHighlightedText(original: String, transformed: String) -> AttributedString {
    let diffs = computeCharacterDiff(original: original, transformed: transformed)

    var result = AttributedString()
    for diff in diffs {
        var part = AttributedString(String(diff.char))
        if diff.isChanged {
            part.backgroundColor = Color.green.opacity(0.3)
            part.foregroundColor = Color.primary
        } else {
            part.foregroundColor = Color.primary
        }
        result.append(part)
    }
    return result
}

// MARK: - Preview Window Controller
class PreviewWindowController: ObservableObject {
    @Published var originalText: String
    @Published var transformedText: String
    let promptName: String
    let promptIcon: String

    var onAccept: ((String) -> Void)?
    var onReject: (() -> Void)?

    init(originalText: String, transformedText: String, promptName: String, promptIcon: String) {
        self.originalText = originalText
        self.transformedText = transformedText
        self.promptName = promptName
        self.promptIcon = promptIcon
    }
}

// MARK: - Preview Window View
struct PreviewWindowView: View {
    @EnvironmentObject var controller: PreviewWindowController
    @FocusState private var isEditingFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Integrated diff view with editable result
            integratedDiffView
                .frame(maxHeight: .infinity)

            Divider()

            // Action buttons
            footerView
        }
        .frame(minWidth: 600, minHeight: 450)
        .onAppear {
            // Auto-focus the transformed text for immediate editing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isEditingFocused = true
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 10) {
            PromptIconView(
                iconName: controller.promptIcon,
                color: IconColorMapper.color(for: controller.promptIcon),
                size: 20
            )
            Text(controller.promptName)
                .font(.headline)
            Spacer()
            Text("Preview Changes")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var integratedDiffView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show inline diff with highlighted changes
            VStack(alignment: .leading, spacing: 8) {
                Text("CHANGES")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                ScrollView {
                    if controller.originalText != controller.transformedText {
                        Text(createHighlightedText(
                            original: controller.originalText,
                            transformed: controller.transformedText
                        ))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
                        Text("No changes")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .italic()
                            .padding()
                    }
                }
                .frame(minHeight: 100, maxHeight: 150)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }

            // Keep existing editable section unchanged
            VStack(alignment: .leading, spacing: 8) {
                Text("EDIT & APPLY")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)

                TextEditor(text: $controller.transformedText)
                    .font(.body)
                    .focused($isEditingFocused)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .padding()
    }

    private var footerView: some View {
        HStack(spacing: QPhraseSpacing.base) {
            Text("⏎ Accept  •  ⎋ Reject")
                .font(QPhraseTypography.caption)
                .foregroundColor(QPhraseColors.textTertiary)

            Spacer()

            Button("Reject") {
                controller.onReject?()
            }
            .keyboardShortcut(.escape, modifiers: [])

            Button("Accept") {
                controller.onAccept?(controller.transformedText)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(controller.transformedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(QPhraseSpacing.lg)
    }
}
