# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

QuickRephrase is a native macOS menu bar application that provides AI-powered text transformation using global hotkeys. Users select text in any application and press a hotkey to transform it via OpenAI or Anthropic APIs.

## Build & Run

```bash
# Open project in Xcode
open QuickRephrase.xcodeproj

# Build and run from Xcode
⌘R

# Command line build
xcodebuild -project QuickRephrase.xcodeproj -scheme QuickRephrase -configuration Release build
```

Requirements:
- macOS 13.0+ (Ventura)
- Xcode with Swift 5.0
- Apple Development Team configured for code signing
- Accessibility permissions (prompted on first run)

No external dependencies - uses only system frameworks.

## Architecture

```
QuickRephraseApp.swift    Entry point, AppDelegate manages menu bar popover lifecycle
    ↓
MenuBarView.swift         Quick access menu from status bar
SettingsView.swift        Tabbed settings (Prompts, API, General)
    ↓
AIService.swift           Singleton handling OpenAI/Anthropic API calls
HotkeyManager.swift       Global hotkey registration via Carbon Events
PromptManager.swift       Prompt CRUD with UserDefaults persistence
SettingsManager.swift     Configuration + Keychain for API keys
```

**Text transformation flow:**
1. User presses registered hotkey → HotkeyManager intercepts
2. Simulates Cmd+C to capture selected text
3. AIService calls configured provider API
4. Simulates Cmd+V to replace with transformed text
5. Original clipboard content restored

## Key Implementation Details

**Global Hotkeys**: Uses Carbon Events framework (kEventClassKeyboard). Key codes mapped in `HotkeyManager.swift:keyCodeToString`.

**API Keys**: Stored in macOS Keychain under service `com.quickrephrase.api` with accounts "openai" and "anthropic". Never store API keys in UserDefaults or code.

**Prompts**: JSON-encoded in UserDefaults key `QuickRephrase.Prompts`. Each prompt has optional `HotkeyConfig` with keyCode and modifiers.

**App Behavior**: LSUIElement=true (no dock icon), runs as menu bar accessory app.

## Source Files

All source in `QuickRephrase/`:
- `QuickRephraseApp.swift` - App entry, AppDelegate, menu bar setup
- `AIService.swift` - API calls (callOpenAI, callAnthropic methods)
- `HotkeyManager.swift` - Carbon event handlers, keyboard simulation
- `PromptManager.swift` - Prompt model and persistence
- `SettingsManager.swift` - Settings + Keychain access
- `MenuBarView.swift` - Status bar popover UI
- `SettingsView.swift` - Full settings interface

## Supported AI Models

OpenAI: gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo
Anthropic: claude-sonnet-4-20250514, claude-3-5-haiku-20241022, claude-3-opus-20240229

## Testing

No automated tests. Manual testing required:
- Hotkey registration/triggering in various apps
- API calls with both providers
- Text selection and replacement accuracy
- Accessibility permission flow
