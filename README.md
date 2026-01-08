# QPhrase

A lightweight macOS menu bar app that lets you transform text anywhere using AI. Select text in any app, press a hotkey, and instantly get rephrased/corrected text.

## Features

- **Works Everywhere** - Slack, Gmail, Notion, VS Code, any app where you can select text
- **Custom Prompts** - Create your own text transformations (fix grammar, make professional, summarize, etc.)
- **Global Hotkeys** - Assign keyboard shortcuts to each prompt
- **Click-to-Run** - Run prompts directly from the menu bar without hotkeys
- **Multiple AI Providers** - Choose between OpenAI, Anthropic, Groq, or Google Gemini
- **Custom Models** - Add new models as they become available
- **Preview with Diff** - See changes highlighted character-by-character before applying, with editable result
- **Transformation History** - Review recent transformations and copy original text back
- **Visual Feedback** - Optional sparkle overlay effects at cursor during transformations
- **Hotkey Conflict Detection** - Warnings when shortcuts conflict with system or other apps
- **Privacy First** - Your API key stays on your Mac (stored in Keychain)
- **Menu Bar App** - Lives quietly in your menu bar, always ready

## How It Works

1. Select text in any application
2. Press your assigned hotkey (e.g., ⌘⇧G for "Fix Grammar") or click a prompt in the menu bar
3. The app copies your selection, sends it to the AI, and pastes the result back
4. Done! The corrected text replaces your selection

## Installation

### From Source (Xcode Required)

1. Clone or download this repository
2. **Configure signing** (required):
   ```bash
   cp Config.xcconfig.template Config.local.xcconfig
   ```
   Edit `Config.local.xcconfig` and add your Development Team ID and Bundle Identifier:
   ```
   DEVELOPMENT_TEAM = YOUR_TEAM_ID
   PRODUCT_BUNDLE_IDENTIFIER = com.yourname.qphrase
   ```
   To find your Team ID: Xcode → Settings → Accounts → Select team → View Details
3. Open `QPhrase.xcodeproj` in Xcode
4. Build and run (⌘R)
5. The app will appear in your menu bar

### First Run Setup

1. **Grant Accessibility Permissions**
   - When prompted, go to System Settings → Privacy & Security → Accessibility
   - Enable QPhrase
   - This allows the app to read selected text and paste results

2. **Configure API Key**
   - Click the menu bar icon → Settings (gear icon) → Providers tab
   - Select your AI provider
   - Enter your API key
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
   - **Icon**: Choose an SF Symbol icon
   - **Instruction**: The AI instruction (e.g., "Translate to Spanish")
   - **Hotkey**: Click "Record" and press your key combination
4. Optionally test the prompt with sample text before saving
5. Click Save

### Example Custom Prompts

| Name | Instruction |
|------|-------------|
| Translate to Spanish | Translate the following text to Spanish. Only output the translation, nothing else. |
| ELI5 | Explain the following text as if explaining to a 5-year-old. Keep it simple and fun. |
| Add Emojis | Add relevant emojis throughout the text to make it more engaging. Only output the text with emojis. |
| Technical | Rewrite the following text to be more technical and precise. Use industry terminology. |
| Pirate | Rewrite the following text as if spoken by a pirate. Arrr! |

## Settings

Settings are organized into three tabs: **Preferences → Providers → Prompts**

### Preferences
- **Show notifications**: System notifications for processing status
- **Play sounds**: Audio feedback on completion/error
- **Show overlay effects**: Sparkle animations near cursor during transformations
- **Preview transformations**: Review and edit AI output before applying
- **Launch at login**: Start QPhrase with macOS

### Providers
- **Provider**: Select between OpenAI, Anthropic, Groq, or Gemini
- **Model**: Choose from available models (with speed indicators)
- **Manage Models**: Add custom models as new ones become available
- **API Key**: Securely stored in macOS Keychain
- **Test Connection**: Verify your API key works

### Prompts
- View and manage your text transformation prompts
- Assign global hotkeys to each prompt
- Enable/disable prompts with toggle switch
- Test prompts with sample text before saving

## Troubleshooting

### "No text selected" error
- Make sure you have text highlighted before pressing the hotkey
- Some apps may not support standard copy/paste - try a different app

### Hotkeys not working
- Check that the app has Accessibility permissions in System Settings
- Look for the warning icon (⚠️) next to prompts with conflicting hotkeys
- Make sure the hotkey isn't conflicting with system shortcuts
- Try re-recording the hotkey

### API errors
- Use the "Test Connection" button in Providers settings
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
- Clipboard is restored after each transformation

## Supported Models

### OpenAI (Responses API)
- gpt-4.1-nano, gpt-4.1-mini, gpt-5-nano, gpt-4.1, gpt-5-mini

### Anthropic
- claude-opus-4.5, claude-sonnet-4.5, claude-3.7-sonnet, claude-3-5-haiku-20241022

### Groq
- llama-3.3-70b-versatile, llama-4-scout-17b, gpt-oss-120b, qwen-qwq-32b, llama-3.1-8b-instant

### Google Gemini
- gemini-flash-lite-latest, gemini-flash-latest, gemini-2.5-flash, gemini-3-flash-preview, gemini-3-pro-preview

You can add custom models via Settings → Providers → Manage Models.

## Tech Stack

- SwiftUI for the interface
- Carbon Events API for global hotkey registration
- CGEvent for simulating copy/paste keystrokes
- Security framework for Keychain storage
- UserNotifications for system notifications
- URLSession for API calls

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Set up signing (see Installation)
4. Make your changes
5. Commit (`git commit -m 'Add amazing feature'`)
6. Push (`git push origin feature/amazing-feature`)
7. Open a Pull Request

Note: `Config.local.xcconfig` is gitignored - each contributor uses their own signing configuration.

## License

MIT License - feel free to use, modify, and distribute.

---

Built as an alternative to [Rephrase](https://www.rephrase.space/) and [FridayGPT](https://www.fridaygpt.app/) - simple tools that do one thing well.
