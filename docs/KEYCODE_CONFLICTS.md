# macOS KeyCode Conflicts and Shortcut Registration Issues

## Overview

When using `RegisterEventHotKey` on macOS to register global keyboard shortcuts, certain keyCode combinations may fail to register or be intercepted by the system/other applications before reaching your app. This document outlines known issues and workarounds.

## Common KeyCode Issues

### System Reserved or Conflicting KeyCodes

Based on testing with TextEnhancer, certain keyCodes appear to be problematic:

**Potentially Problematic KeyCodes:**
- `24` (7 key) - Often captured by system or other apps
- `25` (8 key) - Often captured by system or other apps
- Various others depending on system configuration

**Generally Reliable KeyCodes:**
- `18` (1 key) - Usually works
- `19` (2 key) - Usually works  
- `20` (3 key) - Usually works
- `21` (4 key) - Usually works
- `22` (5 key) - Usually works
- `23` (6 key) - Usually works
- `26` (9 key) - Usually works
- `29` (0 key) - Usually works

## macOS System Changes

### macOS Sequoia (15.0) Breaking Changes

Apple introduced security restrictions in macOS 15 that affect keyboard shortcut registration:

- **Option + Shift combinations now fail** with error `-9868` (`eventInternalErr`)
- This was intentional to prevent key-logging malware from observing password characters
- Option + Shift can generate alternate characters (e.g., Ø from Shift+Option+O)
- **Workaround**: Use Command+Option, Control+Option, or other modifier combinations

### Known System Conflicts

1. **CMD+Tab**: Reserved for application switching, cannot be captured
2. **Various Option combinations**: May conflict with character input methods
3. **Accessibility shortcuts**: Check System Preferences > Keyboard > Shortcuts

## Debugging Shortcut Registration

### Symptoms of Registration Failure

1. **Key press prints the character**: Shortcut not registered at all
2. **No response**: Shortcut registered but intercepted by another app
3. **Delayed/inconsistent response**: Conflict with system shortcuts

### Debugging Steps

1. **Check registration logs**: Look for "✅ Registered shortcut" vs "❌ Failed to register"
2. **Test with different keyCodes**: Try adjacent keys to isolate the problem
3. **Check system shortcuts**: System Preferences > Keyboard > Shortcuts
4. **Test other modifier combinations**: Try Command+Option instead of Control+Option

## Best Practices

### Choosing Reliable KeyCodes

1. **Test on multiple systems**: KeyCode conflicts vary by macOS version and installed apps
2. **Use number keys (1-6, 9-0)**: Generally more reliable than 7-8
3. **Avoid system shortcut ranges**: Some keyCode ranges are more prone to conflicts
4. **Provide configuration options**: Let users customize shortcuts if conflicts occur

### Modifier Key Guidelines

1. **Use multiple modifiers**: Control+Option is generally safer than Option alone
2. **Avoid Option+Shift**: Broken in macOS 15+ for security reasons
3. **Consider Command+Option**: Less likely to conflict with text input
4. **Test Control+Shift**: Alternative to Option-based combinations

### Code Implementation

```swift
// Good: Multiple modifiers, reliable keyCode
let shortcut = ShortcutConfiguration(
    keyCode: 22, // 5 key - generally reliable
    modifiers: [.control, .option],
    // ...
)

// Problematic: Single modifier, unreliable keyCode
let badShortcut = ShortcutConfiguration(
    keyCode: 24, // 7 key - often conflicts
    modifiers: [.option], // Single modifier more likely to conflict
    // ...
)
```

## Error Handling

### RegisterEventHotKey Error Codes

- `-9868` (`eventInternalErr`): System security restriction (macOS 15+)
- `-9879` (`eventAlreadyPostedErr`): KeyCode already registered by another app
- `noErr` (0): Success

### Fallback Strategies

1. **Try alternative keyCodes**: If registration fails, try nearby keys
2. **Offer configuration UI**: Let users choose their own shortcuts
3. **Graceful degradation**: Provide menu-based alternatives
4. **Log conflicts**: Help users identify conflicting applications

## Testing Matrix

When adding new shortcuts, test these combinations:

| KeyCode | Key | Control+Option | Command+Option | Notes |
|---------|-----|----------------|----------------|-------|
| 18 | 1 | ✅ Reliable | ✅ Reliable | Good choice |
| 19 | 2 | ✅ Reliable | ✅ Reliable | Good choice |
| 20 | 3 | ✅ Reliable | ✅ Reliable | Good choice |
| 21 | 4 | ✅ Reliable | ✅ Reliable | Good choice |
| 22 | 5 | ✅ Reliable | ✅ Reliable | Good choice |
| 23 | 6 | ✅ Reliable | ✅ Reliable | Good choice |
| 24 | 7 | ⚠️ Conflicts | ⚠️ Conflicts | Avoid |
| 25 | 8 | ⚠️ Conflicts | ⚠️ Conflicts | Avoid |
| 26 | 9 | ✅ Reliable | ✅ Reliable | Good choice |
| 29 | 0 | ✅ Reliable | ✅ Reliable | Good choice |

## Resources

- [Apple's Keyboard Shortcuts Documentation](https://support.apple.com/en-us/102650)
- [macOS Virtual Key Codes](https://stackoverflow.com/questions/3202629/where-can-i-find-a-list-of-mac-virtual-key-codes)
- [RegisterEventHotKey Issues on GitHub](https://github.com/feedback-assistant/reports/issues/552)