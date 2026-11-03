//
//  TwoFingerDetector.swift
//  MacinTouch
//
//  Detects whether a two-finger gesture is scroll or pinch,
//  then delegates to the appropriate handler.
//

import Foundation

class TwoFingerDetector: GestureRecognizer {
    private let context: GestureContext
    private let stateMachine: GestureStateMachine
    private let clock: () -> TimeInterval
    private var detectionStartTime: TimeInterval?
    let scrollGesture: ScrollGesture
    let pinchGesture: PinchGesture

    // Detection state machine
    enum State {
        case idle
        case detecting
        case scrolling
        case pinching
    }
    private(set) var state: State = .idle

    // Detection data
    private var initialTouch1: Touch?
    private var initialTouch2: Touch?
    private var initialDistance: Double?


    init(context: GestureContext, stateMachine: GestureStateMachine, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.context = context
        self.stateMachine = stateMachine
        self.clock = clock
        self.scrollGesture = ScrollGesture(context: context, stateMachine: stateMachine, clock: clock)
        self.pinchGesture = PinchGesture(context: context)
    }

    // MARK: - Public

    /// Called each frame when exactly 2 fingers are active.
    func update(touch1: Touch, touch2: Touch) {
        let distance = context.pixelDistance(from: touch1, to: touch2)

        switch state {
        case .idle:
            startDetection(touch1: touch1, touch2: touch2, distance: distance)

        case .detecting:
            continueDetection(touch1: touch1, touch2: touch2, distance: distance)

        case .scrolling:
            guard scrollGesture.isScrolling else {
                resetState()
                return
            }
            scrollGesture.handleScroll(touch1: touch1, touch2: touch2, distance: distance)

        case .pinching:
            guard pinchGesture.isPinching else {
                resetState()
                return
            }
            pinchGesture.handlePinch(touch1: touch1, touch2: touch2, currentDistance: distance)
        }
    }

    /// Called when fingers leave or count changes away from 2.
    func endTwoFingerGesture(allowInertia: Bool = true) {
        if scrollGesture.isScrolling {
            scrollGesture.stopScrolling(allowInertia: allowInertia && context.activeFingerCount < 2)
        }
        if pinchGesture.isPinching {
            pinchGesture.stopPinching()
            if context.activeFingerCount < 2 {
                // As with scrolling, slot compaction on release can briefly
                // report a fresh single DOWN. Do not turn the tail into a tap.
                stateMachine.startEventFilter(duration: context.config.gestures.eventFilterDuration,
                                              reason: "two-finger-pinch-ended")
                stateMachine.startRightClickProtection(duration: 0.5)
            }
        }
        resetState()
    }

    func reset() {
        scrollGesture.reset()
        pinchGesture.reset()
        resetState()
    }

    // MARK: - Detection

    private func startDetection(touch1: Touch, touch2: Touch, distance: Double) {
        detectionStartTime = clock()
        state = .detecting
        initialTouch1 = touch1
        initialTouch2 = touch2
        initialDistance = distance

        Log.debug(.pinch, "Two-finger detection started, distance: \(String(format: "%.1f", distance))px")
    }

    private func continueDetection(touch1: Touch, touch2: Touch, distance: Double) {
        guard let first = initialTouch1, let second = initialTouch2 else {
            resetState()
            return
        }
        let accumulatedDistanceChange = abs(distance - (initialDistance ?? distance))
        let initialCenter = Touch(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        let curCenter = Touch(x: (touch1.x + touch2.x) / 2, y: (touch1.y + touch2.y) / 2)
        // Compare net displacement with net distance change. Summing the path
        // counted jitter as intent; counting 20 X/Y callbacks was not a timeout.
        let accumulatedCenterMovement = context.pixelDistance(from: initialCenter, to: curCenter)
        guard max(accumulatedDistanceChange, accumulatedCenterMovement) >= 8 else { return }

        // Core distinction:
        //   Scroll → center moves significantly, finger distance barely changes
        //   Pinch  → finger distance changes significantly, center barely moves
        let isPinch = context.config.pinch.enabled
            && accumulatedDistanceChange > accumulatedCenterMovement * 1.2
            && accumulatedDistanceChange > 5.0

        if isPinch {
            Log.debug(.pinch, "Detected pinch (distChange=\(String(format: "%.1f", accumulatedDistanceChange)) centerMove=\(String(format: "%.1f", accumulatedCenterMovement)))")
            transitionToPinch(center: curCenter, distance: distance)
        } else {
            Log.debug(.scroll, "Detected scroll (distChange=\(String(format: "%.1f", accumulatedDistanceChange)) centerMove=\(String(format: "%.1f", accumulatedCenterMovement)))")
            transitionToScroll(center: initialCenter)
            scrollGesture.handleScroll(touch1: touch1, touch2: touch2, distance: distance)
        }
    }

    // MARK: - State Transitions

    private func transitionToScroll(center: Touch) {
        state = .scrolling
        scrollGesture.startScrolling(center: center, sampleStartTime: detectionStartTime)
    }

    private func transitionToPinch(center: Touch, distance: Double) {
        state = .pinching
        pinchGesture.startPinching(center: center, distance: distance)
    }

    private func resetState() {
        detectionStartTime = nil
        state = .idle
        initialTouch1 = nil
        initialTouch2 = nil
        initialDistance = nil
    }
}
