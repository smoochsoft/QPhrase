import Foundation
import Carbon
import AppKit
import UserNotifications

class HotkeyManager {
    private var promptManager: PromptManager
    private var settingsManager: SettingsManager
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var registeredHotkeys: [(keyCode: UInt32, modifiers: UInt32, promptID: UUID)] = []
    private(set) var conflictingPromptIDs: Set<UUID> = []

    init(promptManager: PromptManager, settingsManager: SettingsManager) {
        self.promptManager = promptManager
        self.settingsManager = settingsManager
        setupEventTap()

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    deinit {
        removeEventTap()
    }

    private func setupEventTap() {
        // Create event tap that listens for key down events
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        // Store self reference for the callback
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: userInfo
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap - accessibility permissions may be required")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func removeEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // If tap is disabled (system safety), re-enable it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap = eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Only process key down events
        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Convert CGEventFlags to Carbon modifier format
        var carbonModifiers: UInt32 = 0
        if flags.contains(.maskCommand) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.maskShift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.maskControl) { carbonModifiers |= UInt32(controlKey) }

        // Check if this key combination matches any of our registered hotkeys
        for hotkey in registeredHotkeys {
            if hotkey.keyCode == keyCode && hotkey.modifiers == carbonModifiers {
                // Found a matching hotkey - execute the prompt and consume the event
                if let prompt = promptManager.prompts.first(where: { $0.id == hotkey.promptID && $0.isEnabled }) {
                    Task { @MainActor in
                        await self.executePrompt(prompt)
                    }
                    // Return nil to consume the event (prevent it from reaching other apps)
                    return nil
                }
            }
        }

        // Not our hotkey - pass the event through unchanged
        return Unmanaged.passUnretained(event)
    }

    func registerAllHotkeys() {
        registeredHotkeys.removeAll()
        conflictingPromptIDs.removeAll()

        // Track which key combinations have been registered to detect duplicates
        var seenCombinations: Set<String> = []

        for prompt in promptManager.prompts where prompt.isEnabled {
            if let hotkey = prompt.hotkey {
                let comboKey = "\(hotkey.keyCode)-\(hotkey.modifiers)"

                if seenCombinations.contains(comboKey) {
                    // Duplicate hotkey within our app
                    conflictingPromptIDs.insert(prompt.id)
                } else {
                    seenCombinations.insert(comboKey)
                    registeredHotkeys.append((
                        keyCode: hotkey.keyCode,
                        modifiers: hotkey.modifiers,
                        promptID: prompt.id
                    ))
                }
            }
        }

        // Post notification if there are conflicts
        if !conflictingPromptIDs.isEmpty {
            NotificationCenter.default.post(name: .hotkeyConflictDetected, object: conflictingPromptIDs)
        }
    }

    /// Test if a hotkey can be registered (for UI validation)
    func testHotkeyAvailability(_ config: HotkeyConfig) -> Bool {
        // Check if this combination is already registered
        for hotkey in registeredHotkeys {
            if hotkey.keyCode == config.keyCode && hotkey.modifiers == config.modifiers {
                return false
            }
        }
        return true
    }

    @MainActor
    private func executePrompt(_ prompt: Prompt) async {
        // Check API key
        guard settingsManager.isConfigured else {
            showNotification(title: "QPhrase", body: "Please configure your API key in settings")
            return
        }

        // Get selected text
        guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
            showNotification(title: "QPhrase", body: "No text selected")
            return
        }

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

            // Replace selected text with result
            replaceSelectedText(with: result)

            // Play sound
            if settingsManager.playSound {
                NSSound(named: .init("Tink"))?.play()
            }

        } catch {
            showNotification(title: "QPhrase Error", body: error.localizedDescription)
            if settingsManager.playSound {
                NSSound(named: .init("Basso"))?.play()
            }
        }
    }

    private func getSelectedText() -> String? {
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

        // Wait for pasteboard to update
        Thread.sleep(forTimeInterval: 0.1)

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

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
