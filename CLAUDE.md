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
MenuBarView.swift         Quick access menu from status bar
SettingsView.swift        Tabbed settings (General, API, Prompts)
    ↓
AIService.swift           Singleton handling OpenAI/Anthropic/Groq/Gemini API calls
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

**Global Hotkeys**: Uses Carbon Events framework (`RegisterEventHotKey`). Only registered hotkeys are intercepted; all other keyboard shortcuts pass through normally.

**API Keys**: Stored in macOS Keychain under service `com.qphrase.api` with accounts "openai", "anthropic", "groq", and "gemini". Never store API keys in UserDefaults or code.

**Prompts**: JSON-encoded in UserDefaults key `QPhrase.Prompts`. Each prompt has optional `HotkeyConfig` with keyCode and modifiers.

**App Behavior**: LSUIElement=true (no dock icon), runs as menu bar accessory app.

## Source Files

All source in `QPhrase/`:
- `QPhraseApp.swift` - App entry, AppDelegate, menu bar setup
- `AIService.swift` - API calls (callOpenAI, callAnthropic methods)
- `HotkeyManager.swift` - Carbon event handlers, keyboard simulation
- `PromptManager.swift` - Prompt model and persistence
- `SettingsManager.swift` - Settings + Keychain access
- `MenuBarView.swift` - Status bar popover UI
- `SettingsView.swift` - Full settings interface

## Supported AI Models

OpenAI: gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo
Anthropic: claude-sonnet-4-20250514, claude-3-5-haiku-20241022, claude-3-opus-20240229
Groq: llama-3.3-70b-versatile, llama-3.1-8b-instant, mixtral-8x7b-32768, gemma2-9b-it
Gemini: gemini-2.0-flash-exp, gemini-1.5-pro, gemini-1.5-flash

## Testing

No automated tests. Manual testing required:
- Hotkey registration/triggering in various apps
- API calls with both providers
- Text selection and replacement accuracy
- Accessibility permission flow
