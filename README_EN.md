# MacinTouch for macOS

English | [中文](README.md)

A macOS touch driver for ILITEK touchscreen devices. Bridges USB HID touch input into macOS mouse events with full multi-touch gesture support. Available as a CLI driver and a SwiftUI menu bar app.

## Device Support

| Field | Value |
|-------|-------|
| Model | ILITEK-TP |
| Vendor ID | 0x222a |
| Product ID | 0x0001 |
| Interface | USB HID |

## Features

The driver supports two touch modes, switchable at runtime:

### Two-Finger Scroll Mode (default)

- **Click / Double-click** — standard left mouse button
- **Long press (0.6s)** — right-click context menu
- **Single-finger drag** — hold and move for drag / text selection
- **Two-finger scroll** — natural direction with inertia and acceleration
- **Two-finger pinch** — zoom in/out (Cmd+scroll simulation)

### Single-Finger Scroll Mode (`--single-finger`)

- **Single-finger swipe** — scroll the page directly; cursor snaps to finger position so the scroll targets the window under your finger
- **Tap** — left click; double-tap → double click
- **Long press (0.6s)** — drag mode for text selection
- **Two-finger tap** — right-click at the current cursor position (cursor does not move)

### Common (both modes)

- **4-finger gestures**
  - Swipe up → Mission Control (Control + ↑)
  - Swipe down → App Exposé (Control + ↓)
  - Swipe left → Move to right desktop (Control + →)
  - Swipe right → Move to left desktop (Control + ←)
  - Tap → Launchpad
- **Menu bar GUI** — graphical configuration, no command line needed

## Requirements

- macOS 13.0+
- Apple Silicon or Intel
- Accessibility permission (for event simulation)
- Input Monitoring permission (for HID device access)

## Quick Start

### Option 1: GUI App (recommended)

```bash
# Build the GUI app
make gui-debug

# Launch (or open build/MacinTouchApp.app directly)
make gui-run-debug
```

The app guides you through permission setup — no `sudo` required.

### Option 2: CLI Driver

```bash
# Build
make debug

# Run in two-finger scroll mode (requires sudo for HID access)
sudo make run-debug

# Run in single-finger scroll mode
sudo make run-debug-sf

# Install to /usr/local/bin
sudo make install
```

### Option 3: DMG Package

Build a distributable DMG from the release GUI app:

```bash
make dmg
# or directly
bash scripts/create-dmg.sh
```

Produces `build/MacinTouch-1.0.0.dmg`. Mount, drag to Applications, launch from Launchpad.

## Build Commands

```bash
# CLI driver
make debug          # debug build
make release        # release build
make clean          # clean build artifacts

# GUI app
make gui-debug      # debug build
make gui            # release build
make gui-install    # install to /Applications

# System checks
make check-all                               # all checks
swift tools/core/device-check-simple.swift  # check device connection
```

## Gesture Reference

### Two-Finger Scroll Mode (default)

| Gesture | Action |
|---------|--------|
| Single tap | Left click |
| Double tap | Double click |
| Long press (0.6s) | Right-click menu |
| Single-finger drag | Mouse drag |
| Two-finger scroll (up/down) | Vertical scroll (with inertia) |
| Two-finger scroll (left/right) | Horizontal scroll |
| Two-finger pinch / spread | Zoom (Cmd+scroll) |

### Single-Finger Scroll Mode (`--single-finger`)

| Gesture | Action |
|---------|--------|
| Single-finger swipe | Page scroll (with inertia) |
| Tap | Left click |
| Double tap | Double click |
| Long press (0.6s) | Drag mode (text selection) |
| Two-finger tap | Right-click (cursor stays put) |

### 4-Finger Gestures (both modes)

| Gesture | Action |
|---------|--------|
| Swipe up | Mission Control |
| Swipe down | App Exposé |
| Swipe left | Move to right desktop |
| Swipe right | Move to left desktop |
| Tap | Launchpad |

## Architecture

```
HIDSetup.c ──→ TouchHandler.swift ──→ Gestures/ ──→ InputSimulator.swift
                                           ↕
                                   DisplayManager.swift
                                           ↕
                                     DriverConfig.swift
```

- `MacinTouch/` — driver core (shared by CLI and GUI)
- `MacinTouch/Gestures/` — 8 independent gesture recognizer modules
- `MacinTouchApp/` — SwiftUI menu bar app
- See [docs/02-technical-architecture.md](docs/02-technical-architecture.md) for full details

## Debug Tools

```bash
swift tools/core/device-check-simple.swift  # check device connection
swift tools/core/config-validate.swift      # validate config
swift tools/core/system-check.swift         # system compatibility check
swift tools/core/debug-monitor.swift        # live touch event monitor
swift tools/core/gesture-test.swift         # gesture recognition test
swift tools/core/coordinate-test.swift      # coordinate mapping test
```

## Documentation

| Doc | Description |
|-----|-------------|
| [Technical Architecture](docs/02-technical-architecture.md) | Full architecture and module details |
| [Coordinate System](docs/03-coordinate-system.md) | Coordinate conversion internals |
| [Gesture Guide](docs/09-gesture-guide.md) | Gesture parameters and tuning |
| [Debugging Guide](docs/05-debugging-guide.md) | Debugging methods and tools |
| [GUI App](docs/11-gui-application.md) | GUI usage guide |
| [Deployment](docs/10-deployment-guide.md) | Installation and distribution |

## License

MIT License
