# TextEnhancer Configuration

TextEnhancer now uses JSON-based configuration instead of a settings UI. This provides more flexibility and allows for version control of your configuration.

## Configuration Files

### `config.json` (Your Configuration)
- **Location**: Root directory of the project
- **Purpose**: Your personal configuration with API keys and custom settings
- **Git Status**: Excluded from version control (private)
- **Required**: Yes, you must create this file

### `config.example.json` (Example Configuration)
- **Location**: Root directory of the project  
- **Purpose**: Example showing all available configuration options
- **Git Status**: Committed to version control (public)
- **Required**: No, this is just a reference

## Getting Started

1. **Copy the example configuration**:
   ```bash
   cp config.example.json config.json
   ```

2. **Edit your configuration**:
   - Open `config.json` in your preferred editor
   - Add your Claude API key to the `claudeApiKey` field
   - Customize shortcuts, prompts, and other settings as needed

3. **Run the app**:
   ```bash
   swift build && .build/debug/TextEnhancer
   ```

## Configuration Options

### Core Settings
- `claudeApiKey`: Your Claude API key from Anthropic
- `maxTokens`: Maximum tokens per API request (default: 1000)
- `timeout`: Request timeout in seconds (default: 30.0)

### UI Settings
- `showStatusIcon`: Show/hide the menu bar icon (default: true)
- `enableNotifications`: Enable system notifications (default: true)
- `logLevel`: Logging level ("debug", "info", "warning", "error")

### Shortcuts
Each shortcut has:
- `id`: Unique identifier
- `name`: Display name
- `keyCode`: Key code (18 = "1", 19 = "2", etc.)
- `modifiers`: Array of modifiers (["ctrl", "opt", "cmd", "shift"])
- `prompt`: The prompt sent to Claude

### Example Custom Shortcut
```json
{
  "id": "make-professional",
  "name": "Make Professional",
  "keyCode": 19,
  "modifiers": ["ctrl", "opt"],
  "prompt": "Rewrite this text in a professional, business-appropriate tone."
}
```

## Key Codes Reference
- 18 = "1"
- 19 = "2" 
- 20 = "3"
- 21 = "4"
- 22 = "5"
- 23 = "6"
- 24 = "7"
- 25 = "8"
- 26 = "9"
- 29 = "0"

## Modifier Keys
- `"ctrl"` = Control (⌃)
- `"opt"` = Option (⌥)
- `"cmd"` = Command (⌘)
- `"shift"` = Shift (⇧)

## Troubleshooting

### App won't start
- Check that `config.json` exists
- Verify JSON syntax is valid
- Check console output for error messages

### Shortcuts not working
- Ensure key codes are correct
- Check that modifiers are spelled correctly
- Verify you have accessibility permissions

### API calls failing
- Check your Claude API key is valid
- Verify you have API credits
- Check internet connection

## Live Configuration Updates

The app loads configuration at startup. To apply changes:
1. Edit `config.json`
2. Quit and restart the app

## Security Notes

- `config.json` contains your API key and is excluded from git
- Never commit your actual API key to version control
- Keep your API key secure and don't share it 