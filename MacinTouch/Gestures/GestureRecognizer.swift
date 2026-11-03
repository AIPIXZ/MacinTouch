//
//  GestureRecognizer.swift
//  MacinTouch
//
//  Protocol and shared context for gesture recognition.
//

import AppKit
import Foundation

// MARK: - Gesture Action

/// Actions that gesture recognizers can request the system to perform.
enum GestureAction {
    // Mouse
    case mouseDown(Touch)
    case mouseUp(Touch)
    case mouseMove(Touch)
    case mouseDrag(Touch)
    case rightClick(Touch)
    case doubleClick(Touch)
    // Continuation when the first single click has already been emitted.
    case secondClick(Touch)

    // Scroll
    case scroll(deltaX: Int32, deltaY: Int32, at: CGPoint)  // AppKit screen coords
    case continuousScroll(deltaX: Int32, deltaY: Int32, at: CGPoint, phase: Int64, momentum: Int64)

    // Pinch
    case pinchZoom(magnification: Double, at: Touch)
    case pinchEnd(Touch)

    // Four-finger
    case fourFingerGesture(InputType, at: CGPoint)  // AppKit screen coords
    case dockGesture(motion: Int32, phase: Int32, progress: Double)
    case dockSwipe(phase: Int32, progress: Double)

    // Modifier key management
    case ensureCommandKeyReleased
    case cleanupAllModifierKeys
}

// MARK: - Gesture Recognizer Protocol

protocol GestureRecognizer: AnyObject {
    /// Called when a finger touches down.
    func touchBegan(fingerId: Int, touch: Touch, context: GestureContext)

    /// Called when a finger moves.
    func touchMoved(fingerId: Int, touch: Touch, context: GestureContext)

    /// Called when a finger lifts up.
    func touchEnded(fingerId: Int, touch: Touch, context: GestureContext)

    /// Called when the overall finger count changes.
    func fingerCountChanged(count: Int, context: GestureContext)

    /// Reset all internal state.
    func reset()
}

/// Default implementations so recognizers only override what they need.
extension GestureRecognizer {
    func touchBegan(fingerId: Int, touch: Touch, context: GestureContext) {}
    func touchMoved(fingerId: Int, touch: Touch, context: GestureContext) {}
    func touchEnded(fingerId: Int, touch: Touch, context: GestureContext) {}
    func fingerCountChanged(count: Int, context: GestureContext) {}
}

// MARK: - Gesture State

/// The unified gesture state machine states.
enum GestureState: Equatable {
    case idle           // No fingers touching
    case singleTouch    // One finger active
    case multiTouch     // Two or more fingers active
}

// MARK: - Gesture Context

/// Shared mutable context passed to all gesture recognizers.
/// Contains the current touch state and provides action dispatch.
class GestureContext {
    // Runtime config — updated when GUI saves changes
    var config = DriverConfig()

    // Current touches
    var activeTouches: [Int: Touch] = [:]
    var gestureStartPoints: [Int: Touch] = [:]

    // State
    var state: GestureState = .idle
    var maxFingerCount: Int = 0

    // Track whether WE have emitted a leftMouseDown without a matching leftMouseUp.
    // Used by GestureStateMachine to know if a mouseUp release is needed on multi-touch transition,
    // instead of relying on CGEventSource.buttonState which reflects hardware state and can be
    // stale (our synthetic events posted via cghidEventTap may not yet have updated it).
    var mouseButtonIsDown: Bool = false

    // Protection timers
    var fourFingerProtectionEndTime: Date = .distantPast
    var rightClickProtectionEndTime: Date = .distantPast
    var eventFilterEndTime: Date = .distantPast

    // Tracking per-finger state
    var isDragging: [Int: Bool] = [:]
    var hasTriggeredRightClick: [Int: Bool] = [:]

    // Drag continuation: for stylus tip bounce compensation
    var lastDragEndTime: Date = .distantPast
    var lastDragEndPosition: Touch? = nil

    // Action dispatch - set by TouchHandler
    var onAction: ((GestureAction) -> Void)?

    // MARK: Convenience

    var activeFingerCount: Int { activeTouches.count }

    var isSingleTouchAllowed: Bool {
        guard state == .singleTouch else { return false }
        guard Date() >= fourFingerProtectionEndTime else {
            Log.debug(.gesture, "Four-finger protection active, blocking single touch")
            return false
        }
        return true
    }

    var isInFourFingerProtection: Bool {
        Date() < fourFingerProtectionEndTime
    }

    var isInEventFilterPeriod: Bool {
        Date() < eventFilterEndTime
    }

    var isInRightClickProtection: Bool {
        Date() < rightClickProtectionEndTime
    }

    func emit(_ action: GestureAction) {
        onAction?(action)
    }

    /// Calculate pixel distance between two touches using DisplayManager.
    func pixelDistance(from a: Touch, to b: Touch) -> Double {
        let aScreen = DisplayManager.shared.convertHardwareToAppKitScreen(hardwareX: a.x, hardwareY: a.y)
        let bScreen = DisplayManager.shared.convertHardwareToAppKitScreen(hardwareX: b.x, hardwareY: b.y)
        let dx = bScreen.x - aScreen.x
        let dy = bScreen.y - aScreen.y
        return sqrt(dx * dx + dy * dy)
    }

    /// How long after a drag ends we still treat a new DOWN as drag continuation (stylus bounce).
    var dragContinuationWindow: TimeInterval { 0.25 }

    var isDragContinuation: Bool {
        lastDragEndPosition != nil &&
        Date().timeIntervalSince(lastDragEndTime) < dragContinuationWindow
    }

    func resetAll() {
        activeTouches.removeAll()
        gestureStartPoints.removeAll()
        isDragging.removeAll()
        hasTriggeredRightClick.removeAll()
        lastDragEndPosition = nil
        state = .idle
        maxFingerCount = 0
        mouseButtonIsDown = false
    }
}
