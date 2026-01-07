import Foundation
import SwiftUI
import AppKit

// MARK: - Toast Types
enum ToastType {
    case success(String)
    case error(String, String?) // title, optional action message
    case processing(String)

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .processing: return "arrow.trianglehead.2.clockwise"
        }
    }

    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .processing: return .blue
        }
    }

    var title: String {
        switch self {
        case .success(let msg): return msg
        case .error(let title, _): return title
        case .processing(let msg): return msg
        }
    }
}

// MARK: - Toast Manager
class ToastManager: ObservableObject {
    static let shared = ToastManager()

    @Published var currentToast: ToastType?
    @Published var isVisible = false

    private var dismissTask: Task<Void, Never>?

    func show(_ toast: ToastType, duration: TimeInterval = 2.5) {
        dismissTask?.cancel()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentToast = toast
            isVisible = true
        }

        // Auto-dismiss (except for processing)
        if case .processing = toast {
            return
        }

        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                self.dismiss()
            }
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.currentToast = nil
        }
    }

    func showSuccess(_ message: String) {
        show(.success(message))
    }

    func showError(_ title: String, details: String? = nil) {
        show(.error(title, details), duration: 4.0)
    }

    func showProcessing(_ message: String) {
        show(.processing(message))
    }
}

// MARK: - Toast View
struct ToastView: View {
    let toast: ToastType
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    let onSettings: (() -> Void)?

    @State private var isSpinning = false

    init(toast: ToastType, onDismiss: @escaping () -> Void, onRetry: (() -> Void)? = nil, onSettings: (() -> Void)? = nil) {
        self.toast = toast
        self.onDismiss = onDismiss
        self.onRetry = onRetry
        self.onSettings = onSettings
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Group {
                if case .processing = toast {
                    Image(systemName: toast.icon)
                        .rotationEffect(.degrees(isSpinning ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isSpinning)
                        .onAppear { isSpinning = true }
                } else {
                    Image(systemName: toast.icon)
                }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(toast.color)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(.subheadline, weight: .medium))

                if case .error(_, let details) = toast, let details = details {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Action buttons for errors
            if case .error = toast {
                HStack(spacing: 8) {
                    if let onRetry = onRetry {
                        Button("Retry") {
                            onRetry()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if let onSettings = onSettings {
                        Button("Settings") {
                            onSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(toast.color.opacity(0.3), lineWidth: 1)
        }
    }
}

// MARK: - Toast Container View
struct ToastContainerView: View {
    @ObservedObject var toastManager = ToastManager.shared
    var onRetry: (() -> Void)?
    var onSettings: (() -> Void)?

    var body: some View {
        VStack {
            if toastManager.isVisible, let toast = toastManager.currentToast {
                ToastView(
                    toast: toast,
                    onDismiss: { toastManager.dismiss() },
                    onRetry: onRetry,
                    onSettings: onSettings
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }

            Spacer()
        }
    }
}

// MARK: - Floating Toast Window
class ToastWindowController {
    static let shared = ToastWindowController()

    private var window: NSWindow?
    private var hostingView: NSHostingView<ToastContainerView>?

    func show() {
        if window == nil {
            createWindow()
        }
        window?.orderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let contentView = ToastContainerView(
            onRetry: nil,
            onSettings: {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
        )

        hostingView = NSHostingView(rootView: contentView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window?.contentView = hostingView
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.level = .floating
        window?.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window?.ignoresMouseEvents = false

        // Position near menu bar
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window!.frame
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.maxY - windowFrame.height - 10
            window?.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
