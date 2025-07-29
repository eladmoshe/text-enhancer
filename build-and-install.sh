#!/bin/bash

# TextEnhancer Build and Install Script
# This script ensures the app is properly built and installed with working permissions
# CRITICAL: This app is USELESS without accessibility permissions - this script ensures they work

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="TextEnhancer"
BUNDLE_ID="com.lemonadeinc.textenhancer.v2"
INSTALL_PATH="/Applications/${APP_NAME}.app"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"

echo -e "${BLUE}🚀 TextEnhancer Build & Install Script${NC}"
echo -e "${YELLOW}⚠️  CRITICAL: This app requires accessibility permissions to function${NC}"
echo ""

# Step 1: Kill any running instances
echo -e "${BLUE}1. Cleaning up running instances...${NC}"
if pgrep -f "${APP_NAME}" > /dev/null; then
    echo "   Killing running ${APP_NAME} instances..."
    pkill -f "${APP_NAME}" || true
    sleep 2
fi

# Step 2: Remove old installations and builds
echo -e "${BLUE}2. Cleaning up old installations...${NC}"
if [ -d "${INSTALL_PATH}" ]; then
    echo "   Removing old app from Applications..."
    rm -rf "${INSTALL_PATH}"
fi

echo "   Cleaning up development builds..."
rm -rf "${BUILD_DIR}" 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/TextEnhancer-* 2>/dev/null || true

# Step 3: Verify bundle identifier consistency
echo -e "${BLUE}3. Verifying bundle identifier consistency...${NC}"
INFO_PLIST_ID=$(plutil -p "${PROJECT_DIR}/TextEnhancer/Info.plist" | grep CFBundleIdentifier | cut -d'"' -f4)
PROJECT_ID=$(grep -A1 "PRODUCT_BUNDLE_IDENTIFIER" "${PROJECT_DIR}/TextEnhancer.xcodeproj/project.pbxproj" | grep -o 'com\.lemonadeinc\.textenhancer\.v2' | head -1)

if [ "$INFO_PLIST_ID" != "$BUNDLE_ID" ]; then
    echo -e "${RED}❌ ERROR: Info.plist bundle ID ($INFO_PLIST_ID) doesn't match expected ($BUNDLE_ID)${NC}"
    exit 1
fi

if [ "$PROJECT_ID" != "$BUNDLE_ID" ]; then
    echo -e "${RED}❌ ERROR: Xcode project bundle ID doesn't match expected ($BUNDLE_ID)${NC}"
    exit 1
fi

echo -e "${GREEN}   ✅ Bundle identifier verified: $BUNDLE_ID${NC}"

# Step 4: Clean build
echo -e "${BLUE}4. Building ${APP_NAME}...${NC}"
cd "${PROJECT_DIR}"
xcodebuild -scheme "${APP_NAME}" \
           -configuration Release \
           -derivedDataPath "${BUILD_DIR}" \
           clean build \
           | grep -E "(error|warning|SUCCEEDED|FAILED)" || true

if [ ! -d "${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app" ]; then
    echo -e "${RED}❌ ERROR: Build failed - app not found${NC}"
    exit 1
fi

echo -e "${GREEN}   ✅ Build completed successfully${NC}"

# Step 5: Verify code signing
echo -e "${BLUE}5. Verifying code signing and bundle ID...${NC}"
BUILT_APP="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"
ACTUAL_BUNDLE_ID=$(codesign -dv --verbose=4 "${BUILT_APP}" 2>&1 | grep "Identifier=" | cut -d'=' -f2)

if [ "$ACTUAL_BUNDLE_ID" != "$BUNDLE_ID" ]; then
    echo -e "${RED}❌ ERROR: Built app has wrong bundle ID: $ACTUAL_BUNDLE_ID (expected: $BUNDLE_ID)${NC}"
    exit 1
fi

echo -e "${GREEN}   ✅ Code signing verified: $ACTUAL_BUNDLE_ID${NC}"

# Step 6: Install to Applications
echo -e "${BLUE}6. Installing to Applications folder...${NC}"
cp -R "${BUILT_APP}" "/Applications/"

# Verify installation
if [ ! -d "${INSTALL_PATH}" ]; then
    echo -e "${RED}❌ ERROR: Installation failed - app not found in Applications${NC}"
    exit 1
fi

echo -e "${GREEN}   ✅ Installed to: ${INSTALL_PATH}${NC}"

# Step 7: Reset and check permissions
echo -e "${BLUE}7. Managing accessibility permissions...${NC}"
echo "   Resetting accessibility permissions for clean state..."
sudo tccutil reset Accessibility "${BUNDLE_ID}" 2>/dev/null || true

# Step 8: Launch the app
echo -e "${BLUE}8. Launching ${APP_NAME}...${NC}"
open "${INSTALL_PATH}"
sleep 3

# Verify app is running from correct location
RUNNING_APP=$(ps aux | grep "/Applications/${APP_NAME}" | grep -v grep | head -1)
if [ -z "$RUNNING_APP" ]; then
    echo -e "${RED}❌ ERROR: App is not running from Applications folder${NC}"
    exit 1
fi

echo -e "${GREEN}   ✅ App launched successfully from Applications${NC}"

# Step 9: Check build number in logs
echo -e "${BLUE}9. Verifying app version in logs...${NC}"
sleep 2
LOG_FILE="$HOME/Library/Logs/${APP_NAME}/debug.log"
if [ -f "$LOG_FILE" ]; then
    LATEST_VERSION=$(tail -20 "$LOG_FILE" | grep "Version:" | tail -1)
    if [ -n "$LATEST_VERSION" ]; then
        echo -e "${GREEN}   ✅ $LATEST_VERSION${NC}"
    fi
fi

# Final instructions
echo ""
echo -e "${GREEN}🎉 BUILD AND INSTALLATION COMPLETE!${NC}"
echo ""
echo -e "${YELLOW}📋 NEXT STEPS TO ENABLE PERMISSIONS:${NC}"
echo "   1. Click the ⚠️  icon in the menu bar"
echo "   2. System Settings will open to Accessibility"
echo "   3. Enable the checkbox next to TextEnhancer"
echo "   4. The warning icon should disappear"
echo "   5. Test keyboard shortcuts (e.g., Ctrl+Option+1)"
echo ""
echo -e "${BLUE}🔧 DEBUGGING INFO:${NC}"
echo "   • App location: ${INSTALL_PATH}"
echo "   • Bundle ID: ${BUNDLE_ID}"
echo "   • Process: $(ps aux | grep "/Applications/${APP_NAME}" | grep -v grep | awk '{print $2}' | head -1)"
echo "   • Log file: ${LOG_FILE}"
echo ""
echo -e "${RED}⚠️  REMEMBER: This app is USELESS without accessibility permissions!${NC}"
echo -e "${RED}   If permissions don't work, run: sudo tccutil reset Accessibility${NC}"