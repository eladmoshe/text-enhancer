# Comprehensive Testing Plan for TextEnhancer

## Problem Statement
We are stuck in an endless loop of permission issues, losing permissions on every rebuild, and unable to properly test the multi-provider functionality. This plan establishes a systematic approach to break this cycle.

## Root Causes Identified
1. **Unsigned bundles** reset permissions on every rebuild
2. **Signed bundles** currently fail to launch (Error Code 153)
3. **Screen recording permission** request mechanism is broken
4. **No systematic testing** leads to repeated regressions

## Testing Strategy

### Phase 1: Fix Core Permission Issues

#### 1.1 Screen Recording Permission Fix
**Problem**: Clicking "Screen Recording: Disabled" doesn't add app to System Settings
**Test**: 
```bash
# Run this test after each fix attempt
./test-screen-recording-permissions.sh
```

#### 1.2 Signed Bundle Launch Fix
**Problem**: Signed bundles fail with "Launch failed" error
**Test**:
```bash
# Run this test for each signing attempt
./test-signed-bundle.sh
```

### Phase 2: Automated Test Suite

#### 2.1 Permission Status Tests
```bash
#!/bin/bash
# test-permissions.sh
echo "🔍 Testing Permission Status..."

# Test 1: Accessibility Permission
echo "1. Accessibility Permission:"
if ./check-accessibility-permission.sh; then
    echo "✅ Accessibility: GRANTED"
else
    echo "❌ Accessibility: DENIED"
fi

# Test 2: Screen Recording Permission  
echo "2. Screen Recording Permission:"
if ./check-screen-recording-permission.sh; then
    echo "✅ Screen Recording: GRANTED"
else
    echo "❌ Screen Recording: DENIED"
fi

# Test 3: App Bundle Identity
echo "3. App Bundle Identity:"
echo "Bundle ID: $(defaults read ~/Applications/TextEnhancer.app/Contents/Info.plist CFBundleIdentifier)"
echo "Bundle Path: $(readlink -f ~/Applications/TextEnhancer.app)"
```

#### 2.2 Multi-Provider Functionality Tests
```bash
#!/bin/bash
# test-multi-provider.sh
echo "🔍 Testing Multi-Provider Functionality..."

# Test 1: Configuration Loading
echo "1. Configuration Loading:"
if ./check-config-loading.sh; then
    echo "✅ Config loaded with $(./count-shortcuts.sh) shortcuts"
else
    echo "❌ Config failed to load"
fi

# Test 2: Claude Provider
echo "2. Claude Provider:"
if ./test-claude-provider.sh; then
    echo "✅ Claude provider working"
else
    echo "❌ Claude provider failed"
fi

# Test 3: OpenAI Provider
echo "3. OpenAI Provider:"
if ./test-openai-provider.sh; then
    echo "✅ OpenAI provider working"
else
    echo "❌ OpenAI provider failed"
fi

# Test 4: Screenshot Functionality
echo "4. Screenshot Functionality:"
if ./test-screenshot-capture.sh; then
    echo "✅ Screenshot capture working"
else
    echo "❌ Screenshot capture failed"
fi
```

#### 2.3 End-to-End Shortcut Tests
```bash
#!/bin/bash
# test-shortcuts.sh
echo "🔍 Testing All Shortcuts..."

shortcuts=(
    "improve-text:claude:1"
    "summarize:openai:4" 
    "expand:claude:5"
    "describe-screen:claude:6:screenshot"
    "analyze-screen-openai:openai:7:screenshot"
)

for shortcut in "${shortcuts[@]}"; do
    IFS=':' read -r id provider key screenshot <<< "$shortcut"
    echo "Testing $id (Ctrl+Option+$key, $provider)..."
    if ./test-shortcut.sh "$id" "$provider" "$key" "$screenshot"; then
        echo "✅ $id: PASSED"
    else
        echo "❌ $id: FAILED"
    fi
done
```

### Phase 3: Continuous Integration

#### 3.1 Pre-Build Tests
```bash
#!/bin/bash
# pre-build-tests.sh
echo "🔍 Pre-Build Tests..."

# Test API keys are configured
if ! ./check-api-keys.sh; then
    echo "❌ API keys not configured"
    exit 1
fi

# Test code compiles
if ! swift build; then
    echo "❌ Code compilation failed"
    exit 1
fi

echo "✅ Pre-build tests passed"
```

#### 3.2 Post-Build Tests
```bash
#!/bin/bash
# post-build-tests.sh
echo "🔍 Post-Build Tests..."

# Test app launches
if ! ./test-app-launch.sh; then
    echo "❌ App launch failed"
    exit 1
fi

# Test permissions
if ! ./test-permissions.sh; then
    echo "❌ Permission tests failed"
    exit 1
fi

# Test multi-provider functionality
if ! ./test-multi-provider.sh; then
    echo "❌ Multi-provider tests failed"
    exit 1
fi

echo "✅ Post-build tests passed"
```

### Phase 4: Regression Prevention

#### 4.1 Test-Driven Development Workflow
```bash
#!/bin/bash
# development-workflow.sh

echo "🔄 TextEnhancer Development Workflow"
echo "=================================="

# 1. Pre-build tests
echo "1. Running pre-build tests..."
./pre-build-tests.sh || exit 1

# 2. Build app
echo "2. Building application..."
./build.sh --bundle-signed || ./build.sh --bundle || exit 1

# 3. Post-build tests
echo "3. Running post-build tests..."
./post-build-tests.sh || exit 1

# 4. Manual testing checklist
echo "4. Manual Testing Checklist:"
echo "   □ Click menu bar icon"
echo "   □ Verify all shortcuts shown"
echo "   □ Test Ctrl+Option+1 (Claude text)"
echo "   □ Test Ctrl+Option+4 (OpenAI text)"
echo "   □ Test Ctrl+Option+6 (Claude screenshot)"
echo "   □ Test Ctrl+Option+7 (OpenAI screenshot)"
echo "   □ Verify permissions persist after restart"

echo "✅ Development workflow complete"
```

## Implementation Priority

### Immediate Actions (This Session)
1. **Fix screen recording permission request**
2. **Create basic test scripts**
3. **Implement permission status verification**

### Next Steps
1. **Fix signed bundle launch issue**
2. **Create comprehensive test suite**
3. **Implement CI/CD workflow**

## Success Criteria
- ✅ App launches reliably every time
- ✅ Permissions persist across rebuilds (signed version)
- ✅ Screen recording permission can be granted
- ✅ All 5 shortcuts work with correct providers
- ✅ Screenshot functionality works for both providers
- ✅ Test suite catches regressions before they reach production

## Test Frequency
- **Every build**: Basic launch and permission tests
- **Every feature change**: Full multi-provider test suite
- **Every commit**: Automated regression tests
- **Weekly**: Complete end-to-end testing

This systematic approach will break the endless loop and ensure stable, reliable functionality.