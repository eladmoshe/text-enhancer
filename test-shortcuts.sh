#!/bin/bash

echo "🔍 Testing Shortcut Functionality..."

# Step 1: Check if app is running
if ! pgrep -f TextEnhancer > /dev/null; then
    echo "❌ TextEnhancer is not running"
    echo "💡 Run: ./build.sh --bundle && open ~/Applications/TextEnhancer.app"
    exit 1
fi

echo "✅ TextEnhancer is running"

# Step 2: Check configuration loading
echo "🔍 Checking configuration loading..."
if [ -f ~/Library/Application\ Support/TextEnhancer/config.json ]; then
    echo "✅ Configuration file found"
    shortcuts_count=$(grep -c '"id"' ~/Library/Application\ Support/TextEnhancer/config.json)
    echo "📋 Found $shortcuts_count shortcuts in config"
else
    echo "❌ Configuration file not found"
    exit 1
fi

# Step 3: Check API keys
echo "🔍 Checking API keys..."
if grep -q "sk-ant-" ~/Library/Application\ Support/TextEnhancer/config.json; then
    echo "✅ Claude API key found"
else
    echo "❌ Claude API key missing"
fi

if grep -q '"openai"' ~/Library/Application\ Support/TextEnhancer/config.json && grep -A 10 '"openai"' ~/Library/Application\ Support/TextEnhancer/config.json | grep -q '"apiKey": "sk-'; then
    echo "✅ OpenAI API key found"
else
    echo "❌ OpenAI API key missing"
fi

# Step 4: Manual testing instructions
echo ""
echo "📋 Manual Shortcut Testing Checklist:"
echo "   □ Click TextEnhancer menu bar icon"
echo "   □ Verify shortcuts are listed in menu"
echo "   □ Test Ctrl+Option+1 (Improve Text - Claude)"
echo "   □ Test Ctrl+Option+4 (Summarize - OpenAI)"
echo "   □ Test Ctrl+Option+5 (Expand - Claude)"
echo "   □ Test Ctrl+Option+6 (Describe Screen - Claude)"
echo "   □ Test Ctrl+Option+7 (Analyze Screen - OpenAI)"
echo ""
echo "🔧 Testing Text Shortcuts (Ctrl+Option+1, 4, 5):"
echo "   1. Select some text in any app"
echo "   2. Press the shortcut key combination"
echo "   3. Verify the text is enhanced and replaced"
echo "   4. Check that different providers give different responses"
echo ""
echo "🔧 Testing Screenshot Shortcuts (Ctrl+Option+6, 7):"
echo "   1. Do NOT select any text"
echo "   2. Press the shortcut key combination"
echo "   3. Verify screenshot is captured and analyzed"
echo "   4. Check that analysis is inserted at cursor position"
echo ""
echo "💡 If shortcuts don't work, check accessibility permissions"
echo "💡 If screenshot shortcuts don't work, check screen recording permissions"

echo ""
echo "🎯 Test Status: READY_FOR_MANUAL_TESTING"