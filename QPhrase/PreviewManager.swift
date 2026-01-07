import Foundation
import SwiftUI
import AppKit

// MARK: - Preview Manager
class PreviewManager: ObservableObject {
    static let shared = PreviewManager()

    @Published var isShowingPreview = false
    @Published var originalText: String = ""
    @Published var transformedText: String = ""
    @Published var promptName: String = ""

    private var onApply: (() -> Void)?
    private var onCancel: (() -> Void)?

    private var previewWindow: NSWindow?

    func showPreview(
        original: String,
        transformed: String,
        promptName: String,
        onApply: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalText = original
        self.transformedText = transformed
        self.promptName = promptName
        self.onApply = onApply
        self.onCancel = onCancel

        DispatchQueue.main.async {
            self.isShowingPreview = true
            self.showPreviewWindow()
        }
    }

    func apply() {
        onApply?()
        dismissPreview()
    }

    func cancel() {
        onCancel?()
        dismissPreview()
    }

    private func dismissPreview() {
        isShowingPreview = false
        previewWindow?.close()
        previewWindow = nil
    }

    private func showPreviewWindow() {
        if previewWindow != nil {
            previewWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let previewView = PreviewWindowView()
            .environmentObject(self)

        let hostingController = NSHostingController(rootView: previewView)

        previewWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        previewWindow?.title = "Preview: \(promptName)"
        previewWindow?.contentViewController = hostingController
        previewWindow?.center()
        previewWindow?.level = .floating
        previewWindow?.isReleasedWhenClosed = false

        previewWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Preview Window View
struct PreviewWindowView: View {
    @EnvironmentObject var previewManager: PreviewManager
    @State private var showDiff = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                Text(previewManager.promptName)
                    .font(.headline)

                Spacer()

                Toggle("Show changes", isOn: $showDiff)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Content
            HSplitView {
                // Original
                VStack(alignment: .leading, spacing: 8) {
                    Label("Original", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ScrollView {
                        Text(previewManager.originalText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(Color(.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding()
                .frame(minWidth: 200)

                // Transformed
                VStack(alignment: .leading, spacing: 8) {
                    Label("Transformed", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundColor(.accentColor)

                    ScrollView {
                        Text(previewManager.transformedText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(Color(.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding()
                .frame(minWidth: 200)
            }

            Divider()

            // Footer with actions
            HStack {
                Text("Press ↩ to apply, ⎋ to cancel")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Cancel") {
                    previewManager.cancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Apply") {
                    previewManager.apply()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
        }
        .frame(minWidth: 450, minHeight: 300)
    }
}

// MARK: - Diff Highlighting (simplified)
struct DiffText: View {
    let original: String
    let transformed: String

    var body: some View {
        // For simplicity, just show the transformed text
        // A full diff implementation would be more complex
        Text(transformed)
    }
}
