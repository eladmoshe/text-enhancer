# TextEnhancer Makefile

.PHONY: build run clean debug release install help bundle bundle-signed install-location

# Configuration
INSTALL_PATH = $(HOME)/Applications/TextEnhancer.app
BUNDLE_NAME = TextEnhancer.app

# Default target
all: build

# Build the application in debug mode
build:
	@echo "Building TextEnhancer..."
	swift build

# Build the application in release mode
release:
	@echo "Building TextEnhancer (Release)..."
	swift build -c release

# Stop any running instances
stop:
	@echo "Stopping any running TextEnhancer instances..."
	@if pgrep -f "TextEnhancer" > /dev/null; then \
		echo "Found running TextEnhancer instances, terminating..."; \
		pkill -f "TextEnhancer"; \
		sleep 2; \
		if pgrep -f "TextEnhancer" > /dev/null; then \
			echo "Force terminating remaining instances..."; \
			pkill -9 -f "TextEnhancer"; \
			sleep 1; \
		fi; \
		echo "✅ All TextEnhancer instances stopped"; \
	else \
		echo "✅ No running TextEnhancer instances found"; \
	fi

# Run the application
run: build stop
	@echo "Running TextEnhancer..."
	.build/debug/TextEnhancer

# Run the release version
run-release: release stop
	@echo "Running TextEnhancer (Release)..."
	.build/release/TextEnhancer

# Run as proper app bundle
run-bundle: install stop
	@echo "Running TextEnhancer as app bundle..."
	open "$(INSTALL_PATH)"

# Open settings directly
settings: install stop
	@echo "Opening TextEnhancer settings..."
	open "$(INSTALL_PATH)" --args --settings

# Debug build with verbose output
debug:
	@echo "Building TextEnhancer (Debug with verbose output)..."
	swift build -v

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build
	rm -rf $(BUNDLE_NAME)

# Clean signing artifacts
clean-sign: clean
	@echo "Cleaning signing artifacts..."
	rm -rf "$(INSTALL_PATH)"

# Install dependencies
deps:
	@echo "Resolving dependencies..."
	swift package resolve

# Update dependencies
update:
	@echo "Updating dependencies..."
	swift package update

# Check for signing certificate
check-sign:
	@echo "Checking for code signing certificate..."
	@if [ -z "$(SIGN_ID)" ]; then \
		echo "ℹ️  SIGN_ID not set, checking for available certificates..."; \
		CERT_OUTPUT=$$(security find-identity -v -p codesigning 2>/dev/null); \
		CERT_COUNT=$$(echo "$$CERT_OUTPUT" | grep -c "valid identities found" || echo "0"); \
		if echo "$$CERT_OUTPUT" | grep -q "0 valid identities found"; then \
			echo "⚠️  No code signing certificates found"; \
			echo "📝 To enable persistent accessibility permissions:"; \
			echo "   1. Create a development certificate in Xcode"; \
			echo "   2. Export SIGN_ID=\"Your Certificate Name\""; \
			echo "   3. Run 'make bundle-signed' instead of 'make bundle'"; \
			echo ""; \
			echo "🔧 For now, building unsigned (permissions will reset on rebuild)"; \
		else \
			echo "✅ Found signing certificates, but SIGN_ID not set"; \
			echo "📝 Available certificates:"; \
			security find-identity -v -p codesigning; \
			echo ""; \
			echo "💡 Set SIGN_ID to use signing: export SIGN_ID=\"Certificate Name\""; \
		fi; \
	else \
		echo "✅ SIGN_ID set to: $(SIGN_ID)"; \
	fi

# Create app bundle (unsigned - permissions will reset on rebuild)
bundle: release check-sign
	@echo "Creating unsigned app bundle..."
	rm -rf $(BUNDLE_NAME)
	mkdir -p $(BUNDLE_NAME)/Contents/{MacOS,Resources}
	cp .build/release/TextEnhancer $(BUNDLE_NAME)/Contents/MacOS/
	cp Info.plist $(BUNDLE_NAME)/Contents/Info.plist
	@echo "✅ Unsigned app bundle created: $(BUNDLE_NAME)"
	@if [ -z "$(SIGN_ID)" ]; then \
		echo "⚠️  Bundle is unsigned - accessibility permissions will reset on rebuild"; \
		echo "💡 Use 'make bundle-signed' for persistent permissions"; \
	fi
	# If a provisioning profile is provided, embed it for Apple Development certificates
	@if [ -n "$(PROVISION_PROFILE)" ] && [ -f "$(PROVISION_PROFILE)" ]; then \
		  echo "📄 Embedding provisioning profile: $(PROVISION_PROFILE)"; \
		  cp "$(PROVISION_PROFILE)" $(BUNDLE_NAME)/Contents/embedded.provisionprofile; \
	else \
		  echo "ℹ️  No provisioning profile embedded (set PROVISION_PROFILE=/path/to/profile.provisionprofile)"; \
	fi

# Create app bundle (signed - permissions will persist across rebuilds)
bundle-signed: release
	@if [ -z "$(SIGN_ID)" ]; then \
		echo "❌ SIGN_ID not set. Please export SIGN_ID=\"Your Certificate Name\""; \
		echo "📝 Available certificates:"; \
		security find-identity -v -p codesigning; \
		exit 1; \
	fi
	@echo "Creating signed app bundle with certificate: $(SIGN_ID)"
	rm -rf $(BUNDLE_NAME)
	mkdir -p $(BUNDLE_NAME)/Contents/{MacOS,Resources}
	cp .build/release/TextEnhancer $(BUNDLE_NAME)/Contents/MacOS/
	cp Info.plist $(BUNDLE_NAME)/Contents/Info.plist
	echo "APPL????" > $(BUNDLE_NAME)/Contents/PkgInfo
	@echo "🔏 Signing app bundle..."
	codesign --force --deep --timestamp --options runtime \
		--entitlements TextEnhancer.entitlements \
		--sign "$(SIGN_ID)" $(BUNDLE_NAME)/Contents/MacOS/TextEnhancer
	codesign --force --deep --timestamp --options runtime \
		--sign "$(SIGN_ID)" $(BUNDLE_NAME)
	@echo "✅ Signed app bundle created: $(BUNDLE_NAME)"
	@echo "🎯 Accessibility permissions will now persist across rebuilds!"

# Install app bundle to Applications folder
install: bundle-signed
	@echo "Installing TextEnhancer to $(INSTALL_PATH)..."
	@mkdir -p "$$(dirname "$(INSTALL_PATH)")"
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "🗑️  Removing existing installation..."; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	cp -R $(BUNDLE_NAME) "$(INSTALL_PATH)"
	@echo "📁 Ensuring app support directory exists..."
	@mkdir -p ~/Library/Application\ Support/TextEnhancer/
	@echo "✅ App support directory ready"
	@echo "✅ TextEnhancer installed to $(INSTALL_PATH)"

# Install signed app bundle to Applications folder
install-signed: bundle-signed
	@echo "Installing signed TextEnhancer to $(INSTALL_PATH)..."
	@mkdir -p "$$(dirname "$(INSTALL_PATH)")"
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "🗑️  Removing existing installation..."; \
		rm -rf "$(INSTALL_PATH)"; \
	fi
	cp -R $(BUNDLE_NAME) "$(INSTALL_PATH)"
	@echo "📁 Ensuring app support directory exists..."
	@mkdir -p ~/Library/Application\ Support/TextEnhancer/
	@echo "✅ App support directory ready"
	@echo "✅ Signed TextEnhancer installed to $(INSTALL_PATH)"
	@echo "🎯 Launch from $(INSTALL_PATH) for persistent accessibility permissions!"


# Show install location
install-location:
	@echo "📍 TextEnhancer install location: $(INSTALL_PATH)"
	@if [ -d "$(INSTALL_PATH)" ]; then \
		echo "✅ TextEnhancer is installed"; \
		echo "📝 Version: $$(defaults read "$(INSTALL_PATH)/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "unknown")"; \
		echo "🔏 Signed: $$(codesign -dv "$(INSTALL_PATH)" 2>&1 | grep -q "Signature=" && echo "Yes" || echo "No")"; \
	else \
		echo "❌ TextEnhancer is not installed"; \
		echo "💡 Run 'make install' or 'make install-signed' to install"; \
	fi

# Notarize the signed app (requires Apple ID setup)
notarize: bundle-signed
	@if [ -z "$(NOTARY_PROFILE)" ]; then \
		echo "❌ NOTARY_PROFILE not set. Please set up notarytool first:"; \
		echo "   xcrun notarytool store-credentials TEXTENHANCER_NOTARY"; \
		echo "   export NOTARY_PROFILE=TEXTENHANCER_NOTARY"; \
		exit 1; \
	fi
	@echo "📤 Submitting for notarization..."
	xcrun notarytool submit $(BUNDLE_NAME) \
		--keychain-profile "$(NOTARY_PROFILE)" --wait
	@echo "📎 Stapling notarization ticket..."
	xcrun stapler staple $(BUNDLE_NAME)
	@echo "✅ App notarized and stapled!"

# Format code
format:
	@echo "Formatting Swift code..."
	swift-format --recursive --in-place Sources/

# Lint code
lint:
	@echo "Linting Swift code..."
	swiftlint lint Sources/

# Check for common issues
check:
	@echo "Checking for common issues..."
	swift build --build-tests 2>&1 | head -20

# Show help
help:
	@echo "TextEnhancer Build System"
	@echo ""
	@echo "🏗️  Build targets:"
	@echo "  build         - Build the application (debug, non-bundled)"
	@echo "  release       - Build the application (release, non-bundled)"
	@echo "  bundle        - Create unsigned app bundle (production)"
	@echo "  bundle-signed - Create signed app bundle (production, persistent permissions)"
	@echo ""
	@echo "🚀 Run targets:"
	@echo "  run           - Build and run debug version (non-bundled, development)"
	@echo "  run-release   - Build and run release version (non-bundled)"
	@echo "  run-bundle    - Install and run app bundle (bundled, production)"
	@echo "  settings      - Open settings window directly"
	@echo ""
	@echo "📦 Install targets:"
	@echo "  install       - Install signed bundle to ~/Applications"
	@echo "  install-signed- Install signed bundle to ~/Applications"
	@echo "  install-location - Show install status and location"
	@echo ""
	@echo "🔏 Signing targets:"
	@echo "  check-sign    - Check signing certificate status"
	@echo "  notarize      - Notarize signed app (requires setup)"
	@echo ""
	@echo "🧹 Maintenance:"
	@echo "  clean         - Clean build artifacts"
	@echo "  clean-sign    - Clean build and signing artifacts"
	@echo "  deps          - Resolve dependencies"
	@echo "  update        - Update dependencies"
	@echo "  stop          - Stop any running TextEnhancer instances"
	@echo ""
	@echo "🧪 Development:"
	@echo "  test          - Run tests with coverage"
	@echo "  debug         - Build with verbose output"
	@echo "  format        - Format Swift code"
	@echo "  lint          - Lint Swift code"
	@echo "  check         - Check for common issues"
	@echo ""
	@echo "💡 For persistent accessibility permissions:"
	@echo "   1. Create development certificate in Xcode"
	@echo "   2. export SIGN_ID=\"Apple Development: Your Name (TEAMID)\""
	@echo "   3. make install-signed && open ~/Applications/TextEnhancer.app"
	@echo ""
	@echo "Usage: make [target]"

# Development shortcuts
dev: clean deps build run

# Run tests with coverage
test:
	@echo "Running tests with coverage..."
	swift test --enable-code-coverage
	@echo ""
	@echo "Code coverage report:"
	@echo "Use: xcrun llvm-cov show .build/debug/TextEnhancerPackageTests.xctest/Contents/MacOS/TextEnhancerPackageTests -instr-profile .build/debug/codecov/default.profdata"

# Quick test build
test-build:
	@echo "Quick test build..."
	swift build --build-tests 