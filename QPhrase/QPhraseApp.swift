import SwiftUI
import AppKit

@main
struct QPhraseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.promptManager)
                .environmentObject(appDelegate.settingsManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsWindow: NSWindow?
    var previewWindow: NSWindow?
    var previewController: PreviewWindowController?
    private var normalIcon: NSImage?
    private var processingIcon: NSImage?
    private var processingTimer: Timer?

    let promptManager = PromptManager()
    let settingsManager = SettingsManager()
    var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent multiple instances
        if let bundleID = Bundle.main.bundleIdentifier {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if runningApps.count > 1 {
                // Another instance is already running - activate it and quit this one
                for app in runningApps where app != NSRunningApplication.current {
                    app.activate(options: .activateIgnoringOtherApps)
                }
                NSApp.terminate(nil)
                return
            }
        }

        // Hide dock icon - menu bar app only
        NSApp.setActivationPolicy(.accessory)

        // Setup menu bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Prepare icons
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            normalIcon = image
        }
        processingIcon = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Processing")
        processingIcon?.isTemplate = true

        if let button = statusItem.button {
            button.image = normalIcon
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Setup popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 380)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(promptManager)
                .environmentObject(settingsManager)
        )

        // Setup hotkey manager
        hotkeyManager = HotkeyManager(promptManager: promptManager, settingsManager: settingsManager, appDelegate: self)
        hotkeyManager.registerAllHotkeys()

        // Setup app menu with keyboard shortcuts
        setupMenu()

        // Listen for notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshHotkeys),
            name: .refreshHotkeys,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProcessingStarted),
            name: .processingStarted,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProcessingFinished),
            name: .processingFinished,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRunPromptFromPopover),
            name: .runPromptFromPopover,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransformationError),
            name: .transformationError,
            object: nil
        )

        // Request accessibility permissions
        requestAccessibilityPermissions()

        // Show onboarding if not configured
        if !settingsManager.isConfigured {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showOnboardingPopover()
            }
        }
    }

    private func showOnboardingPopover() {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: ","))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "Quit QPhrase", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Edit menu - required for Cmd+C/V/X/A to work in text fields
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc func refreshHotkeys() {
        hotkeyManager.registerAllHotkeys()
    }

    @objc func handleProcessingStarted() {
        statusItem.button?.image = processingIcon
        startProcessingAnimation()

        // Transition overlay to processing state
        if settingsManager.showOverlayEffects {
            SparkleOverlayManager.shared.transitionToState(.processing)
        }
    }

    @objc func handleProcessingFinished() {
        stopProcessingAnimation()
        statusItem.button?.image = normalIcon

        // Show success overlay state
        if settingsManager.showOverlayEffects {
            SparkleOverlayManager.shared.transitionToState(.success)
        }

        // Brief success flash
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.flashSuccess()
        }
    }

    @objc func handleRunPromptFromPopover(_ notification: Notification) {
        guard let prompt = notification.object as? Prompt else { return }

        // Close popover
        popover.performClose(nil)

        // Small delay to let user see the app before transformation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            Task { @MainActor in
                await self?.hotkeyManager.executePrompt(prompt)
            }
        }
    }

    @objc func handleTransformationError() {
        // Show error overlay state
        if settingsManager.showOverlayEffects {
            SparkleOverlayManager.shared.transitionToState(.error)
        }
    }

    // MARK: - Animated Processing
    private func startProcessingAnimation() {
        var alpha: CGFloat = 1.0
        var increasing = false

        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let button = self?.statusItem.button else { return }

            if increasing {
                alpha += 0.05
                if alpha >= 1.0 {
                    alpha = 1.0
                    increasing = false
                }
            } else {
                alpha -= 0.05
                if alpha <= 0.4 {
                    alpha = 0.4
                    increasing = true
                }
            }

            button.alphaValue = alpha
        }
    }

    private func stopProcessingAnimation() {
        processingTimer?.invalidate()
        processingTimer = nil
        statusItem.button?.alphaValue = 1.0
    }

    private func flashSuccess() {
        guard let button = statusItem.button else { return }

        // Quick green tint effect using layer
        let originalImage = button.image
        let successIcon = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
        successIcon?.isTemplate = true

        button.image = successIcon
        button.contentTintColor = .systemGreen

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            button.image = originalImage
            button.contentTintColor = nil
        }
    }

    @objc func handleOpenSettings() {
        // Close popover first
        if popover.isShown {
            popover.performClose(nil)
        }

        // Switch to regular app to appear in Command+Tab and enable menu bar
        NSApp.setActivationPolicy(.regular)

        // Ensure Edit menu is available for paste operations
        setupMenu()

        openSettings()
    }

    @objc func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        // Right-click shows context menu
        if event?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        // Left-click toggles popover
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(handleOpenSettings), keyEquivalent: "")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(promptManager)
                .environmentObject(settingsManager)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 580),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.minSize = NSSize(width: 550, height: 450)
            settingsWindow?.title = "QPhrase Settings"
            settingsWindow?.contentView = NSHostingView(rootView: settingsView)
            settingsWindow?.center()
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.delegate = self
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Preview Window Management
    @MainActor
    func showPreview(
        original: String,
        transformed: String,
        prompt: Prompt,
        completion: @escaping (String?) -> Void
    ) {
        // Track if completion has been called to prevent double-resume
        class CompletionState {
            var hasCompleted = false
        }
        let completionState = CompletionState()

        let controller = PreviewWindowController(
            originalText: original,
            transformedText: transformed,
            promptName: prompt.name,
            promptIcon: prompt.icon
        )

        controller.onAccept = { [weak self] editedText in
            guard !completionState.hasCompleted else { return }
            completionState.hasCompleted = true
            completion(editedText)
            self?.closePreview()
        }

        controller.onReject = { [weak self] in
            guard !completionState.hasCompleted else { return }
            completionState.hasCompleted = true
            completion(nil)
            self?.closePreview()
        }

        // Create preview view
        let previewView = PreviewWindowView()
            .environmentObject(controller)

        // Store controller first to prevent deallocation
        self.previewController = controller

        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Preview Transformation"
        window.minSize = NSSize(width: 500, height: 400)
        window.level = .floating
        window.delegate = self
        window.isReleasedWhenClosed = false

        // Set content view
        let hostingView = NSHostingView(rootView: previewView)
        window.contentView = hostingView

        // Store window reference
        self.previewWindow = window

        // Show window
        window.center()

        // Activate app first, then show window with a slight delay
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Small delay to ensure app activation completes before showing window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func closePreview() {
        previewWindow?.close()
        previewWindow = nil
        previewController = nil

        // Restore menu bar only mode
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Only restore menu bar mode when settings window closes (not preview)
        if notification.object as? NSWindow == settingsWindow {
            NSApp.setActivationPolicy(.accessory)
        } else if notification.object as? NSWindow == previewWindow {
            // User closed the window - treat as reject
            previewController?.onReject?()
        }
    }
}
