# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QPhrase is a native macOS menu bar application that provides AI-powered text transformation using global hotkeys. Users select text in any application and press a hotkey to transform it via OpenAI, Anthropic, Groq, or Google Gemini APIs.

## Build & Run

```bash
# Open project in Xcode
open QPhrase.xcodeproj

# Build and run from Xcode
⌘R

# Command line build
xcodebuild -project QPhrase.xcodeproj -scheme QPhrase -configuration Release build
```

Requirements:
- macOS 13.0+ (Ventura)
- Xcode with Swift 5.0
- Apple Development Team configured for code signing
- Accessibility permissions (prompted on first run)

No external dependencies - uses only system frameworks.

## Architecture

```
QPhraseApp.swift    Entry point, AppDelegate manages menu bar popover lifecycle
    ↓
MenuBarView.swift         Tabbed popover (Prompts/History) with clickable prompts
SettingsView.swift        Tabbed settings (General, API, Prompts)
OnboardingView.swift      First-run setup wizard
    ↓
AIService.swift           Singleton handling OpenAI/Anthropic/Groq/Gemini API calls
HotkeyManager.swift       Global hotkey registration via Carbon Events
PromptManager.swift       Prompt CRUD with UserDefaults persistence
SettingsManager.swift     Configuration + Keychain for API keys
HistoryManager.swift      Transformation history with persistence
    ↓
ToastManager.swift        Floating toast notifications for feedback
SoundManager.swift        Audio feedback (system sounds)
PreviewManager.swift      Optional preview-before-apply window
```

**Text transformation flow:**
1. User presses registered hotkey → HotkeyManager intercepts
2. Simulates Cmd+C to capture selected text
3. AIService calls configured provider API
4. (Optional) If preview mode enabled, shows PreviewManager window for confirmation
5. Simulates Cmd+V to replace with transformed text
6. Entry added to HistoryManager
7. Toast notification shown, sound played
8. Original clipboard content restored

## Key Implementation Details

**Global Hotkeys**: Uses Carbon Events framework (`RegisterEventHotKey`). Only registered hotkeys are intercepted; all other keyboard shortcuts pass through normally. Hotkey signature is `0x51525048` ("QRPH").

**API Keys**: Stored in macOS Keychain under service `com.qphrase.api` with accounts "openai", "anthropic", "groq", and "gemini". Never store API keys in UserDefaults or code.

**Prompts**: JSON-encoded in UserDefaults key `QPhrase.Prompts`. Each prompt has optional `HotkeyConfig` with keyCode (Carbon virtual key) and modifiers (Carbon modifier flags).

**App Behavior**: LSUIElement=true (no dock icon), runs as menu bar accessory app.

**Internal Notifications**: Uses `NotificationCenter` for state:
- `.processingStarted` / `.processingFinished` - Toggles menu bar spinner
- `.transformSuccess` / `.transformError` - Triggers toast and sound feedback
- `.executePrompt` - Manual prompt execution from popover
- `.hotkeyConflictDetected` - Alerts when hotkey registration fails
- `.openSettings` / `.showHistory` - Navigation

**UserDefaults Keys**: `selectedProvider`, `selectedModel`, `showNotifications`, `playSound`, `showPreview`, `QPhrase.Prompts`, `QPhrase.History`

## Source Files

All source in `QPhrase/`:
- `QPhraseApp.swift` - App entry, AppDelegate, menu bar setup, animated icons
- `AIService.swift` - API calls (callOpenAI, callAnthropic methods)
- `HotkeyManager.swift` - Carbon event handlers, keyboard simulation
- `PromptManager.swift` - Prompt model and persistence
- `SettingsManager.swift` - Settings + Keychain access
- `MenuBarView.swift` - Tabbed popover UI (Prompts/History)
- `SettingsView.swift` - Full settings interface with provider cards
- `HistoryManager.swift` - Transformation history tracking
- `ToastManager.swift` - Floating toast notifications
- `SoundManager.swift` - Audio feedback using system sounds
- `PreviewManager.swift` - Preview-before-apply window
- `OnboardingView.swift` - First-run setup wizard

## Supported AI Models

Models are defined in `SettingsManager.AIProvider.models`. Current list:
- OpenAI: gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo
- Anthropic: claude-sonnet-4-20250514, claude-3-5-haiku-20241022, claude-3-opus-20240229
- Groq: llama-3.3-70b-versatile, llama-3.1-8b-instant, mixtral-8x7b-32768, gemma2-9b-it
- Gemini: gemini-2.0-flash-exp, gemini-1.5-pro, gemini-1.5-flash

## Testing

No automated tests. Manual testing required:
- Hotkey registration/triggering in various apps
- API calls with both providers
- Text selection and replacement accuracy
- Accessibility permission flow
