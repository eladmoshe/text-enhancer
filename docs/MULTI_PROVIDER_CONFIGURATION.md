# Multi-Provider Configuration Guide

TextEnhancer supports multiple AI providers (Claude and OpenAI) with per-shortcut provider selection and vision capabilities for screenshot analysis.

## Configuration Structure

### Basic Configuration

```json
{
  "claudeApiKey": "sk-ant-api03-...",
  "shortcuts": [
    {
      "id": "improve-text",
      "name": "Improve Text",
      "keyCode": 18,
      "modifiers": ["ctrl", "opt"],
      "prompt": "Improve the writing quality and clarity of this text.",
      "provider": "claude"
    }
  ],
  "apiProviders": {
    "claude": {
      "apiKey": "sk-ant-api03-...",
      "model": "claude-3-haiku-20240307",
      "enabled": true
    },
    "openai": {
      "apiKey": "sk-proj-...",
      "model": "gpt-4-turbo-preview",
      "enabled": true
    }
  }
}
```

### Shortcut Configuration

Each shortcut can specify:
- `provider`: Which AI provider to use (`"claude"` or `"openai"`)
- `includeScreenshot`: Whether to capture and send a screenshot (`true` or `false`)

#### Text-only Shortcuts
```json
{
  "id": "summarize",
  "name": "Summarize",
  "keyCode": 21,
  "modifiers": ["ctrl", "opt"],
  "prompt": "Provide a concise summary of this text.",
  "provider": "openai"
}
```

#### Screenshot-only Shortcuts
```json
{
  "id": "describe-screen",
  "name": "Describe Screen",
  "keyCode": 23,
  "modifiers": ["ctrl", "opt"],
  "prompt": "Describe what you see in this screenshot.",
  "provider": "claude",
  "includeScreenshot": true
}
```

#### Combined Text + Screenshot Shortcuts
```json
{
  "id": "analyze-with-context",
  "name": "Analyze with Context",
  "keyCode": 19,
  "modifiers": ["ctrl", "opt"],
  "prompt": "Analyze this text considering the visual context from the screenshot.",
  "provider": "claude",
  "includeScreenshot": true
}
```

## API Provider Configuration

### Claude Configuration
```json
"claude": {
  "apiKey": "sk-ant-api03-...",
  "model": "claude-3-haiku-20240307",
  "enabled": true
}
```

**Supported Models:**
- `claude-3-haiku-20240307` (fast, cost-effective)
- `claude-3-sonnet-20240229` (balanced)
- `claude-3-opus-20240229` (most capable)

### OpenAI Configuration
```json
"openai": {
  "apiKey": "sk-proj-...",
  "model": "gpt-4-turbo-preview",
  "enabled": true
}
```

**Supported Models:**
- `gpt-3.5-turbo` (text-only)
- `gpt-4-turbo-preview` (text + vision)
- `gpt-4-vision-preview` (vision-optimized)

## Vision/Screenshot Support

### Requirements
- **Claude**: All Claude-3 models support vision
- **OpenAI**: Requires `gpt-4-vision-preview` or `gpt-4-turbo-preview`

### Permissions
Screenshot functionality requires:
1. **Accessibility permissions** (for all shortcuts)
2. **Screen Recording permissions** (for screenshot shortcuts)

### Usage Examples

#### Screenshot Description (Claude)
- **Shortcut**: Ctrl+Option+6
- **Usage**: Press shortcut without selecting text
- **Result**: Captures screen and gets description from Claude

#### Screenshot Analysis (OpenAI)
- **Shortcut**: Ctrl+Option+7
- **Usage**: Press shortcut without selecting text
- **Result**: Captures screen and gets analysis from OpenAI

#### Text with Visual Context
- **Shortcut**: Ctrl+Option+2 (with `includeScreenshot: true`)
- **Usage**: Select text, then press shortcut
- **Result**: Sends both selected text and screenshot to AI

## Key Code Reference

Common key codes for shortcuts:
- `18`: Key "1" → Ctrl+Option+1
- `19`: Key "2" → Ctrl+Option+2  
- `20`: Key "3" → Ctrl+Option+3
- `21`: Key "4" → Ctrl+Option+4
- `22`: Key "5" → Ctrl+Option+5
- `23`: Key "6" → Ctrl+Option+6
- `24`: Key "7" → Ctrl+Option+7
- `25`: Key "8" → Ctrl+Option+8

## Example Configuration

See `config-example-with-screenshots.json` for a complete working example with:
- Mixed provider shortcuts (Claude + OpenAI)
- Screenshot-only shortcuts
- Text-only shortcuts
- Combined text + screenshot shortcuts

## Troubleshooting

### Provider Not Working
1. Check API key is valid and not empty
2. Verify `enabled: true` in provider configuration
3. Check shortcut `provider` field matches provider name

### Screenshot Not Working
1. Grant Screen Recording permissions in System Settings
2. Use vision-capable models (Claude-3 or GPT-4 Vision)
3. Check `includeScreenshot: true` in shortcut configuration

### Debug Logging
Set `"logLevel": "debug"` to see detailed provider and screenshot logs.