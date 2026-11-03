# Makefile for MacinTouch
# macOS Apple M4 compatible

PROJECT_NAME = MacinTouch
TARGET_NAME = MacinTouch
BUILD_DIR = build
SOURCE_DIR = MacinTouch

# Compiler settings
SWIFT_FLAGS = -O -whole-module-optimization
C_FLAGS = -O2 -Wall

# Frameworks
FRAMEWORKS = -framework Foundation -framework AppKit -framework IOKit -framework CoreGraphics

# Default target
all: debug

# Debug build
debug:
	@echo "🔨 Building MacinTouch (Debug)..."
	@mkdir -p $(BUILD_DIR)/Debug
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(TARGET_NAME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo "✅ Debug build completed"

# Release build
release:
	@echo "🔨 Building MacinTouch (Release)..."
	@mkdir -p $(BUILD_DIR)/Release
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(TARGET_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo "✅ Release build completed"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf DerivedData
	@echo "✅ Clean completed"

# Install (copy to /usr/local/bin)
install: release
	@echo "📦 Installing MacinTouch..."
	sudo cp $(BUILD_DIR)/Build/Products/Release/$(TARGET_NAME) /usr/local/bin/
	sudo chmod +x /usr/local/bin/$(TARGET_NAME)
	@echo "✅ Installation completed"
	@echo "💡 Run with: sudo MacinTouch"

# Uninstall
uninstall:
	@echo "🗑️  Uninstalling MacinTouch..."
	sudo rm -f /usr/local/bin/$(TARGET_NAME)
	@echo "✅ Uninstallation completed"

# Run debug version (two-finger scroll mode, default)
run-debug: debug
	@echo "🚀 Running MacinTouch (Debug, two-finger scroll)..."
	$(BUILD_DIR)/Build/Products/Debug/$(TARGET_NAME)

# Run debug version in single-finger scroll mode
run-debug-sf: debug
	@echo "🚀 Running MacinTouch (Debug, single-finger scroll)..."
	$(BUILD_DIR)/Build/Products/Debug/$(TARGET_NAME) --single-finger

# Run release version
run: release
	@echo "🚀 Running MacinTouch (Release)..."
	sudo $(BUILD_DIR)/Build/Products/Release/$(TARGET_NAME)

# Check system requirements
check:
	@echo "🔍 Checking system requirements..."
	@echo "System: $$(uname -a)"
	@echo "Xcode: $$(xcodebuild -version | head -1)"
	@echo "Swift: $$(swift --version | head -1)"
	@echo "Architecture: $$(uname -m)"
	@if [ "$$(uname -m)" = "arm64" ]; then \
		echo "✅ Apple Silicon detected"; \
	else \
		echo "⚠️  Intel architecture detected"; \
	fi

# Test build without running
test-build:
	@echo "🧪 Testing build process..."
	@chmod +x test-build.sh
	@./test-build.sh

# Check devices
check-device:
	@echo "🔍 Checking for compatible devices..."
	@swift tools/core/device-check-simple.swift

# Validate configuration
check-config:
	@echo "⚙️  Validating configuration..."
	@swift tools/core/config-validate.swift

# System compatibility check
check-system:
	@echo "🖥️  Checking system compatibility..."
	@swift tools/core/system-check.swift

# Full system check
check-all: check-system check-config check-device
	@echo "✅ All checks completed"

# GUI targets (delegate to Makefile-GUI)
gui:
	@$(MAKE) -f Makefile-GUI gui-release

gui-debug:
	@$(MAKE) -f Makefile-GUI gui-debug

gui-run:
	@$(MAKE) -f Makefile-GUI gui-run

gui-run-debug:
	@$(MAKE) -f Makefile-GUI gui-run-debug

gui-install:
	@$(MAKE) -f Makefile-GUI gui-install

dmg:
	@bash scripts/create-dmg.sh

# Show help
help:
	@echo "MacinTouch Build System"
	@echo "================================"
	@echo ""
	@echo "Build targets:"
	@echo "  debug      - Build debug version"
	@echo "  release    - Build release version"
	@echo "  clean      - Clean build artifacts"
	@echo ""
	@echo "Run targets:"
	@echo "  run-debug     - Build and run debug (two-finger scroll)"
	@echo "  run-debug-sf  - Build and run debug (single-finger scroll)"
	@echo "  run           - Build and run release version"
	@echo ""
	@echo "Install targets:"
	@echo "  install    - Install to system (requires sudo)"
	@echo "  uninstall  - Remove from system (requires sudo)"
	@echo ""
	@echo "Check targets:"
	@echo "  check           - Check system requirements"
	@echo "  check-system    - Check system compatibility"
	@echo "  check-config    - Validate configuration"
	@echo "  check-device    - Check for compatible devices"
	@echo "  check-all       - Run all checks"
	@echo "  test-build      - Test build process"
	@echo ""
	@echo "GUI targets:"
	@echo "  gui            - Build GUI release version"
	@echo "  gui-debug      - Build GUI debug version"
	@echo "  gui-run        - Build and run GUI"
	@echo "  gui-run-debug  - Build and run GUI (debug)"
	@echo "  gui-install    - Install GUI to /Applications"
	@echo ""
	@echo "Other targets:"
	@echo "  help       - Show this help"
	@echo ""
	@echo "Usage examples:"
	@echo "  make check-all    # Run all system checks"
	@echo "  make debug        # Build debug version"
	@echo "  sudo make run     # Build and run release version"
	@echo "  sudo make install # Install to system"

.PHONY: all debug release clean install uninstall run-debug run-debug-sf run check help test-build check-device check-config check-system check-all gui gui-debug gui-run gui-run-debug gui-install dmg