import Foundation
import Carbon
import AppKit
import UserNotifications

class HotkeyManager {
    private var promptManager: PromptManager
    private var settingsManager: SettingsManager
    private var eventHandler: EventHandlerRef?
    private var registeredHotkeys: [EventHotKeyRef] = []
    private var hotkeyIDToPrompt: [UInt32: UUID] = [:]
    private var nextHotkeyID: UInt32 = 1
    
    init(promptManager: PromptManager, settingsManager: SettingsManager) {
        self.promptManager = promptManager
        self.settingsManager = settingsManager
        setupEventHandler()
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
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
        
        for prompt in promptManager.prompts where prompt.isEnabled {
            if let hotkey = prompt.hotkey {
                registerHotkey(for: prompt, config: hotkey)
            }
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
        }
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
        // Check API key
        guard settingsManager.isConfigured else {
            showNotification(title: "QuickRephrase", body: "Please configure your API key in settings")
            return
        }
        
        // Get selected text
        guard let selectedText = getSelectedText(), !selectedText.isEmpty else {
            showNotification(title: "QuickRephrase", body: "No text selected")
            return
        }
        
        // Show processing indicator
        if settingsManager.showNotifications {
            showNotification(title: "QuickRephrase", body: "Processing with \(prompt.name)...")
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
            showNotification(title: "QuickRephrase Error", body: error.localizedDescription)
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
