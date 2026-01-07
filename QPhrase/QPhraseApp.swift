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
                .environmentObject(appDelegate.historyManager)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var settingsWindow: NSWindow?
    private var normalIcon: NSImage?
    private var processingIcons: [NSImage] = []
    private var successIcon: NSImage?
    private var errorIcon: NSImage?
    private var animationTimer: Timer?
    private var currentAnimationFrame = 0

    let promptManager = PromptManager()
    let settingsManager = SettingsManager()
    let historyManager = HistoryManager()
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

        // Create animated processing icons (spinner frames)
        let spinnerSymbols = [
            "circle.dotted",
            "circle.bottomhalf.filled",
            "circle.lefthalf.filled",
            "circle.tophalf.filled",
            "circle.righthalf.filled"
        ]
        processingIcons = spinnerSymbols.compactMap { symbolName in
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Processing")
            image?.isTemplate = true
            return image
        }

        // Success/error icons for feedback
        successIcon = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Success")
        successIcon?.isTemplate = true
        errorIcon = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Error")
        errorIcon?.isTemplate = true

        if let button = statusItem.button {
            button.image = normalIcon
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Setup popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(promptManager)
                .environmentObject(settingsManager)
                .environmentObject(historyManager)
        )

        // Setup hotkey manager
        hotkeyManager = HotkeyManager(promptManager: promptManager, settingsManager: settingsManager, historyManager: historyManager)
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
            selector: #selector(handleTransformSuccess),
            name: .transformSuccess,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTransformError),
            name: .transformError,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExecutePrompt),
            name: .executePrompt,
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
        startProcessingAnimation()
    }

    @objc func handleProcessingFinished() {
        stopProcessingAnimation()
    }

    @objc func handleTransformSuccess(_ notification: Notification) {
        stopProcessingAnimation()

        // Show success icon briefly
        statusItem.button?.image = successIcon

        // Show toast
        if let promptName = notification.userInfo?["promptName"] as? String {
            ToastManager.shared.showSuccess("Transformed with \"\(promptName)\"")
        } else {
            ToastManager.shared.showSuccess("Text transformed")
        }

        // Restore normal icon after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.statusItem.button?.image = self?.normalIcon
        }
    }

    @objc func handleTransformError(_ notification: Notification) {
        stopProcessingAnimation()

        // Show error icon briefly
        statusItem.button?.image = errorIcon

        // Show toast
        let title = notification.userInfo?["title"] as? String ?? "Error"
        let details = notification.userInfo?["details"] as? String
        ToastManager.shared.showError(title, details: details)

        // Restore normal icon after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.statusItem.button?.image = self?.normalIcon
        }
    }

    private func startProcessingAnimation() {
        currentAnimationFrame = 0
        animationTimer?.invalidate()

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self, !self.processingIcons.isEmpty else { return }
            self.statusItem.button?.image = self.processingIcons[self.currentAnimationFrame]
            self.currentAnimationFrame = (self.currentAnimationFrame + 1) % self.processingIcons.count
        }
    }

    private func stopProcessingAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        statusItem.button?.image = normalIcon
    }

    @objc func handleExecutePrompt(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let prompt = userInfo["prompt"] as? Prompt,
              let text = userInfo["text"] as? String else {
            return
        }

        Task {
            await hotkeyManager.executePromptWithText(prompt, text: text)
        }
    }

    @objc func handleOpenSettings() {
        // Close popover first
        if popover.isShown {
            popover.performClose(nil)
        }

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
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if !trusted {
            print("Accessibility permissions needed for text selection")
        }
    }

    func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
                .environmentObject(promptManager)
                .environmentObject(settingsManager)
                .environmentObject(historyManager)

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
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
