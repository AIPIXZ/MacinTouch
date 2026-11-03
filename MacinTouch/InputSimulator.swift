//
//  InputSimulator.swift
//  MacinTouch
//
//  macOS input event generation using Core Graphics.
//  Pure event simulation - coordinate conversion lives in DisplayManager.
//

import AppKit
import Foundation

class InputSimulator {
    // Keep first click, pointer movement and second click on the same HID state
    // source. A continuation must not switch to a separately created nil source.
    private static let mouseEventSource = CGEventSource(stateID: .hidSystemState)
    private static let clickTraceTag: Int64 = 0x4D54434C
    private static var clickObservationAttempted = false
    private static var clickObservationTap: CFMachPort?
    private static var clickObservationSource: CFRunLoopSource?

    private static func observePostedClicksIfNeeded() {
        guard !clickObservationAttempted, Log.isEnabled(.info, .fourFinger) else { return }
        clickObservationAttempted = true
        let mask = (CGEventMask(1) << CGEventType.leftMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .tailAppendEventTap,
                                         options: .listenOnly, eventsOfInterest: mask,
                                         callback: { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = InputSimulator.clickObservationTap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else if event.getIntegerValueField(.eventSourceUserData) == InputSimulator.clickTraceTag {
                let point = event.location
                Log.info(.fourFinger, "ClickTrace delivered event=\(type == .leftMouseDown ? "DOWN" : "UP") clickState=\(event.getIntegerValueField(.mouseEventClickState)) sourceState=\(event.getIntegerValueField(.eventSourceStateID)) targetPID=\(event.getIntegerValueField(.eventTargetUnixProcessID)) targetCG=\(String(format: "(%.1f,%.1f)", point.x, point.y))")
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: nil) else {
            Log.warn(.fourFinger, "ClickTrace delivery-observer-unavailable; sender logs do not confirm application receipt")
            return
        }
        clickObservationTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        clickObservationSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Main Entry Point

    /// Simulate a mouse event at the given hardware touch coordinates.
    static func simulateMouseEvent(_ inputType: InputType, at touch: Touch, scrollIntensity: Double = 3.0) {
        let dm = DisplayManager.shared
        let cgPoint = dm.convertHardwareToCGEvent(hardwareX: touch.x, hardwareY: touch.y)

        if [.DOWN, .UP, .RIGHT_CLICK, .DBL_CLICK].contains(inputType), Log.isEnabled(.info, .fourFinger) {
            // Read in CG's global coordinate space, the same space as cgPoint.
            // Observe only: do not warp the cursor or change event targeting.
            let cursor = CGEvent(source: nil)?.location
            let cursorDescription = cursor.map { String(format: "(%.1f,%.1f)", $0.x, $0.y) } ?? "unknown"
            let distance = cursor.map { String(format: "%.1f", hypot(cgPoint.x - $0.x, cgPoint.y - $0.y)) } ?? "unknown"
            Log.info(.fourFinger, "ClickTrace event=\(inputType) hardware=(\(touch.x),\(touch.y)) targetCG=\(String(format: "(%.1f,%.1f)", cgPoint.x, cgPoint.y)) pointerBeforeCG=\(cursorDescription) distance=\(distance)")
        }

        Log.debug(.coordinates, "Event \(inputType): hardware(\(touch.x),\(touch.y)) -> CG(\(Int(cgPoint.x)),\(Int(cgPoint.y)))")

        switch inputType {
        case .DOWN:      simulateMouseDown(at: cgPoint)
        case .UP:        simulateMouseUp(at: cgPoint)
        case .MOVE:      simulateMouseMove(at: cgPoint)
        case .DRAG:      simulateMouseDrag(at: cgPoint)
        case .RIGHT_CLICK: simulateRightClick(at: cgPoint)
        case .DBL_CLICK:   simulateDoubleClick(at: cgPoint)
        case .NOTIFICATION_CENTER: simulateNotificationCenter()
        case .SCROLL_UP:   simulateDirectionalScroll(.up, at: cgPoint, units: Int32(scrollIntensity))
        case .SCROLL_DOWN: simulateDirectionalScroll(.down, at: cgPoint, units: Int32(scrollIntensity))
        case .FOUR_FINGER_SWIPE_UP, .FOUR_FINGER_SWIPE_DOWN,
             .FOUR_FINGER_SWIPE_LEFT, .FOUR_FINGER_SWIPE_RIGHT,
             .FOUR_FINGER_TAP:
            simulateFourFingerGesture(inputType, at: CGPoint.zero)
        default: break
        }
    }

    // MARK: - Mouse Events

    private static func simulateMouseDown(at point: CGPoint) {
        observePostedClicksIfNeeded()
        guard let event = CGEvent(mouseEventSource: mouseEventSource, mouseType: .leftMouseDown,
                                   mouseCursorPosition: point, mouseButton: .left) else { return }
        event.flags = []
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.setIntegerValueField(.eventSourceUserData, value: clickTraceTag)
        event.post(tap: .cghidEventTap)
    }

    private static func simulateMouseUp(at point: CGPoint) {
        guard let event = CGEvent(mouseEventSource: mouseEventSource, mouseType: .leftMouseUp,
                                   mouseCursorPosition: point, mouseButton: .left) else { return }
        event.flags = []
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.setIntegerValueField(.eventSourceUserData, value: clickTraceTag)
        event.post(tap: .cghidEventTap)
    }

    private static func simulateMouseMove(at point: CGPoint) {
        guard let event = CGEvent(mouseEventSource: mouseEventSource, mouseType: .mouseMoved,
                                   mouseCursorPosition: point, mouseButton: .left) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    private static func simulateMouseDrag(at point: CGPoint) {
        guard let event = CGEvent(mouseEventSource: mouseEventSource, mouseType: .leftMouseDragged,
                                   mouseCursorPosition: point, mouseButton: .left) else { return }
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Right Click

    /// Right-click at a pre-computed CGEvent position (bypasses hardware coordinate round-trip).
    /// Use this when you already have the correct CGEvent coords (e.g. derived from NSEvent.mouseLocation).
    static func simulateRightClickAt(cgPoint point: CGPoint) {
        simulateRightClick(at: point)
    }

    // Whether we believe the left mouse button is currently held down.
    // Updated by TouchHandler.handleAction for mouseDown/mouseUp events.
    static var simulatedLeftButtonIsDown: Bool = false

    private static func simulateRightClick(at point: CGPoint) {
        // Release left button only if WE held it down (tracked via simulatedLeftButtonIsDown).
        // Previously used CGEventSource.buttonState(.hidSystemState) which is the hardware HID state —
        // our synthetic cghidEventTap events may not have propagated yet, causing false positives
        // that moved the cursor on every two-finger tap.
        if simulatedLeftButtonIsDown {
            guard let upEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                         mouseCursorPosition: point, mouseButton: .left) else { return }
            upEvent.post(tap: .cghidEventTap)
            simulatedLeftButtonIsDown = false
            usleep(20000)
        }

        // Right button down
        guard let downEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown,
                                       mouseCursorPosition: point, mouseButton: .right) else { return }
        downEvent.post(tap: .cghidEventTap)
        usleep(50000)

        // Right button up
        guard let upEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
                                     mouseCursorPosition: point, mouseButton: .right) else { return }
        upEvent.post(tap: .cghidEventTap)
    }

    /// Release right mouse button at hardware touch coordinates.
    static func simulateRightButtonUp(at touch: Touch) {
        let cgPoint = DisplayManager.shared.convertHardwareToCGEvent(hardwareX: touch.x, hardwareY: touch.y)
        guard let upEvent = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
                                     mouseCursorPosition: cgPoint, mouseButton: .right) else { return }
        upEvent.post(tap: .cghidEventTap)
    }

    // MARK: - Double Click

    /// Builds one physical click pair. Kept separate from posting for verification.
    static func makeClickEvents(at point: CGPoint, clickState: Int64) -> [CGEvent] {
        guard let down = CGEvent(mouseEventSource: mouseEventSource, mouseType: .leftMouseDown,
                                 mouseCursorPosition: point, mouseButton: .left),
              let up = CGEvent(mouseEventSource: mouseEventSource, mouseType: .leftMouseUp,
                               mouseCursorPosition: point, mouseButton: .left) else { return [] }
        for event in [down, up] {
            event.flags = []
            event.setIntegerValueField(.mouseEventClickState, value: clickState)
            event.setIntegerValueField(.eventSourceUserData, value: clickTraceTag)
        }
        return [down, up]
    }

    static func simulateSecondClick(at touch: Touch) {
        observePostedClicksIfNeeded()
        let point = DisplayManager.shared.convertHardwareToCGEvent(hardwareX: touch.x, hardwareY: touch.y)
        Log.info(.fourFinger, "ClickTrace event=SECOND_CLICK clickState=2 hardware=(\(touch.x),\(touch.y)) targetCG=\(String(format: "(%.1f,%.1f)", point.x, point.y))")
        for event in makeClickEvents(at: point, clickState: 2) { event.post(tap: .cghidEventTap) }
    }

    private static func simulateDoubleClick(at point: CGPoint) {
        observePostedClicksIfNeeded()
        // Used only when the first tap was deferred and has not been posted yet.
        for event in makeClickEvents(at: point, clickState: 1) { event.post(tap: .cghidEventTap) }
        usleep(50000)
        for event in makeClickEvents(at: point, clickState: 2) { event.post(tap: .cghidEventTap) }
    }

    // MARK: - Scroll Events

    /// Bidirectional pixel scroll at an AppKit screen coordinate.
    static func simulateScroll(deltaX: Int32, deltaY: Int32, at point: CGPoint) {
        let cgPoint = DisplayManager.shared.convertAppKitScreenToCGEvent(point)
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                   wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) else { return }
        event.location = cgPoint
        event.post(tap: .cghidEventTap)
    }

    static func simulateContinuousScroll(deltaX: Int32, deltaY: Int32, at point: CGPoint, phase: Int64, momentum: Int64) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                 wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0) else { return }
        event.location = DisplayManager.shared.convertAppKitScreenToCGEvent(point)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: momentum)
        event.post(tap: .cghidEventTap)
    }

    private enum ScrollDirection { case up, down, left, right }

    private static func simulateDirectionalScroll(_ dir: ScrollDirection, at point: CGPoint, units: Int32 = 3) {
        let (w1, w2): (Int32, Int32) = {
            switch dir {
            case .up:    return (units, 0)
            case .down:  return (-units, 0)
            case .left:  return (0, -units)
            case .right: return (0, units)
            }
        }()
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                   wheelCount: 2, wheel1: w1, wheel2: w2, wheel3: 0) else { return }
        event.location = point
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Pinch Zoom (Native Magnify Gesture)

    /// Magnification phase tracking for pinch-to-zoom gesture events.
    private static var magnifyPhaseActive = false

    static func simulatePinchZoom(magnification: Double, at touch: Touch) {
        let cgPoint = DisplayManager.shared.convertHardwareToCGEvent(hardwareX: touch.x, hardwareY: touch.y)

        if !magnifyPhaseActive {
            // GestureStarted envelope
            postGestureEnvelope(subtype: 61, at: cgPoint)
            // Pinch began
            postMagnifyEvent(phase: 1, magnification: 0, at: cgPoint)
            magnifyPhaseActive = true
        }

        // Pinch changed
        postMagnifyEvent(phase: 2, magnification: magnification, at: cgPoint)
    }

    /// End the magnification gesture sequence. Called when pinch ends.
    static func endMagnifyGesture(at touch: Touch) {
        guard magnifyPhaseActive else { return }
        let cgPoint = DisplayManager.shared.convertHardwareToCGEvent(hardwareX: touch.x, hardwareY: touch.y)
        // Pinch ended
        postMagnifyEvent(phase: 4, magnification: 0, at: cgPoint)
        // GestureEnded envelope
        postGestureEnvelope(subtype: 62, at: cgPoint)
        magnifyPhaseActive = false
    }

    /// Post a GestureStarted (61) or GestureEnded (62) envelope event.
    private static func postGestureEnvelope(subtype: Int64, at point: CGPoint) {
        guard let event = CGEvent(source: nil) else { return }
        event.type = CGEventType(rawValue: 29)!  // kCGEventGesture
        event.location = point
        // Field 110 = kCGEventGestureType (gesture subtype)
        event.setIntegerValueField(CGEventField(rawValue: 110)!, value: subtype)
        event.post(tap: .cghidEventTap)
    }

    /// Post a native magnify (pinch) gesture event via CGEvent.
    /// Uses CGEvent type 29 (kCGEventGesture) with subtype 8 (Pinch).
    /// Fields from AXElements/mouse reverse-engineering:
    ///   110 = kCGEventGestureType (8 = Pinch)
    ///   113 = kCGEventGesturePinchValue (magnification delta)
    ///   132 = kCGEventGesturePhase (IOHIDEventPhase: 1=began, 2=changed, 4=ended)
    private static func postMagnifyEvent(phase: Int64, magnification: Double, at point: CGPoint) {
        guard let event = CGEvent(source: nil) else { return }
        event.type = CGEventType(rawValue: 29)!  // kCGEventGesture
        event.location = point
        event.setIntegerValueField(CGEventField(rawValue: 110)!, value: 8)  // kCGGestureTypePinch
        event.setDoubleValueField(CGEventField(rawValue: 113)!, value: magnification)  // pinch value
        event.setIntegerValueField(CGEventField(rawValue: 132)!, value: phase)  // IOHIDEventPhase
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Four-Finger Gestures

    /// Same macOS 27 event builder used by the validated standalone probe.
    static func postDockSwipe(phase: Int32, progress: Double) {
        postDockGesture(motion: 1, phase: phase, progress: progress)
    }

    private static var pinchLastProgress = 0.0
    private static var pinchLastDelta = 0.0

    static func postDockGesture(motion: Int32, phase: Int32, progress: Double) {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 else { return }
        let nativePinch = motion == 3
        let nativeHID = motion == 2 || nativePinch
        var outputPhase = phase
        var velocity = 0.0
        // Match the successful native probe's range. Recognition stays normalized.
        let outputProgress = nativeHID ? progress * 1.5 : progress
        if nativePinch {
            if phase == 1 {
                pinchLastProgress = outputProgress
                pinchLastDelta = outputProgress
            } else if phase == 2 {
                let delta = outputProgress - pinchLastProgress
                if abs(delta) > 0.00001 { pinchLastDelta = delta }
                pinchLastProgress = outputProgress
            } else if phase == 4 {
                // Return-to-origin / reversing gestures should snap back.
                if abs(outputProgress) < 0.05 || pinchLastDelta * outputProgress < 0 {
                    outputPhase = 8
                } else {
                    velocity = max(-5, min(5, pinchLastDelta * 100))
                }
            }
        }
        let created = nativeHID
            ? MacinTouchCreateNativeDockGestureEvent(motion, outputPhase, outputProgress, velocity)
            : MacinTouchCreateDockGestureEvent(motion, outputPhase, outputProgress, velocity)
        guard let event = created else {
            Log.warn(.fourFinger, "DockGesture construction failed, motion=\(motion) phase=\(outputPhase)")
            return
        }
        event.takeRetainedValue().post(tap: .cgSessionEventTap)
        if !nativeHID, let companion = CGEvent(source: nil) {
            companion.type = CGEventType(rawValue: 29)!
            companion.post(tap: .cgSessionEventTap)
        }
        if outputPhase != 2 {
            Log.info(.fourFinger, "DockGesture motion=\(motion) phase=\(outputPhase) progress=\(String(format: "%.3f", outputProgress)) velocity=\(String(format: "%.3f", velocity)) backend=\(nativeHID ? "native-iohid" : "serialized")")
        }
        if nativePinch && (outputPhase == 4 || outputPhase == 8) {
            pinchLastProgress = 0
            pinchLastDelta = 0
        }
    }

    static func simulateFourFingerGesture(_ type: InputType, at point: CGPoint) {
        switch type {
        case .FOUR_FINGER_SWIPE_UP:    simulateControlArrow(.upArrow)
        case .FOUR_FINGER_SWIPE_DOWN:  simulateControlArrow(.downArrow)
        case .FOUR_FINGER_SWIPE_LEFT:  simulateControlArrow(.rightArrow)
        case .FOUR_FINGER_SWIPE_RIGHT: simulateControlArrow(.leftArrow)
        case .FOUR_FINGER_TAP:         launchLaunchpad()
        default: break
        }
    }

    private static func simulateControlArrow(_ key: CGKeyCode) {
        let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
        down?.flags.insert(.maskControl)
        up?.flags.insert(.maskControl)
        down?.post(tap: .cghidEventTap)
        usleep(50000)
        up?.post(tap: .cghidEventTap)
        ensureControlKeyReleased()
    }

    private static func launchLaunchpad() {
        // macOS 26 (Tahoe) replaced Launchpad with "Apps"
        let appName: String
        if #available(macOS 26.0, *) {
            appName = "Apps"
        } else {
            appName = "Launchpad"
        }

        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-a", appName]
        do {
            try task.run()
            Log.debug(.gesture, "Launched \(appName)")
        } catch {
            Log.warn(.gesture, "Failed to launch \(appName): \(error)")
        }
    }

    // MARK: - Notification Center

    private static func simulateNotificationCenter() {
        let script = """
            tell application "System Events"
                try
                    click menu bar item "Notification Center" of menu bar 1 of application process "SystemUIServer"
                on error
                    key code 99 using {option down}
                end try
            end tell
            """
        if let appleScript = NSAppleScript(source: script) {
            var err: NSDictionary?
            appleScript.executeAndReturnError(&err)
        }
    }

    // MARK: - Keyboard Shortcuts

    private static func simulateKeyboardShortcut(key: CGKeyCode, modifiers: [CGEventFlags]) {
        let down = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
        for m in modifiers {
            down?.flags.insert(m)
            up?.flags.insert(m)
        }
        down?.post(tap: .cghidEventTap)
        usleep(50000)
        up?.post(tap: .cghidEventTap)
    }
}

// MARK: - Modifier Key Management

extension InputSimulator {
    private static func ensureControlKeyReleased() {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        if flags.contains(.maskControl) {
            let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode.control, keyDown: false)
            up?.flags = []
            up?.post(tap: .cghidEventTap)
            usleep(10000)
        }
    }

    static func ensureCommandKeyReleased() {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        if flags.contains(.maskCommand) {
            let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode.command, keyDown: false)
            up?.flags = []
            up?.post(tap: .cghidEventTap)
            usleep(10000)
        }
    }

    static func cleanupAllModifierKeys() {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let keys: [(CGEventFlags, CGKeyCode)] = [
            (.maskCommand, .command), (.maskControl, .control),
            (.maskShift, .shift), (.maskAlternate, .option)
        ]
        for (flag, key) in keys {
            if flags.contains(flag) {
                let up = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: false)
                up?.flags = []
                up?.post(tap: .cghidEventTap)
            }
        }
    }
}

// MARK: - CGKeyCode Constants

extension CGKeyCode {
    static let equal: CGKeyCode = 24
    static let minus: CGKeyCode = 27
    static let upArrow: CGKeyCode = 126
    static let downArrow: CGKeyCode = 125
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let f4: CGKeyCode = 118
    static let control: CGKeyCode = 59
    static let command: CGKeyCode = 55
    static let shift: CGKeyCode = 56
    static let option: CGKeyCode = 58
}
