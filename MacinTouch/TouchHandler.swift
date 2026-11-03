//
//  TouchHandler.swift
//  MacinTouch
//
//  Core touch event coordinator. Receives HID events, maintains touch state,
//  and delegates gesture recognition to specialized modules.
//

import AppKit
import Foundation

class TouchHandler {
    private let legacyContext: MultiTouchContext  // kept for compatibility during migration
    private let gestureContext: GestureContext
    private let stateMachine: GestureStateMachine
    private let singleTouch: SingleTouchGesture
    private let singleFingerScroll: SingleFingerScrollGesture
    private let twoFinger: TwoFingerDetector
    private let fourFinger: FourFingerGesture

    // Two-finger tap detection (for single-finger scroll mode right-click)
    private var twoFingerDownTime: Date?
    private var twoFingerTapCancelled = false

    // Event history for HID parsing
    private var eventHistory: [TouchEvent] = []
    private let maxHistorySize = 100
    private var lastReportedFingerCount = -1
    private var untrackedCoordinateLogged: Set<Int> = []
    private var diagnosticFilterDeadline: Date?

    private func logFilterExpiry() {
        let deadline = gestureContext.eventFilterEndTime
        if deadline > Date() { diagnosticFilterDeadline = deadline }
        if let previous = diagnosticFilterDeadline, Date() >= previous {
            Log.info(.fourFinger, "TouchTrace filter-expired observedOnNextInput=true tracked=\(gestureContext.activeTouches.keys.sorted())")
            diagnosticFilterDeadline = nil
        }
    }

    private var isSingleFingerScrollMode: Bool {
        gestureContext.config.gestures.touchMode == .singleFingerScroll
    }

    init(context: MultiTouchContext) {
        self.legacyContext = context
        self.gestureContext = GestureContext()

        self.stateMachine = GestureStateMachine(context: gestureContext)
        self.singleTouch = SingleTouchGesture(context: gestureContext, stateMachine: stateMachine)
        self.singleFingerScroll = SingleFingerScrollGesture(context: gestureContext, stateMachine: stateMachine)
        self.twoFinger = TwoFingerDetector(context: gestureContext, stateMachine: stateMachine)
        self.fourFinger = FourFingerGesture(context: gestureContext, stateMachine: stateMachine)

        // Wire up action dispatch
        gestureContext.onAction = { [weak self] action in
            self?.handleAction(action)
        }
    }

    /// Update the live config used by all gesture recognizers.
    func updateConfig(_ config: DriverConfig) {
        fourFinger.reset()
        gestureContext.config = config
        Log.info(.fourFinger, "FourFinger config enabled=\(config.fourFinger.enabled) nativePinch=\(config.fourFinger.nativePinchGesture != false) OS=\(ProcessInfo.processInfo.operatingSystemVersionString)")
    }

    /// Cancel in-flight system gestures before driver shutdown or device loss.
    func cancelGestures() {
        fourFinger.reset()
        twoFinger.reset()
        singleFingerScroll.reset()
        singleTouch.reset()
        gestureContext.resetAll()
        legacyContext.clearAll()
        eventHistory.removeAll()
        untrackedCoordinateLogged.removeAll()
        diagnosticFilterDeadline = nil
        twoFingerDownTime = nil
        fourFinger.check()
    }

    // MARK: - HID Entry Point

    func processHIDElement(element: HIDElement) {
        logFilterExpiry()
        guard let event = parseHIDElement(element) else { return }
        if event.type == .PRESS {
            untrackedCoordinateLogged.remove(event.finger)
            Log.info(.fourFinger, "TouchTrace raw-\(event.button == .DOWN ? "DOWN" : "UP") slot=\(event.finger) cookie=\(element.cookie) raw=\(element.currentValue) reported=\(lastReportedFingerCount) tracked=\(gestureContext.activeTouches.keys.sorted()) filterRemainingMs=\(max(0, Int(gestureContext.eventFilterEndTime.timeIntervalSinceNow * 1000))) state=\(gestureContext.state)")
        }
        addToHistory(event)
        handleTouchEvent(event)
    }

    // MARK: - HID Parsing

    private func parseHIDElement(_ element: HIDElement) -> TouchEvent? {
        // Coordinate events
        let excludedCookie = Int(gestureContext.config.device.hidMapping.excludedCookie)
        if element.usagePage == 1 && element.currentValue < 0x10000 && element.cookie != excludedCookie {
            let value = Int(element.currentValue & 0xffff)

            if element.usage == 0x30 {
                let fid = fingerID(from: Int32(element.cookie), type: .XCOORD)
                return TouchEvent(finger: fid, type: .XCOORD, input: value)
            }
            if element.usage == 0x31 {
                let fid = fingerID(from: Int32(element.cookie), type: .YCOORD)
                return TouchEvent(finger: fid, type: .YCOORD, input: value)
            }
        }
        // Tip switch
        else if element.usage == 0x56 && element.currentValue < 8000 {
            return TouchEvent(finger: 0, type: .TIPSWITCH, input: Int(element.currentValue))
        }
        // Button (press/release)
        else if Int(element.type.rawValue) == 2 {
            let fid = fingerID(from: Int32(element.cookie), type: .PRESS)
            let button: InputType = (element.currentValue == 1) ? .DOWN : .UP
            return TouchEvent(finger: fid, type: .PRESS, button: button)
        }
        // Contact ID
        else if element.usage == 0x51 && element.currentValue != 0 {
            let fid = fingerID(from: Int32(element.cookie), type: .CONTACTID)
            return TouchEvent(finger: fid, type: .CONTACTID, input: Int(element.currentValue / 4))
        }
        // Finger count
        else if element.usage == 0x54 {
            return TouchEvent(finger: 0, type: .FINGERCOUNT, input: Int(element.currentValue))
        }

        return nil
    }

    private func fingerID(from cookie: Int32, type: HIDEventType) -> Int {
        let m = gestureContext.config.device.hidMapping
        var fid: Int
        switch type {
        case .XCOORD:
            fid = Int((cookie - m.xBase) / m.fingerStride)
        case .YCOORD:
            fid = Int((cookie - m.yBase) / m.fingerStride)
        case .CONTACTID:
            fid = Int((cookie - m.contactIDBase) / m.contactIDStride)
        case .PRESS:
            fid = Int(cookie - m.pressBase)
        default:
            fid = 0
        }
        return max(0, min(9, fid))
    }

    // MARK: - Event Routing

    private func handleTouchEvent(_ event: TouchEvent) {
        Log.debug(.hid, "Event: \(event)")

        switch event.type {
        case .PRESS:
            handlePress(event)
        case .XCOORD, .YCOORD:
            handleCoordinate(event)
        case .FINGERCOUNT:
            handleFingerCount(event)
        case .TIPSWITCH:
            Log.debug(.hid, "Tip switch: \(event.input)")
        case .CONTACTID:
            Log.debug(.hid, "Contact ID: F\(event.finger) -> \(event.input)")
        default:
            break
        }
    }

    // MARK: - Press Events

    private func handlePress(_ event: TouchEvent) {
        guard let button = event.button else { return }
        let fid = event.finger

        if button == .DOWN {
            handleTouchDown(fid)
        } else if button == .UP {
            handleTouchUp(fid)
        }
    }

    private func handleTouchDown(_ fid: Int) {
        // Check event filter
        guard !gestureContext.isInEventFilterPeriod else {
            diagnosticFilterDeadline = gestureContext.eventFilterEndTime
            Log.info(.fourFinger, "TouchTrace DOWN-skipped slot=\(fid) reason=event-filter remainingMs=\(max(0, Int(gestureContext.eventFilterEndTime.timeIntervalSinceNow * 1000))) reported=\(lastReportedFingerCount) tracked=\(gestureContext.activeTouches.keys.sorted())")
            Log.debug(.gesture, "Filtered delayed HID event: F\(fid)")
            return
        }

        guard let touch = getCurrentTouch(for: fid) else {
            let fields = eventHistory.suffix(20).filter { $0.finger == fid }.map { "\($0.type):\($0.input)" }.joined(separator: ",")
            Log.info(.fourFinger, "TouchTrace DOWN-skipped slot=\(fid) reason=missing-coordinate-in-last-20-events history=[\(fields)] reported=\(lastReportedFingerCount) tracked=\(gestureContext.activeTouches.keys.sorted())")
            return
        }
        // Only an accepted touch may interrupt momentum. Slot compaction during
        // release can generate UP/DOWN pairs which the filter intentionally
        // ignores; stopping before that check killed a fling before its first frame.
        twoFinger.scrollGesture.stopInertialScrolling(reason: "accepted-touch-down slot=\(fid)")
        singleFingerScroll.stopInertialScrolling()
        var t = touch
        t.state = .ACTIVE

        // Update context
        gestureContext.activeTouches[fid] = t
        gestureContext.gestureStartPoints[fid] = t
        legacyContext.addTouch(t, fingerId: fid)
        Log.info(.fourFinger, "TouchTrace DOWN-accepted slot=\(fid) hardware=(\(t.x),\(t.y)) tracked=\(gestureContext.activeTouches.keys.sorted())")

        // Update state machine
        stateMachine.update()

        if isSingleFingerScrollMode {
            // Clean up any stale two-finger gesture state (e.g. from mode switch)
            if twoFinger.state != .idle {
                twoFinger.endTwoFingerGesture()
            }

            if gestureContext.activeFingerCount == 1 {
                // Check for "A up before B down" two-finger tap scenario:
                // A lifted (pending click running) → state reset to idle → B arrives as activeCount=1.
                // If B is a different finger than the one with the pending click, treat it as the
                // second finger of a two-finger tap: cancel A's pending click, start 2f-tap tracking.
                if singleFingerScroll.pendingClickFingerId >= 0 &&
                   singleFingerScroll.pendingClickFingerId != fid {
                    singleFingerScroll.cancelPendingTapForMultiTouch()
                    twoFingerDownTime = Date()
                    twoFingerTapCancelled = false
                    Log.debug(.singleTouch, "F\(fid) late 2f-tap: cancelled pending click for F\(singleFingerScroll.pendingClickFingerId)")
                    // Don't start single-finger gesture for B — it's part of the two-finger tap.
                    // Its touchEnded will hit phase=idle and do nothing.
                } else {
                    // Single finger → route to scroll gesture
                    singleFingerScroll.touchBegan(fingerId: fid, touch: t, context: gestureContext)
                }
            } else if gestureContext.activeFingerCount == 2 {
                // Second finger down simultaneously → cancel single-finger scroll, start two-finger tap tracking
                singleFingerScroll.reset()
                twoFingerDownTime = Date()
                twoFingerTapCancelled = false
                Log.debug(.singleTouch, "2nd finger simultaneous → reset singleFingerScroll, start 2f-tap window")
            }
            // 3+ fingers: handled by four-finger below
        } else {
            // Two-finger scroll mode (default)
            singleTouch.touchBegan(fingerId: fid, touch: t, context: gestureContext)

            if gestureContext.state == .multiTouch {
                singleTouch.cancelContextMenuTimer()
                singleTouch.cancelDelayedMouseDown()
            }
        }

        // Three or more contacts cannot later become a two-finger tap on release.
        if gestureContext.activeFingerCount >= 3 {
            twoFingerTapCancelled = true
            twoFingerDownTime = nil
            twoFinger.endTwoFingerGesture(allowInertia: false)
        }

        // 4-finger handling
        if gestureContext.activeFingerCount == 4 && FOUR_FINGER_GESTURE_ENABLED {
            if twoFinger.scrollGesture.isScrolling {
                twoFinger.endTwoFingerGesture()
            }
            twoFinger.scrollGesture.stopInertialScrolling()
            singleFingerScroll.stopInertialScrolling()
            singleTouch.cancelContextMenuTimer()
        }

        fourFinger.check()

        Log.debug(.gesture, "Touch DOWN: F\(fid) at (\(t.x), \(t.y)), fingers=\(gestureContext.activeFingerCount)")
    }

    private func handleTouchUp(_ fid: Int) {
        guard let touch = gestureContext.activeTouches[fid] else {
            Log.info(.fourFinger, "TouchTrace UP-skipped slot=\(fid) reason=not-tracked")
            return
        }

        if isSingleFingerScrollMode {
            // Check for two-finger tap right-click.
            // Fires when the last remaining finger lifts (activeFingerCount==1 = only this finger in context).
            // twoFingerDownTime is set either when both fingers are simultaneously active,
            // or when the late-arrival scenario (A up before B down) is detected.
            // We don't require maxFingerCount==2 because in the late-arrival case both
            // fingers are never simultaneously active, so maxFingerCount stays at 1.
            if gestureContext.activeFingerCount == 1,
               let downTime = twoFingerDownTime,
               !twoFingerTapCancelled {
                let elapsed = Date().timeIntervalSince(downTime)
                if elapsed < 0.4 {
                    // Two-finger tap: right-click at current cursor position.
                    // Use NSEvent.mouseLocation → CGEvent coords directly (no hardware round-trip)
                    // to avoid coordinate precision loss that would move the cursor.
                    let mousePos = NSEvent.mouseLocation
                    let screenHeight = NSScreen.screens.first?.frame.height ?? 800.0
                    let cgPos = CGPoint(x: mousePos.x, y: screenHeight - mousePos.y)
                    Log.debug(.singleTouch, "Two-finger tap → right-click at CG(\(Int(cgPos.x)),\(Int(cgPos.y)))")
                    InputSimulator.simulateRightClickAt(cgPoint: cgPos)
                }
                twoFingerDownTime = nil
            }

            singleFingerScroll.touchEnded(fingerId: fid, touch: touch, context: gestureContext)
        } else {
            singleTouch.touchEnded(fingerId: fid, touch: touch, context: gestureContext)
        }

        // Remove from context
        gestureContext.activeTouches.removeValue(forKey: fid)
        gestureContext.gestureStartPoints.removeValue(forKey: fid)
        gestureContext.isDragging.removeValue(forKey: fid)
        gestureContext.hasTriggeredRightClick.removeValue(forKey: fid)
        legacyContext.removeTouch(fingerId: fid)
        Log.info(.fourFinger, "TouchTrace UP-removed slot=\(fid) hardware=(\(touch.x),\(touch.y)) tracked=\(gestureContext.activeTouches.keys.sorted())")

        // Four-finger: finish or advance the multi-contact session
        fourFinger.check()

        // Finish on the first participating lift, without waiting for a later
        // coordinate callback or the remaining finger's release.
        if gestureContext.activeFingerCount != 2 {
            twoFinger.endTwoFingerGesture()
        }

        // Update state machine
        stateMachine.update()

        Log.debug(.gesture, "Touch UP: F\(fid), remaining=\(gestureContext.activeFingerCount)")
    }


    // MARK: - Coordinate Events

    private func handleCoordinate(_ event: TouchEvent) {
        let fid = event.finger
        guard var touch = gestureContext.activeTouches[fid] else {
            if untrackedCoordinateLogged.insert(fid).inserted {
                Log.info(.fourFinger, "TouchTrace coordinate-skipped slot=\(fid) reason=not-tracked axis=\(event.type) value=\(event.input) reported=\(lastReportedFingerCount) tracked=\(gestureContext.activeTouches.keys.sorted())")
            }
            return
        }

        if event.type == .XCOORD {
            touch.x = event.input
        } else {
            touch.y = event.input
        }
        touch.state = .MOVING
        gestureContext.activeTouches[fid] = touch
        legacyContext.updateTouch(touch, fingerId: fid)

        if isSingleFingerScrollMode {
            if gestureContext.activeFingerCount == 1 {
                // Clean up stale two-finger state when back to single finger
                if twoFinger.state != .idle {
                    twoFinger.endTwoFingerGesture()
                }
                // Single-finger scroll
                if gestureContext.isSingleTouchAllowed {
                    singleFingerScroll.touchMoved(fingerId: fid, touch: touch, context: gestureContext)
                }
            } else if gestureContext.activeFingerCount == 2 && !gestureContext.isInFourFingerProtection {
                // Two-finger: pinch detection (same logic as two-finger scroll mode)
                let touches = Array(gestureContext.activeTouches.values)
                if touches.count == 2 {
                    twoFinger.update(touch1: touches[0], touch2: touches[1])
                }
                // Cancel two-finger tap if either finger moved significantly
                if !twoFingerTapCancelled,
                   let startPoint = gestureContext.gestureStartPoints[fid] {
                    let moved = gestureContext.pixelDistance(from: startPoint, to: touch)
                    if moved > gestureContext.config.gestures.movementThreshold {
                        twoFingerTapCancelled = true
                    }
                }
            } else if twoFinger.state != .idle {
                twoFinger.endTwoFingerGesture()
            }
        } else {
            // Two-finger scroll mode (default)
            // Two-finger gesture detection (blocked during four-finger protection)
            if gestureContext.activeFingerCount == 2 && !gestureContext.isInFourFingerProtection {
                let touches = Array(gestureContext.activeTouches.values)
                if touches.count == 2 {
                    twoFinger.update(touch1: touches[0], touch2: touches[1])
                }
            } else if twoFinger.state != .idle {
                twoFinger.endTwoFingerGesture()
            }

            // Single-finger: drag detection and mouse move
            if gestureContext.isSingleTouchAllowed && !twoFinger.scrollGesture.isScrolling {
                singleTouch.touchMoved(fingerId: fid, touch: touch, context: gestureContext)
            }
        }

        // Four-finger gesture detection (always active)
        fourFinger.check()
    }

    // MARK: - Finger Count

    private func handleFingerCount(_ event: TouchEvent) {
        let count = event.input
        Log.debug(.gesture, "Finger count reported: \(count)")
        if count != lastReportedFingerCount {
            if count >= 3 || lastReportedFingerCount >= 3 {
                Log.info(.fourFinger, "Reported contact count=\(count), tracked=\(gestureContext.activeFingerCount)")
            }
            lastReportedFingerCount = count
        }
    }

    // MARK: - Touch Reconstruction

    private func getCurrentTouch(for fid: Int) -> Touch? {
        let recent = eventHistory.suffix(20)
        var x: Int?, y: Int?

        for e in recent.reversed() {
            if e.finger == fid {
                if e.type == .XCOORD && x == nil { x = e.input }
                if e.type == .YCOORD && y == nil { y = e.input }
                if x != nil && y != nil { break }
            }
        }

        guard let xVal = x, let yVal = y else { return nil }
        return Touch(x: xVal, y: yVal)
    }

    private func addToHistory(_ event: TouchEvent) {
        eventHistory.append(event)
        if eventHistory.count > maxHistorySize {
            eventHistory.removeFirst(eventHistory.count - maxHistorySize)
        }
    }

    // MARK: - Action Dispatch

    private func handleAction(_ action: GestureAction) {
        switch action {
        case .mouseDown(let touch):
            Log.info(.fourFinger, "TouchTrace action=mouseDown tracked=\(gestureContext.activeTouches.keys.sorted()) state=\(gestureContext.state)")
            gestureContext.mouseButtonIsDown = true
            InputSimulator.simulatedLeftButtonIsDown = true
            InputSimulator.simulateMouseEvent(.DOWN, at: touch)
        case .mouseUp(let touch):
            Log.info(.fourFinger, "TouchTrace action=mouseUp tracked=\(gestureContext.activeTouches.keys.sorted()) state=\(gestureContext.state)")
            gestureContext.mouseButtonIsDown = false
            InputSimulator.simulatedLeftButtonIsDown = false
            InputSimulator.simulateMouseEvent(.UP, at: touch)
        case .mouseMove(let touch):
            InputSimulator.simulateMouseEvent(.MOVE, at: touch)
        case .mouseDrag(let touch):
            InputSimulator.simulateMouseEvent(.DRAG, at: touch)
        case .rightClick(let touch):
            Log.info(.fourFinger, "TouchTrace action=rightClick tracked=\(gestureContext.activeTouches.keys.sorted()) state=\(gestureContext.state)")
            InputSimulator.simulateMouseEvent(.RIGHT_CLICK, at: touch)
        case .doubleClick(let touch):
            Log.info(.fourFinger, "TouchTrace action=doubleClick tracked=\(gestureContext.activeTouches.keys.sorted()) state=\(gestureContext.state)")
            gestureContext.mouseButtonIsDown = false  // double-click is self-contained (down+up+down+up)
            InputSimulator.simulateMouseEvent(.DBL_CLICK, at: touch)
        case .secondClick(let touch):
            Log.info(.fourFinger, "TouchTrace action=secondClick clickState=2 tracked=\(gestureContext.activeTouches.keys.sorted()) state=\(gestureContext.state)")
            gestureContext.mouseButtonIsDown = false
            InputSimulator.simulatedLeftButtonIsDown = false
            InputSimulator.simulateSecondClick(at: touch)
        case .scroll(let dx, let dy, let point):
            InputSimulator.simulateScroll(deltaX: dx, deltaY: dy, at: point)
        case .continuousScroll(let dx, let dy, let point, let phase, let momentum):
            InputSimulator.simulateContinuousScroll(deltaX: dx, deltaY: dy, at: point, phase: phase, momentum: momentum)
        case .pinchZoom(let magnification, let touch):
            InputSimulator.simulatePinchZoom(magnification: magnification, at: touch)
        case .pinchEnd(let touch):
            InputSimulator.endMagnifyGesture(at: touch)
        case .fourFingerGesture(let type, let point):
            InputSimulator.simulateFourFingerGesture(type, at: point)
        case .dockGesture(let motion, let phase, let progress):
            InputSimulator.postDockGesture(motion: motion, phase: phase, progress: progress)
        case .dockSwipe(let phase, let progress):
            InputSimulator.postDockSwipe(phase: phase, progress: progress)
        case .ensureCommandKeyReleased:
            InputSimulator.ensureCommandKeyReleased()
        case .cleanupAllModifierKeys:
            InputSimulator.cleanupAllModifierKeys()
        }
    }
}
