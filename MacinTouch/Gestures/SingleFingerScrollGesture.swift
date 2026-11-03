//
//  SingleFingerScrollGesture.swift
//  MacinTouch
//
//  Single-finger scroll mode gesture recognizer.
//
//  State machine:
//    idle → pending:   finger touches down
//    pending → scroll:  finger moves beyond scrollCommitThreshold
//    pending → drag:    long-press timer fires (finger barely moved)
//    pending → idle:    finger lifts → tap / double-click
//    scroll → idle:     finger lifts → inertial scroll
//    drag → idle:       finger lifts → mouseUp
//
//  In pending state, small jitter is absorbed — no events emitted.
//  Scroll events are emitted at the current mouse cursor position.
//

import AppKit
import Foundation

class SingleFingerScrollGesture: GestureRecognizer {
    private let context: GestureContext
    private let stateMachine: GestureStateMachine

    // MARK: - State Machine

    private enum Phase {
        case idle
        case pending   // Finger down, determining intent: tap / scroll / drag
        case scrolling // Committed to scroll
        case dragging  // Long press → drag/select mode
    }
    private var phase: Phase = .idle
    private var activeFingerId: Int = -1

    // Touch tracking
    private var touchDownPosition: Touch?
    private var lastTouch: Touch?

    // Long press timer
    private var longPressTimer: Timer?

    // Whether the user has actually moved after entering drag mode.
    // mouseDown is deferred until the first movement so that long-press without
    // subsequent movement does nothing (rather than acting as a click).
    private var dragMoveStarted = false

    // Scroll commit: movement must exceed this before any scroll events fire.
    // This prevents micro-jitter from accidentally entering scroll and suppressing taps.
    private let scrollCommitThreshold: Double = 5.0

    // Double-click detection
    private var lastTapTime: Date? = nil
    private var lastTapTouch: Touch?

    // Pending click: deferred to allow a second finger to arrive (multi-touch recognition window).
    // If a second finger arrives before the timer fires, reset() cancels it — no click emitted.
    private var pendingClickTimer: Timer?
    private var pendingClickTouch: Touch?
    // Which finger ID started the pending click (-1 = none).
    // Used by TouchHandler to detect "A up before B down" two-finger tap scenario.
    private(set) var pendingClickFingerId: Int = -1

    // True when touchBegan arrived while inertial scrolling was active (user touched to stop scroll).
    // A quick lift in this case should not fire a click — the intent was to stop, not to tap.
    private var beganDuringInertialScroll = false

    // Timestamp of when the last scroll phase ended.
    // Used to suppress bounce clicks: touchscreens sometimes register a spurious brief
    // second contact immediately after a finger lifts, which would otherwise fire a click.
    private var lastScrollEndTime: Date = .distantPast
    // Touch within this window after a scroll ends is treated as a bounce artifact.
    private let scrollEndBounceWindow: TimeInterval = 0.15
    // True when this touch began within the bounce suppression window after a scroll.
    private var beganAfterRecentScroll = false

    // Accumulated scroll (sub-pixel precision)
    private var accumulatedScrollX: Double = 0.0
    private var accumulatedScrollY: Double = 0.0

    // Inertial scrolling
    private struct ScrollSample {
        let position: CGPoint
        let timestamp: Date
    }
    private var scrollSamples: [ScrollSample] = []
    private var inertialScrollTimer: Timer?
    private var isInertialScrolling = false
    private var currentInertialVelocity: CGPoint = .zero

    /// True when in drag (selection) mode via long press.
    var isDragMode: Bool { phase == .dragging }

    init(context: GestureContext, stateMachine: GestureStateMachine) {
        self.context = context
        self.stateMachine = stateMachine
    }

    // MARK: - GestureRecognizer

    func touchBegan(fingerId: Int, touch: Touch, context: GestureContext) {
        guard context.isSingleTouchAllowed else { return }

        beganDuringInertialScroll = isInertialScrolling
        beganAfterRecentScroll = Date().timeIntervalSince(lastScrollEndTime) < scrollEndBounceWindow
        stopInertialScrolling()

        phase = .pending
        activeFingerId = fingerId
        touchDownPosition = touch
        lastTouch = touch
        accumulatedScrollX = 0
        accumulatedScrollY = 0

        startLongPressTimer(fingerId: fingerId)

        Log.debug(.scroll, "SingleFingerScroll: touch began F\(fingerId) → pending")
    }

    func touchMoved(fingerId: Int, touch: Touch, context: GestureContext) {
        guard context.isSingleTouchAllowed else { return }
        guard fingerId == activeFingerId else { return }

        switch phase {
        case .idle:
            return

        case .pending:
            // Absorb movement until it exceeds scrollCommitThreshold.
            // Use max displacement from start (not cumulative path) — prevents accidental
            // scroll commit from jitter, but correctly commits on any directional intent.
            guard let start = touchDownPosition else { return }
            let moved = context.pixelDistance(from: start, to: touch)
            if moved >= scrollCommitThreshold {
                // Commit to scrolling — cancel long-press timer
                phase = .scrolling
                cancelLongPressTimer()
                // Move cursor to finger position so scroll events target the window under the finger,
                // not whatever window happens to be under the current (unrelated) cursor position.
                context.emit(.mouseMove(touch))
                // Set lastTouch to current so the first scroll delta starts fresh.
                lastTouch = touch
                Log.debug(.scroll, "SingleFingerScroll: pending → scroll (moved \(String(format: "%.0f", moved))px)")
            }
            // While pending, no events are emitted (jitter absorbed).

        case .scrolling:
            emitScrollDelta(to: touch)
            lastTouch = touch

        case .dragging:
            if !dragMoveStarted {
                // First movement after long press — emit mouseDown at the original touch-down
                // position so selection starts where the finger landed, not where it moved to.
                let origin = touchDownPosition ?? touch
                context.isDragging[fingerId] = true
                context.emit(.mouseDown(origin))
                dragMoveStarted = true
                Log.debug(.scroll, "SingleFingerScroll: drag started (first move)")
            }
            context.emit(.mouseDrag(touch))
            lastTouch = touch
        }
    }

    func touchEnded(fingerId: Int, touch: Touch, context: GestureContext) {
        cancelLongPressTimer()

        switch phase {
        case .idle:
            break

        case .pending:
            // Finger lifted without moving much — potential tap.
            // Only handle true single-finger gestures (maxFingerCount==1).
            // Multi-finger taps (right-click) are handled by TouchHandler.
            //
            // Problem: on hardware, finger A and finger B arrive sequentially. If A lifts
            // before B's DOWN event is processed, maxFingerCount is still 1 and we'd
            // erroneously emit a click (moving the cursor).
            //
            // Fix: defer the click via a short multi-touch recognition window
            // (tapTimeout, default 100ms). If a second finger arrives during this window,
            // reset() is called, which cancels the pending click — no cursor movement.
            //
            // Also suppress click when:
            // - this touch began during inertial scrolling (user was stopping the scroll), or
            // - this touch began within the bounce window after a scroll ended (hardware bounce artifact)
            if context.maxFingerCount == 1 && !beganDuringInertialScroll && !beganAfterRecentScroll {
                if pendingClickTimer != nil {
                    // Second tap arrived before the first pending click fired → fast double-click.
                    let firstTouch = pendingClickTouch ?? touch
                    cancelPendingClickTimer()
                    context.emit(.doubleClick(firstTouch))
                    lastTapTime = nil
                    lastTapTouch = nil
                    Log.debug(.scroll, "SingleFingerScroll: fast double-tap → double-click")
                } else {
                    pendingClickTouch = touch
                    pendingClickFingerId = fingerId
                    let delay = context.config.gestures.tapTimeout
                    pendingClickTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                        self?.firePendingClick()
                    }
                    Log.debug(.scroll, "SingleFingerScroll: tap pending (\(Int(delay * 1000))ms window)")
                }
            }

        case .scrolling:
            lastScrollEndTime = Date()
            let velocity = getCurrentVelocity()
            if velocity != .zero {
                startInertialScrolling(velocity: velocity)
            }
            Log.debug(.scroll, "SingleFingerScroll: scroll ended")

        case .dragging:
            if dragMoveStarted {
                context.emit(.mouseUp(touch))
                context.isDragging.removeValue(forKey: fingerId)
                Log.debug(.scroll, "SingleFingerScroll: drag ended")
            } else {
                // Long press with no movement — do nothing.
                Log.debug(.scroll, "SingleFingerScroll: long press without movement → ignored")
            }
            dragMoveStarted = false
        }

        phase = .idle
        activeFingerId = -1
        touchDownPosition = nil
        lastTouch = nil
        scrollSamples.removeAll()
        accumulatedScrollX = 0
        accumulatedScrollY = 0
    }

    func reset() {
        cancelLongPressTimer()
        cancelPendingClickTimer()
        stopInertialScrolling()
        phase = .idle
        activeFingerId = -1
        touchDownPosition = nil
        lastTouch = nil
        scrollSamples.removeAll()
        accumulatedScrollX = 0
        accumulatedScrollY = 0
        lastTapTime = nil
        lastTapTouch = nil
        beganDuringInertialScroll = false
        beganAfterRecentScroll = false
        dragMoveStarted = false
    }

    // MARK: - Pending Click

    private func firePendingClick() {
        pendingClickTimer = nil
        guard let touch = pendingClickTouch else { return }
        pendingClickTouch = nil

        let now = Date()
        if let last = lastTapTime, now.timeIntervalSince(last) < context.config.gestures.doubleClickDelay {
            Log.debug(.scroll, "SingleFingerScroll: tap → double-click")
            context.emit(.secondClick(lastTapTouch ?? touch))
            lastTapTime = nil
            lastTapTouch = nil
        } else {
            Log.debug(.scroll, "SingleFingerScroll: tap → click at (\(touch.x),\(touch.y))")
            context.emit(.mouseDown(touch))
            context.emit(.mouseUp(touch))
            lastTapTime = now
            lastTapTouch = touch
        }
    }

    private func cancelPendingClickTimer() {
        pendingClickTimer?.invalidate()
        pendingClickTimer = nil
        pendingClickTouch = nil
        pendingClickFingerId = -1
    }

    /// Called by TouchHandler when a new finger arrives while this pending click is active,
    /// indicating that the pending click belongs to a two-finger tap sequence (A up before B down).
    /// Cancels the pending click so the cursor doesn't move.
    func cancelPendingTapForMultiTouch() {
        Log.debug(.scroll, "SingleFingerScroll: cancelling pending tap for multi-touch (F\(pendingClickFingerId))")
        cancelPendingClickTimer()
    }

    // MARK: - Scroll Emission

    private func emitScrollDelta(to current: Touch) {
        guard let last = lastTouch else { return }

        let lastScreen = DisplayManager.shared.convertHardwareToAppKitScreen(
            hardwareX: last.x, hardwareY: last.y)
        let curScreen = DisplayManager.shared.convertHardwareToAppKitScreen(
            hardwareX: current.x, hardwareY: current.y)

        let rawDX = curScreen.x - lastScreen.x
        let rawDY = curScreen.y - lastScreen.y

        accumulatedScrollX += rawDX
        accumulatedScrollY += context.config.scroll.invertY ? -rawDY : rawDY

        let sdx = Int32(accumulatedScrollX)
        let sdy = Int32(accumulatedScrollY)

        if sdx != 0 || sdy != 0 {
            let mousePos = NSEvent.mouseLocation
            context.emit(.scroll(deltaX: sdx, deltaY: sdy, at: mousePos))
            accumulatedScrollX -= Double(sdx)
            accumulatedScrollY -= Double(sdy)
        }

        addScrollSample(position: curScreen)
    }

    // MARK: - Long Press (drag/select mode)

    private func startLongPressTimer(fingerId: Int) {
        cancelLongPressTimer()
        longPressTimer = Timer.scheduledTimer(
            withTimeInterval: context.config.gestures.contextMenuDelay,
            repeats: false
        ) { [weak self] _ in
            self?.enterDragMode(fingerId: fingerId)
        }
    }

    private func enterDragMode(fingerId: Int) {
        // Only enter drag from pending state — if user is already scrolling, don't interrupt.
        guard phase == .pending else { return }

        phase = .dragging
        dragMoveStarted = false
        // mouseDown is intentionally deferred until the first touchMoved — if the user lifts
        // without moving, the long press does nothing (no accidental click/selection).
        Log.debug(.scroll, "SingleFingerScroll: pending → drag (long press, awaiting movement)")
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    // MARK: - Inertial Scrolling

    func stopInertialScrolling() {
        guard isInertialScrolling else { return }
        // Record the stop time so beganAfterRecentScroll can suppress bounce clicks.
        // This works regardless of whether TouchHandler or touchBegan calls us first.
        lastScrollEndTime = Date()
        isInertialScrolling = false
        inertialScrollTimer?.invalidate()
        inertialScrollTimer = nil
        currentInertialVelocity = .zero
        accumulatedScrollX = 0
        accumulatedScrollY = 0
    }

    private func addScrollSample(position: CGPoint) {
        guard context.config.scroll.inertialEnabled else { return }
        let now = Date()
        scrollSamples.append(ScrollSample(position: position, timestamp: now))
        scrollSamples = scrollSamples.filter {
            now.timeIntervalSince($0.timestamp) <= context.config.scroll.inertialVelocityTimeWindow
        }
        if scrollSamples.count > 30 { scrollSamples.removeFirst(scrollSamples.count - 30) }
    }

    private func getCurrentVelocity() -> CGPoint {
        guard context.config.scroll.inertialEnabled, scrollSamples.count >= 2 else { return .zero }
        let latest = scrollSamples.last!
        let earliest = scrollSamples.first!
        let dt = latest.timestamp.timeIntervalSince(earliest.timestamp)
        guard dt >= context.config.scroll.inertialMinTimeInterval else { return .zero }
        return CGPoint(
            x: (latest.position.x - earliest.position.x) / dt,
            y: (latest.position.y - earliest.position.y) / dt
        )
    }

    private func startInertialScrolling(velocity: CGPoint) {
        guard context.config.scroll.inertialEnabled else { return }
        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        guard speed >= context.config.scroll.inertialMinVelocity else { return }

        currentInertialVelocity = CGPoint(
            x: velocity.x,
            y: context.config.scroll.invertY ? -velocity.y : velocity.y
        )
        isInertialScrolling = true
        accumulatedScrollX = 0
        accumulatedScrollY = 0

        let interval = 1.0 / context.config.scroll.inertialFrameRate
        inertialScrollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateInertialScrolling()
        }

        Log.debug(.scroll, "SingleFingerScroll: inertial started, speed=\(String(format: "%.0f", speed))")
    }

    private func updateInertialScrolling() {
        guard isInertialScrolling else {
            stopInertialScrolling()
            return
        }

        let dt = 1.0 / context.config.scroll.inertialFrameRate
        let dx = currentInertialVelocity.x * dt
        let dy = currentInertialVelocity.y * dt

        if abs(dx) >= 0.5 || abs(dy) >= 0.5 {
            accumulatedScrollX += dx
            accumulatedScrollY += dy

            let sdx = Int32(accumulatedScrollX)
            let sdy = Int32(accumulatedScrollY)

            if sdx != 0 || sdy != 0 {
                let pos = NSEvent.mouseLocation
                context.emit(.scroll(deltaX: sdx, deltaY: sdy, at: pos))
                accumulatedScrollX -= Double(sdx)
                accumulatedScrollY -= Double(sdy)
            }
        }

        currentInertialVelocity.x *= context.config.scroll.inertialDecayFactor
        currentInertialVelocity.y *= context.config.scroll.inertialDecayFactor

        let speed = sqrt(currentInertialVelocity.x * currentInertialVelocity.x +
                         currentInertialVelocity.y * currentInertialVelocity.y)
        if speed < context.config.scroll.inertialMinSpeed {
            stopInertialScrolling()
        }
    }
}
