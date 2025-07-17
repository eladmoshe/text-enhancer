# Development vs Production Workflow

## Overview

TextEnhancer now uses a **bundled vs non-bundled** approach to separate development and production workflows, ensuring optimal permission handling.

## Key Concepts

### 🔧 Development (Non-bundled)
- **Command**: `./build.sh --run`
- **Purpose**: Active development and coding
- **Characteristics**:
  - Runs debug binary directly (`.build/debug/TextEnhancer`)
  - No app bundle created
  - Immediate code changes pickup
  - Permissions reset every time (expected for development)
  - Faster iteration cycle

### 🚀 Production (Bundled)
- **Commands**: 
  - `./build.sh --bundle` (unsigned bundle)
  - `./build.sh --bundle-signed` (signed bundle - RECOMMENDED)
- **Purpose**: Testing with persistent permissions, final releases
- **Characteristics**:
  - Creates proper macOS app bundle
  - Persistent permissions (especially with signed bundles)
  - Slower to rebuild but proper app behavior
  - Recommended for most testing scenarios

## Workflow Recommendations

### During Active Development
```bash
# Use this for rapid iteration and code changes
./build.sh --run
```

### For Permission Testing
```bash
# Use this for testing functionality that requires permissions
./build.sh --bundle-signed
```

### For Final Testing/Release
```bash
# Use this for final testing and deployment
./build.sh --bundle-signed
```

## Permission Behavior

| Version | Accessibility Permissions | Screen Recording Permissions |
|---------|--------------------------|------------------------------|
| Non-bundled (`--run`) | Reset every time | Reset every time |
| Bundled unsigned (`--bundle`) | Reset on rebuild | Reset on rebuild |
| Bundled signed (`--bundle-signed`) | **Persistent** | **Persistent** |

## Visual Indicators

### Menu Bar Icons
The menu bar icon helps you quickly identify which version you're running:

| Version | When Permissions Missing | When Permissions Granted |
|---------|-------------------------|---------------------------|
| **Development** (Non-bundled) | 🔧 (wrench) | ✨ (stars) |
| **Production** (Bundled) | ⚠️ (triangle) | ✨ (stars) |

### Icon Meanings
- **🔧 Wrench**: Development version without permissions (permissions reset every time)
- **⚠️ Triangle**: Production version without permissions (persistent permissions possible)
- **✨ Stars**: Either version with permissions granted

## Key Benefits

1. **Clear Separation**: Development vs Production workflows are clearly separated
2. **Permission Management**: Bundled versions provide persistent permissions
3. **Development Speed**: Non-bundled version allows rapid iteration
4. **Testing Accuracy**: Bundled version provides accurate app behavior
5. **Visual Identification**: Different icons help you identify which version is running

## Migration from Previous Approach

The previous approach used separate bundle identifiers (`com.textenhancer.app` vs `com.textenhancer.app.dev`). The new approach uses:
- Same bundle identifier for all versions
- Separation based on bundled vs non-bundled execution
- Simpler permission management

## Quick Reference

```bash
# Development (fast iteration)
./build.sh --run

# Production (persistent permissions)
./build.sh --bundle-signed

# Status check
./build.sh --status

# Help
./build.sh --help
```