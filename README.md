# QPhrase

A lightweight macOS menu bar app that lets you transform text anywhere using AI. Select text in any app, press a hotkey, and instantly get rephrased/corrected text.

![QPhrase](screenshot.png)

## Features

- **Works Everywhere** - Slack, Gmail, Notion, VS Code, any app where you can select text
- **Custom Prompts** - Create your own text transformations (fix grammar, make professional, summarize, etc.)
- **Global Hotkeys** - Assign keyboard shortcuts to each prompt
- **Multiple AI Providers** - Choose between OpenAI, Anthropic, Groq, or Google Gemini
- **Privacy First** - Your API key stays on your Mac (stored in Keychain)
- **Menu Bar App** - Lives quietly in your menu bar, always ready

## How It Works

1. Select text in any application
2. Press your assigned hotkey (e.g., ⌘⇧G for "Fix Grammar")
3. The app copies your selection, sends it to the AI, and pastes the result back
4. Done! The corrected text replaces your selection

## Installation

### From Source (Xcode Required)

1. Clone or download this repository
2. Open `QPhrase.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Build and run (⌘R)
5. The app will appear in your menu bar

### First Run Setup

1. **Grant Accessibility Permissions**
   - When prompted, go to System Settings → Privacy & Security → Accessibility
   - Enable QPhrase
   - This allows the app to read selected text and paste results

2. **Configure API Key**
   - Click the menu bar icon → Settings (gear icon) → API tab
   - Enter your OpenAI or Anthropic API key
   - Select your preferred model

## Default Prompts & Hotkeys

| Prompt | Hotkey | Description |
|--------|--------|-------------|
| Fix Grammar | ⌘⇧G | Fixes spelling, grammar, punctuation |
| Make Professional | ⌘⇧P | Rewrites in a polished, professional tone |
| Make Concise | ⌘⇧C | Shortens while keeping key points |
| Make Friendly | ⌘⇧F | Rewrites in a casual, friendly tone |
| Expand | ⌘⇧E | Adds more detail and explanation |

## Creating Custom Prompts

1. Click the menu bar icon → Settings → Prompts tab
2. Click the `+` button
3. Enter:
   - **Name**: What to call this prompt
   - **Instruction**: The AI instruction (e.g., "Translate to Spanish")
   - **Hotkey**: Click "Record" and press your key combination
4. Click Save

### Example Custom Prompts

| Name | Instruction |
|------|-------------|
| Translate to Spanish | Translate the following text to Spanish. Only output the translation, nothing else. |
| ELI5 | Explain the following text as if explaining to a 5-year-old. Keep it simple and fun. |
| Add Emojis | Add relevant emojis throughout the text to make it more engaging. Only output the text with emojis. |
| Technical | Rewrite the following text to be more technical and precise. Use industry terminology. |
| Pirate | Rewrite the following text as if spoken by a pirate. Arrr! |

## Settings

Settings are organized into three tabs: **General → API → Prompts**

### General
- **Notifications**: Show/hide processing notifications
- **Sounds**: Enable/disable completion sounds
- **Launch at Login**: Start with macOS

### API
- **Provider**: Segmented picker to switch between OpenAI, Anthropic, Groq, or Gemini
- **Model**: Choose from available models for the selected provider
- **API Key**: Only shows the key field for your selected provider (stored in macOS Keychain)

### Prompts
- View and manage your text transformation prompts
- Assign global hotkeys to each prompt
- Enable/disable prompts as needed

## Troubleshooting

### "No text selected" error
- Make sure you have text highlighted before pressing the hotkey
- Some apps may not support standard copy/paste - try a different app

### Hotkeys not working
- Check that the app has Accessibility permissions in System Settings
- Make sure the hotkey isn't conflicting with another app
- Try re-recording the hotkey

### API errors
- Verify your API key is correct
- Check that you have credits/quota with your AI provider
- Try a different model

## Requirements

- macOS 13.0 (Ventura) or later
- API key from at least one provider: OpenAI, Anthropic, Groq, or Google Gemini

## Getting API Keys

### OpenAI
1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Create a new API key
3. Add credits to your account

### Anthropic
1. Go to [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
2. Create a new API key
3. Add credits to your account

### Groq
1. Go to [console.groq.com/keys](https://console.groq.com/keys)
2. Create a new API key
3. Free tier available with rate limits

### Google Gemini
1. Go to [aistudio.google.com/apikey](https://aistudio.google.com/apikey)
2. Create a new API key
3. Free tier available with rate limits

## Privacy

- API keys are stored securely in your macOS Keychain
- Text is sent directly to your chosen AI provider - not through any other servers
- No data is collected or stored by this app

## Tech Stack

- SwiftUI for the interface
- CGEventTap for global hotkey interception
- Security framework for Keychain storage
- URLSession for API calls

## License

MIT License - feel free to use, modify, and distribute.

---

Built as an alternative to [Rephrase](https://www.rephrase.space/) and [FridayGPT](https://www.fridaygpt.app/) - simple tools that do one thing well.
