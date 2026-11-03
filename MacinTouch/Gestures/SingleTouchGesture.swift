//
//  SingleTouchGesture.swift
//  MacinTouch
//
//  Single-finger gesture recognition: tap, double-tap, right-click (long press), drag.
//

import AppKit
import Foundation

class SingleTouchGesture: GestureRecognizer {
    private let context: GestureContext
    private let stateMachine: GestureStateMachine

    // Right-click (long press) timer
    private var contextMenuTimer: Timer?
    private var isContextMenuPending = false

    // Lazy mouseDown: finger is down but mouseDown hasn't been sent yet.
    // Sent when: drag threshold crossed (drag path) or finger lifts (tap path).
    // Cancelled when: right-click timer fires (so selection isn't lost) or multitouch begins.
    private var pendingMouseDownTouch: Touch? = nil
    private var pendingMouseDownFingerId: Int = -1
    private var mouseDownSent = false

    // Event history for double-click detection
    private var recentUpEvents: [(fingerId: Int, time: Date, touch: Touch)] = []
    private let maxRecentEvents = 10

    /// True only when mouseDown has been sent and the finger is actively dragging.
    var isActiveDragging: Bool { mouseDownSent }

    init(context: GestureContext, stateMachine: GestureStateMachine) {
        self.context = context
        self.stateMachine = stateMachine
    }

    // MARK: - GestureRecognizer

    func touchBegan(fingerId: Int, touch: Touch, context: GestureContext) {
        // Drag continuation: stylus tip bounced — resume drag immediately
        if context.isDragContinuation {
            pendingMouseDownTouch = nil
            pendingMouseDownFingerId = fingerId
            context.isDragging[fingerId] = true
            context.emit(.mouseDown(touch))
            mouseDownSent = true
            context.lastDragEndPosition = nil
            Log.debug(.singleTouch, "Drag continuation: F\(fingerId) resumed after tip bounce")
            return
        }

        // Store pending mouseDown (not sent yet — avoids deselecting text before intent is known)
        mouseDownSent = false
        pendingMouseDownTouch = touch
        pendingMouseDownFingerId = fingerId

        guard context.isSingleTouchAllowed else {
            Log.debug(.singleTouch, "Skipping single touch ops: state=\(context.state)")
            return
        }

        // Start right-click timer (unless in protection period)
        if !context.isInRightClickProtection {
            cancelContextMenuTimer()
            startContextMenuTimer(at: touch, fingerId: fingerId)
        }
    }

    func touchMoved(fingerId: Int, touch: Touch, context: GestureContext) {
        guard context.isSingleTouchAllowed else { return }

        guard let startPoint = context.gestureStartPoints[fingerId] else { return }
        let moveDistance = context.pixelDistance(from: startPoint, to: touch)
        let isCurrentlyDragging = context.isDragging[fingerId] ?? false

        if !isCurrentlyDragging && !mouseDownSent {
            if moveDistance > context.config.gestures.dragThreshold {
                // Commit to drag: send mouseDown now (user is clearly dragging, not long-pressing)
                pendingMouseDownTouch = nil
                cancelContextMenuTimer()
                context.isDragging[fingerId] = true
                context.emit(.mouseDown(touch))
                mouseDownSent = true
                Log.debug(.singleTouch, "Enter drag: F\(fingerId) dist=\(String(format: "%.1f", moveDistance))px, mouseDown sent")
            } else if moveDistance > context.config.gestures.movementThreshold {
                // Smaller movement: cancel right-click but don't commit mouseDown yet
                cancelContextMenuTimer()
            }
        }

        if mouseDownSent {
            context.emit(.mouseDrag(touch))
        } else {
            context.emit(.mouseMove(touch))
        }
    }

    func touchEnded(fingerId: Int, touch: Touch, context: GestureContext) {
        cancelContextMenuTimer()

        let hasRightClicked = context.hasTriggeredRightClick[fingerId] ?? false
        let wasPendingMouseDown = pendingMouseDownTouch != nil
        pendingMouseDownTouch = nil
        var emittedTap = false
        var emittedTapTouch = touch

        if wasPendingMouseDown {
            if context.isSingleTouchAllowed && !hasRightClicked {
                // Check for double-click BEFORE emitting — avoids sending extra tap events on 2nd tap
                // Note: finger is still in activeTouches here, so single-finger count == 1 (not 0)
                let recent = isPreviousTapRecent(fingerId: fingerId)
                let isTapDoubleClick = context.activeFingerCount == 1
                    && context.maxFingerCount == 1
                    && recent
                let clickTouch = isTapDoubleClick
                    ? (recentUpEvents.last(where: { $0.fingerId == fingerId })?.touch ?? touch)
                    : touch
                emittedTapTouch = clickTouch
                // Stationary taps may have no coordinate updates after DOWN.
                // Send a real move before the click so hover-dependent system UI
                // sees the touchdown location before receiving the button event.
                // Do this only once single-touch intent is confirmed on release.
                context.emit(.mouseMove(clickTouch))
                Log.info(.fourFinger, "TouchTrace tap-align-before-click slot=\(fingerId) hardware=(\(clickTouch.x),\(clickTouch.y))")
                Log.debug(.singleTouch, "Tap end: fingers=\(context.activeFingerCount) maxFingers=\(context.maxFingerCount) prevTapRecent=\(recent) → doubleClick=\(isTapDoubleClick)")
                if isTapDoubleClick {
                    Log.info(.fourFinger, "TouchTrace second-click-anchor rawHardware=(\(touch.x),\(touch.y)) firstClickHardware=(\(clickTouch.x),\(clickTouch.y))")
                    context.emit(.secondClick(clickTouch))
                    Log.debug(.singleTouch, "Double-click at (\(clickTouch.x), \(clickTouch.y))")
                } else {
                    context.emit(.mouseDown(touch))
                    context.emit(.mouseUp(touch))
                }
                emittedTap = true
            }
        } else if mouseDownSent && !hasRightClicked && context.isSingleTouchAllowed {
            // Drag path: finger released after dragging
            context.lastDragEndTime = Date()
            context.lastDragEndPosition = touch
            context.emit(.mouseUp(touch))
        }
        mouseDownSent = false

        // Only an actual single-touch tap can be the first half of a double tap.
        // Multi-touch releases, drags and suppressed touches must not seed it.
        if emittedTap {
            recentUpEvents.append((fingerId: fingerId, time: Date(), touch: emittedTapTouch))
            if recentUpEvents.count > maxRecentEvents {
                recentUpEvents.removeFirst()
            }
        } else {
            recentUpEvents.removeAll()
        }
    }

    func reset() {
        cancelContextMenuTimer()
        cancelDelayedMouseDown()
        recentUpEvents.removeAll()
    }

    // MARK: - Right-Click Timer

    private func startContextMenuTimer(at touch: Touch, fingerId: Int) {
        guard !context.isInRightClickProtection else { return }

        isContextMenuPending = true
        contextMenuTimer = Timer.scheduledTimer(withTimeInterval: context.config.gestures.contextMenuDelay, repeats: false) { [weak self] _ in
            self?.fireContextMenu(at: touch, fingerId: fingerId)
        }
        Log.debug(.singleTouch, "Long-press timer started (\(context.config.gestures.contextMenuDelay)s)")
    }

    private func fireContextMenu(at touch: Touch, fingerId: Int) {
        guard isContextMenuPending else { return }
        guard !context.isInRightClickProtection else {
            isContextMenuPending = false
            return
        }
        guard Date() >= context.fourFingerProtectionEndTime else {
            isContextMenuPending = false
            return
        }

        // Cancel pending mouseDown: right-click must not send mouseDown first,
        // otherwise any existing text selection would be lost before the menu appears.
        pendingMouseDownTouch = nil

        context.emit(.rightClick(touch))
        isContextMenuPending = false

        // Mark finger so touchEnded doesn't send an extra mouseUp
        if let activeFinger = context.activeTouches.keys.first {
            context.hasTriggeredRightClick[activeFinger] = true
        }
        Log.debug(.singleTouch, "Right-click triggered at (\(touch.x), \(touch.y))")
    }

    func cancelContextMenuTimer() {
        contextMenuTimer?.invalidate()
        contextMenuTimer = nil
        isContextMenuPending = false
    }

    // MARK: - Pending MouseDown (replaces delayed mouseDown timer)

    /// Cancel pending mouseDown without sending it.
    /// Called by TouchHandler when multitouch begins.
    func cancelDelayedMouseDown() {
        pendingMouseDownTouch = nil
        mouseDownSent = false
        recentUpEvents.removeAll()
    }

    // MARK: - Double-Click

    /// Returns true if the most recent recorded tap for this finger was within doubleClickDelay.
    /// Called BEFORE appending the current tap, so it checks the previous tap.
    private func isPreviousTapRecent(fingerId: Int) -> Bool {
        guard let last = recentUpEvents.last(where: { $0.fingerId == fingerId }) else { return false }
        return Date().timeIntervalSince(last.time) < context.config.gestures.doubleClickDelay
    }
}
