# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
A macOS touch driver for ILITEK touchscreen devices (ILITEK-TP, VID: 0x222a, PID: 0x0001). The driver bridges HID hardware input to macOS mouse events with multi-touch gesture support. Includes a SwiftUI menu bar GUI for configuration.

## Common Development Commands

### Build
```bash
make debug              # CLI driver (debug)
make release            # CLI driver (release)
make gui-debug          # GUI app (debug)
make gui                # GUI app (release)
make clean              # Clean all build artifacts
```

### Run
```bash
sudo make run-debug        # Run CLI driver (requires sudo for HID)
sudo make run-debug-sf     # Run CLI driver in single-finger scroll mode
sudo make run              # Run CLI driver (release)
make gui-run-debug         # Run GUI app
make gui-run               # Run GUI app (release)
sudo make install          # Install CLI to /usr/local/bin
make gui-install           # Install GUI to /Applications
```

### System Checks
```bash
make check-all                              # All system requirements
swift tools/core/device-check-simple.swift  # Check for ILITEK devices
swift tools/core/config-validate.swift      # Validate configuration
swift tools/core/system-check.swift         # System compatibility
```

## Architecture

### CLI Driver Pipeline (MacinTouch/)

```
HIDSetup.c → TouchHandler.swift → Gesture Recognizers → InputSimulator.swift
                                        ↕
                                  DisplayManager.swift
```

1. **HIDSetup.c** - IOKit HID interface. Discovers ILITEK device, parses reports, calls Swift callback.

2. **TouchHandler.swift** - Slim coordinator (298 lines). Receives HID events, maintains touch state, routes to gesture recognizers, dispatches actions to InputSimulator.

3. **Gesture Recognizers** (`Gestures/` directory):
   - `GestureRecognizer.swift` - Protocol + GestureContext (shared state, action dispatch)
   - `GestureStateMachine.swift` - idle/singleTouch/multiTouch transitions
   - `SingleTouchGesture.swift` - Tap, double-tap, right-click (long press), drag (two-finger scroll mode)
   - `SingleFingerScrollGesture.swift` - Single-finger scroll, tap, long-press drag, inertial scrolling (single-finger scroll mode)
   - `ScrollGesture.swift` - Two-finger scroll with inertia and acceleration
   - `PinchGesture.swift` - Two-finger pinch zoom (Cmd+scroll simulation)
   - `TwoFingerDetector.swift` - Distinguishes scroll from pinch via movement analysis
   - `FourFingerGesture.swift` - 4-finger swipes (Control+Arrow) and tap (Launchpad)

4. **DisplayManager.swift** - Coordinate transformation singleton. Hardware (0-16383) -> AppKit Screen -> CGEvent coordinates. Handles multi-display and resolution changes.

5. **InputSimulator.swift** - Pure CGEvent generation (287 lines). Mouse, scroll, pinch, four-finger, modifier key management.

### Shared Infrastructure (MacinTouch/)

- **DriverConfig.swift** - Codable config struct (DriverConfig) with sub-configs for device, gestures, scroll, pinch, four-finger, display, logging. JSON persistence at ~/Library/Application Support/MacinTouch/config.json. Also defines DriverStatus.
- **TouchDriverInterface.swift** - Protocol contract between driver and GUI (start/stop/restart/config/status/onStatusChange). Allows future IPC separation.
- **Logger.swift** - Structured logging with categories and levels, replacing global debug booleans.
- **Config.swift** - Legacy compile-time constants (kept for backward compatibility during migration).
- **Structs.swift** - Touch, TouchEvent, Gesture, MultiTouchContext data structures.

### GUI App (MacinTouchApp/)

SwiftUI menu bar app that embeds the driver in-process.

- **MacinTouchAppApp.swift** - @main App entry, MenuBarExtra, AppDelegate (start/stop driver)
- **Utils/TouchDriverCore.swift** - Implements TouchDriverInterface, bridges HID to GUI
- **ViewModels/TouchDriverModel.swift** - ObservableObject exposing DriverConfig + DriverStatus to views, change tracking
- **Models/TouchDriverConfiguration.swift** - Legacy ConfigurationManager (delegates to DriverConfig)
- **Views/MenuBarView.swift** - Menu bar dropdown: status, quick toggles, save/restart
- **Views/SettingsView.swift** - Tabbed settings (Permissions, Devices, Gestures, Startup, About)
- **Views/SettingsWindowView.swift** - NSWindow wrapper for settings

## Key Configuration

Defined in `DriverConfig.swift` (runtime) with defaults matching `Config.swift` (compile-time):
- Hardware coordinate range: 0-16383
- Right-click long press: 0.6s
- Scroll: direct mapping, inertial scrolling with acceleration
- Four-finger: swipe threshold 60px, min velocity 100px/s, tap detection with 150ms buffer

## Important Details

### Coordinate System
- Hardware: 0-16383 range, Y-axis inverted during normalization
- Three-step conversion: Hardware -> Normalized -> AppKit Screen -> CGEvent
- CGEvent Y is flipped relative to AppKit screen coordinates

### Touch Modes

`DriverConfig.gestures.touchMode` selects between two operating modes:

**Two-finger scroll mode** (default, `.twoFingerScroll`):
- 1 finger → mouse pointer control (move, click, drag, right-click via long press)
- 2 fingers → scroll or pinch zoom
- 4 fingers → Mission Control / desktop swipe

**Single-finger scroll mode** (`.singleFingerScroll`), enabled via `--single-finger` CLI flag or GUI setting:
- 1 finger → scroll (primary use case). State machine: `idle → pending → scrolling/dragging`
  - `pending`: finger down, absorbing jitter until `scrollCommitThreshold` (5px) is exceeded
  - `scrolling`: continuous scroll events; cursor jumps to finger position on first commit so scroll targets the window under the finger
  - `dragging`: entered via long press (~0.6s in pending state); emits mouseDown+drag+mouseUp for text selection
  - Lift without moving → tap → single click (deferred 100ms) or double-click
  - Inertial scrolling on lift when velocity exceeds threshold
- 2 fingers tap → right-click at current cursor position (no cursor movement)
  - Handles sequential finger arrival ("A up before B down") via pending click cancellation
- 4 fingers → Mission Control / desktop swipe (same as two-finger scroll mode)

### Gesture Recognition
- Single touch (two-finger mode): delayed mouseDown (50ms) to avoid accidental clicks during multi-touch transition
- Two-finger: TwoFingerDetector analyzes movement vectors to classify scroll vs pinch
- Four-finger: 150ms buffer waiting for 4th finger, swipe with velocity check, tap with max 0.5s duration

### Required Permissions
- Accessibility (AXIsProcessTrusted) for event simulation
- Input Monitoring for HID device access
- CLI requires sudo; GUI handles permissions via system dialogs

## Testing Workflow

1. `swift tools/core/device-check-simple.swift` - verify device
2. `make debug` - build
3. `sudo make run-debug` - run with debug output
4. `swift tools/core/debug-monitor.swift` - monitor events (separate terminal)
5. `swift tools/core/gesture-test.swift` - test gesture recognition
