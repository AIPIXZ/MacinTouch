//
//  main.swift
//  MacinTouch
//
//  Main entry point for ILITEK touchscreen driver
//

import AppKit
import Foundation

/*---------------------------------  Global State  -------------------------*/

/// Shared driver configuration (loaded from disk or defaults).
var driverConfig = DriverConfig.loadOrDefault()

/// Global touch handler instance.
var globalTouchHandler: TouchHandler?

/// HID element callback bridging C -> Swift.
func hidElementCallback(_ element: UnsafeMutablePointer<HIDElement>?) {
    guard let element = element,
          let handler = globalTouchHandler else { return }
    handler.processHIDElement(element: element.pointee)
}

/*---------------------------------  Main  ---------------------------------*/

func main() {
    // Parse CLI flags
    let args = CommandLine.arguments
    if args.contains("--single-finger") {
        driverConfig.gestures.touchMode = .singleFingerScroll
    } else if args.contains("--two-finger") {
        driverConfig.gestures.touchMode = .twoFingerScroll
    }

    // Configure logging
    Log.configure(with: driverConfig.logging)

    let device = driverConfig.device
    Log.info(.system, "MacinTouch for macOS")
    Log.info(.system, "Touch mode: \(driverConfig.gestures.touchMode == .singleFingerScroll ? "Single-finger scroll" : "Two-finger scroll")")
    Log.info(.system, "Device: ILITEK-TP (VID: 0x\(String(device.vendorID, radix: 16)), PID: 0x\(String(device.productID, radix: 16)))")
    Log.info(.system, "----------------------------------------")

    // Signal handlers
    signal(SIGINT, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    let signalSources = [SIGINT, SIGTERM].map { number -> DispatchSourceSignal in
        let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
        source.setEventHandler {
            globalTouchHandler?.cancelGestures()
            StopHIDNotifications()
            Log.info(.system, "Terminated, exiting...")
            exit(0)
        }
        source.resume()
        return source
    }
    defer { signalSources.forEach { $0.cancel() } }

    // Display manager
    let displayManager = DisplayManager.shared
    displayManager.onDisplayConfigChanged = {
        Log.info(.display, "Display configuration updated:\n\(displayManager.getDisplayInfo())")
    }

    Log.info(.display, "Display Configuration:\n\(displayManager.getDisplayInfo())")

    guard displayManager.isConfigurationValid() else {
        Log.error(.display, "Invalid display configuration, exiting")
        exit(1)
    }

    // Resolution check
    let screenRes = displayManager.screenResolution
    if Int(screenRes.width) == Int(TOUCH_RESX) && Int(screenRes.height) == Int(TOUCH_RESY) {
        Log.info(.display, "Screen resolution matches touch resolution")
    } else {
        Log.info(.display, "Resolution mismatch - Screen: \(Int(screenRes.width))x\(Int(screenRes.height)), Touch: \(Int(TOUCH_RESX))x\(Int(TOUCH_RESY)) - auto-scaling enabled")
    }

    // Accessibility permissions
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
        Log.error(.system, "Accessibility permission required. Grant access in System Settings > Privacy & Security > Accessibility")
        exit(1)
    }
    Log.info(.system, "Accessibility permission granted")

    // Initialize touch handler
    let touchContext = MultiTouchContext()
    globalTouchHandler = TouchHandler(context: touchContext)
    globalTouchHandler?.updateConfig(driverConfig)

    // Start HID monitoring
    Log.info(.hid, "Searching for ILITEK touch device...")
    InitHIDNotifications(TOUCH_VID, TOUCH_PID, hidElementCallback)

    Log.info(.system, "Touch driver running. Press Ctrl+C to exit.")
    Log.info(.system, "----------------------------------------")

    CFRunLoopRun()
}

main()
