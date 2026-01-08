import Foundation
import Carbon
import AppKit
import UserNotifications

class HotkeyManager {
    private var promptManager: PromptManager
    private var settingsManager: SettingsManager
    weak var appDelegate: AppDelegate?
    private var eventHandler: EventHandlerRef?
    private var registeredHotkeys: [EventHotKeyRef] = []
    private var hotkeyIDToPrompt: [UInt32: UUID] = [:]
    private var nextHotkeyID: UInt32 = 1
    private(set) var conflictingPromptIDs: Set<UUID> = []
    private var isTransforming = false

    init(promptManager: PromptManager, settingsManager: SettingsManager, appDelegate: AppDelegate? = nil) {
        self.promptManager = promptManager
        self.settingsManager = settingsManager
        self.appDelegate = appDelegate
        setupEventHandler()

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    deinit {
        unregisterAllHotkeys()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
    }

    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData, let event = event else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleHotkey(event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handlerCallback, 1, &eventType, selfPtr, &eventHandler)
    }

    private func handleHotkey(event: EventRef) -> OSStatus {
        var hotkeyID = EventHotKeyID()
        GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)

        guard let promptID = hotkeyIDToPrompt[hotkeyID.id],
              let prompt = promptManager.prompts.first(where: { $0.id == promptID && $0.isEnabled }) else {
            return OSStatus(eventNotHandledErr)
        }

        Task { @MainActor in
            await executePrompt(prompt)
        }

        return noErr
    }

    func registerAllHotkeys() {
        unregisterAllHotkeys()
        conflictingPromptIDs.removeAll()

        for prompt in promptManager.prompts where prompt.isEnabled {
            if let hotkey = prompt.hotkey {
                registerHotkey(for: prompt, config: hotkey)
            }
        }

        // Post notification if there are conflicts
        if !conflictingPromptIDs.isEmpty {
            NotificationCenter.default.post(name: .hotkeyConflictDetected, object: conflictingPromptIDs)
        }
    }

    private func registerHotkey(for prompt: Prompt, config: HotkeyConfig) {
        var hotkeyRef: EventHotKeyRef?
        let hotkeyID = EventHotKeyID(signature: OSType(0x5152_5048), id: nextHotkeyID) // "QRPH"

        let status = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let ref = hotkeyRef {
            registeredHotkeys.append(ref)
            hotkeyIDToPrompt[nextHotkeyID] = prompt.id
            nextHotkeyID += 1
        } else {
            // Hotkey registration failed - likely a conflict with system or another app
            conflictingPromptIDs.insert(prompt.id)
            NSLog("QPhrase: Failed to register hotkey for '\(prompt.name)' (status: \(status)) - may conflict with system shortcut")
        }
    }

    /// Test if a hotkey can be registered (for UI validation)
    func testHotkeyAvailability(_ config: HotkeyConfig) -> Bool {
        var hotkeyRef: EventHotKeyRef?
        let testID = EventHotKeyID(signature: OSType(0x5152_5048), id: 99999)

        let status = RegisterEventHotKey(
            config.keyCode,
            config.modifiers,
            testID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            return true
        }
        return false
    }

    private func unregisterAllHotkeys() {
        for ref in registeredHotkeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotkeys.removeAll()
        hotkeyIDToPrompt.removeAll()
        nextHotkeyID = 1
    }

    /// Execute a prompt on the currently selected text (public for click-to-run)
    @MainActor
    func executePrompt(_ prompt: Prompt) async {
        // Prevent concurrent transformations
        guard !isTransforming else {
            showNotification(title: "QPhrase", body: "A transformation is already in progress")
            return
        }

        // Check API key
        guard settingsManager.isConfigured else {
            showNotification(title: "QPhrase", body: "Please configure your API key in settings")
            return
        }

        // Capture cursor position before text selection
        let cursorLocation = NSEvent.mouseLocation

        isTransforming = true
        defer { isTransforming = false }

        // Save original clipboard before any operations
        let originalClipboard = NSPasteboard.general.string(forType: .string)

        // Get selected text
        guard let selectedText = await getSelectedText(), !selectedText.isEmpty else {
            restoreClipboard(originalClipboard)
            showNotification(title: "QPhrase", body: "No text selected")
            return
        }

        // Show overlay at cursor location with starting state
        SparkleOverlayManager.shared.showOverlay(
            at: cursorLocation,
            state: .starting,
            enabled: settingsManager.showOverlayEffects
        )

        // Show processing indicator in menu bar
        NotificationCenter.default.post(name: .processingStarted, object: nil)

        defer {
            NotificationCenter.default.post(name: .processingFinished, object: nil)
        }

        do {
            let result = try await AIService.shared.transform(
                text: selectedText,
                prompt: prompt,
                settings: settingsManager
            )

            // Check if preview is enabled
            let finalText: String
            if settingsManager.showPreview {
                // Show preview and wait for user decision
                finalText = await showPreviewAndWait(
                    original: selectedText,
                    transformed: result,
                    prompt: prompt
                )
                // If user rejected, finalText will be empty
                guard !finalText.isEmpty else {
                    // Restore original clipboard on rejection
                    restoreClipboard(originalClipboard)
                    return
                }
            } else {
                finalText = result
            }

            // Record transformation for history/undo
            TransformationHistory.shared.addRecord(
                promptName: prompt.name,
                promptIcon: prompt.icon,
                original: selectedText,
                transformed: finalText
            )

            // Replace selected text with final text (potentially edited by user)
            replaceSelectedText(with: finalText, originalClipboard: originalClipboard)

            // Notify of successful transformation
            NotificationCenter.default.post(
                name: .transformationCompleted,
                object: TransformationHistory.shared.mostRecent
            )

            // Play sound
            if settingsManager.playSound {
                NSSound(named: .init("Tink"))?.play()
            }

        } catch {
            // Restore original clipboard on error
            restoreClipboard(originalClipboard)

            // Notify error for overlay
            NotificationCenter.default.post(name: .transformationError, object: nil)

            showNotification(title: "QPhrase Error", body: error.localizedDescription)
            if settingsManager.playSound {
                NSSound(named: .init("Basso"))?.play()
            }
        }
    }

    /// Show preview window and wait for user decision (with 5 minute timeout)
    @MainActor
    private func showPreviewAndWait(
        original: String,
        transformed: String,
        prompt: Prompt
    ) async -> String {
        guard let appDelegate = self.appDelegate else {
            return ""
        }

        return await withTaskGroup(of: String.self) { group in
            // Add the preview task
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    appDelegate.showPreview(
                        original: original,
                        transformed: transformed,
                        prompt: prompt
                    ) { editedText in
                        continuation.resume(returning: editedText ?? "")
                    }
                }
            }

            // Add timeout task (5 minutes)
            group.addTask {
                try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)
                return ""
            }

            // Return whichever finishes first
            let result = await group.next() ?? ""
            group.cancelAll()
            return result
        }
    }

    /// Test a prompt with provided text (for settings preview)
    @MainActor
    func testPrompt(_ prompt: Prompt, with text: String) async throws -> String {
        guard settingsManager.isConfigured else {
            throw AIError.noAPIKey
        }

        return try await AIService.shared.transform(
            text: text,
            prompt: prompt,
            settings: settingsManager
        )
    }

    private func getSelectedText() async -> String? {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        pasteboard.clearContents()

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDownC = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUpC = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDownC?.flags = .maskCommand
        keyUpC?.flags = .maskCommand

        keyDownC?.post(tap: .cghidEventTap)
        keyUpC?.post(tap: .cghidEventTap)

        // Wait for pasteboard to update with retry logic
        var selectedText: String?
        let maxAttempts = 10
        let delayPerAttempt: UInt64 = 50_000_000 // 50ms

        for _ in 0..<maxAttempts {
            try? await Task.sleep(nanoseconds: delayPerAttempt)

            // Check if pasteboard changed
            if pasteboard.changeCount != previousChangeCount {
                selectedText = pasteboard.string(forType: .string)
                if selectedText != nil && !selectedText!.isEmpty {
                    break
                }
            }
        }

        // Restore previous pasteboard contents if we got nothing
        if selectedText == nil || selectedText?.isEmpty == true {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }

        return selectedText
    }

    private func restoreClipboard(_ content: String?) {
        guard let content = content else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    private func replaceSelectedText(with text: String, originalClipboard: String?) {
        let pasteboard = NSPasteboard.general

        // Put new text in pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDownV = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUpV = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDownV?.flags = .maskCommand
        keyUpV?.flags = .maskCommand

        keyDownV?.post(tap: .cghidEventTap)
        keyUpV?.post(tap: .cghidEventTap)

        // Restore original clipboard after paste completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let original = originalClipboard {
                pasteboard.clearContents()
                pasteboard.setString(original, forType: .string)
            }
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
