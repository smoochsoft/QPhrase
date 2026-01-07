import Foundation
import Carbon
import AppKit
import UserNotifications

class HotkeyManager {
    private var promptManager: PromptManager
    private var settingsManager: SettingsManager
    private var historyManager: HistoryManager?
    private var eventHandler: EventHandlerRef?
    private var registeredHotkeys: [EventHotKeyRef] = []
    private var hotkeyIDToPrompt: [UInt32: UUID] = [:]
    private var nextHotkeyID: UInt32 = 1
    private(set) var conflictingPromptIDs: Set<UUID> = []
    private var isProcessing = false  // Prevents rapid-fire API calls

    init(promptManager: PromptManager, settingsManager: SettingsManager, historyManager: HistoryManager? = nil) {
        self.promptManager = promptManager
        self.settingsManager = settingsManager
        self.historyManager = historyManager
        setupEventHandler()

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func setHistoryManager(_ manager: HistoryManager) {
        self.historyManager = manager
    }

    deinit {
        unregisterAllHotkeys()
    }

    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerCallback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleHotkey(event: event!)
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
            // Hotkey registration failed - likely a conflict
            conflictingPromptIDs.insert(prompt.id)
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

    @MainActor
    private func executePrompt(_ prompt: Prompt) async {
        // Prevent rapid-fire API calls
        guard !isProcessing else {
            return
        }
        isProcessing = true

        defer {
            isProcessing = false
        }

        // Check API key
        guard settingsManager.isConfigured else {
            NotificationCenter.default.post(
                name: .transformError,
                object: nil,
                userInfo: ["title": "No API Key", "details": "Please configure your API key in settings"]
            )
            return
        }

        // Get selected text
        guard let selectedText = await getSelectedText(), !selectedText.isEmpty else {
            NotificationCenter.default.post(
                name: .transformError,
                object: nil,
                userInfo: ["title": "No Text Selected", "details": "Select some text before using the hotkey"]
            )
            return
        }

        // Show processing indicator in menu bar
        NotificationCenter.default.post(name: .processingStarted, object: nil)

        do {
            let result = try await AIService.shared.transform(
                text: selectedText,
                prompt: prompt,
                settings: settingsManager
            )

            // Replace selected text with result
            replaceSelectedText(with: result)

            // Add to history
            historyManager?.addEntry(
                promptName: prompt.name,
                promptID: prompt.id,
                originalText: selectedText,
                transformedText: result
            )

            // Post success notification
            NotificationCenter.default.post(
                name: .transformSuccess,
                object: nil,
                userInfo: ["promptName": prompt.name]
            )

            // Play sound
            if settingsManager.playSound {
                SoundManager.shared.playSuccess()
            }

        } catch {
            // Post error notification
            NotificationCenter.default.post(
                name: .transformError,
                object: nil,
                userInfo: ["title": "Transform Failed", "details": error.localizedDescription]
            )

            if settingsManager.playSound {
                SoundManager.shared.playError()
            }
        }
    }

    /// Execute a prompt with provided text (for manual triggering from popover)
    @MainActor
    func executePromptWithText(_ prompt: Prompt, text: String) async {
        guard !isProcessing else { return }
        isProcessing = true

        defer {
            isProcessing = false
        }

        guard settingsManager.isConfigured else {
            NotificationCenter.default.post(
                name: .transformError,
                object: nil,
                userInfo: ["title": "No API Key", "details": "Please configure your API key in settings"]
            )
            return
        }

        NotificationCenter.default.post(name: .processingStarted, object: nil)

        do {
            let result = try await AIService.shared.transform(
                text: text,
                prompt: prompt,
                settings: settingsManager
            )

            // Copy result to clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(result, forType: .string)

            // Add to history
            historyManager?.addEntry(
                promptName: prompt.name,
                promptID: prompt.id,
                originalText: text,
                transformedText: result
            )

            NotificationCenter.default.post(
                name: .transformSuccess,
                object: nil,
                userInfo: ["promptName": prompt.name, "copiedToClipboard": true]
            )

            if settingsManager.playSound {
                SoundManager.shared.playSuccess()
            }

        } catch {
            NotificationCenter.default.post(
                name: .transformError,
                object: nil,
                userInfo: ["title": "Transform Failed", "details": error.localizedDescription]
            )

            if settingsManager.playSound {
                SoundManager.shared.playError()
            }
        }
    }

    private func getSelectedText() async -> String? {
        // Copy selected text to pasteboard
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()

        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDownC = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUpC = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyDownC?.flags = .maskCommand
        keyUpC?.flags = .maskCommand

        keyDownC?.post(tap: .cghidEventTap)
        keyUpC?.post(tap: .cghidEventTap)

        // Wait for pasteboard to update (non-blocking)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        let selectedText = pasteboard.string(forType: .string)

        // Restore previous pasteboard contents if we got nothing
        if selectedText == nil || selectedText?.isEmpty == true {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }

        return selectedText
    }

    private func replaceSelectedText(with text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

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

        // Restore previous pasteboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

}
