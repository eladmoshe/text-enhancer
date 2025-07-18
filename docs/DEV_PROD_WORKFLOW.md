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

## 🔍 Build Script Reference (Cheat-Sheet)

| Scenario | Command | Builds | Output Location | Auto-Installs To | Permissions Persistence |
|----------|---------|--------|-----------------|------------------|-------------------------|
| **Rapid development** | `./build.sh --run` | Debug binary only | `.build/debug/TextEnhancer` | _Not installed_ (runs in-place) | ❌ (resets every run) |
| **Unsigned bundle** | `./build.sh --bundle` | App bundle | `TextEnhancer.app` in project root | `~/Applications/TextEnhancer.app` | ❌ (resets on every rebuild) |
| **Signed bundle (recommended)** | `./build.sh --bundle-signed` | Signed app bundle | `TextEnhancer.app` (signed) | `~/Applications/TextEnhancer.app` | ✅ (persists across rebuilds) |
| **CI/Test run** | `./build.sh --test` | Debug + tests | `.build/` products | – | N/A |
| **Status / help** | `./build.sh --status` / `--help` | – | – | – | – |

### Where things end up

* **Debug binary**: `.build/debug/TextEnhancer` – executed directly when using `--run`.
* **Unsigned bundle**: `TextEnhancer.app` created in the repo root, then copied to `~/Applications/TextEnhancer.app` by the script.
* **Signed bundle**: Same as above but code-signed with `$SIGN_ID` and copied via `make install-signed`.
* **System-wide install** (optional): Copy the bundle to `/Applications/TextEnhancer.app` instead of to your user’s Applications folder.

> **Tip**: run `make install-location` (or `./build.sh --status`) to see exactly which bundle is currently active.

### Signing variable

```bash
export SIGN_ID="Apple Development: Your Name (TEAMID)"
```
If `SIGN_ID` is **not** set, `--bundle-signed` will abort and `--bundle` will produce an unsigned bundle (permissions will reset).

---