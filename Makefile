# TextEnhancer Makefile

.PHONY: build run clean debug release install help

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

# Run the application
run: build
	@echo "Running TextEnhancer..."
	.build/debug/TextEnhancer

# Run the release version
run-release: release
	@echo "Running TextEnhancer (Release)..."
	.build/release/TextEnhancer

# Run as proper app bundle
run-bundle: bundle
	@echo "Running TextEnhancer as app bundle..."
	open TextEnhancer.app

# Open settings directly
settings: bundle
	@echo "Opening TextEnhancer settings..."
	open TextEnhancer.app --args --settings

# Debug build with verbose output
debug:
	@echo "Building TextEnhancer (Debug with verbose output)..."
	swift build -v

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build

# Install dependencies
deps:
	@echo "Resolving dependencies..."
	swift package resolve

# Update dependencies
update:
	@echo "Updating dependencies..."
	swift package update

# Create app bundle (for distribution)
bundle: release
	@echo "Creating app bundle..."
	rm -rf TextEnhancer.app
	mkdir -p TextEnhancer.app/Contents/{MacOS,Resources}
	cp .build/release/TextEnhancer TextEnhancer.app/Contents/MacOS/
	cp Info.plist TextEnhancer.app/Contents/Info.plist
	cp TextEnhancer.entitlements TextEnhancer.app/Contents/Resources/
	@echo "App bundle created: TextEnhancer.app"
	@echo "To run: open TextEnhancer.app"

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
	@echo "Available targets:"
	@echo "  build      - Build the application (debug)"
	@echo "  release    - Build the application (release)"
	@echo "  run        - Build and run the application"
	@echo "  run-release- Build and run the release version"
	@echo "  run-bundle - Create and run as app bundle (recommended)"
	@echo "  settings   - Open settings window directly"
	@echo "  debug      - Build with verbose output"
	@echo "  clean      - Clean build artifacts"
	@echo "  deps       - Resolve dependencies"
	@echo "  update     - Update dependencies"
	@echo "  bundle     - Create app bundle for distribution"
	@echo "  format     - Format Swift code"
	@echo "  lint       - Lint Swift code"
	@echo "  check      - Check for common issues"
	@echo "  help       - Show this help message"
	@echo ""
	@echo "Usage: make [target]"

# Development shortcuts
dev: clean deps build run

# Quick test build
test-build:
	@echo "Quick test build..."
	swift build --build-tests 