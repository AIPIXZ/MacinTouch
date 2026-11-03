//
//  GestureStateMachine.swift
//  MacinTouch
//
//  Manages transitions between gesture states (idle/singleTouch/multiTouch).
//  Tracks finger count and manages protection timers.
//

import AppKit
import Foundation

class GestureStateMachine {
    private let context: GestureContext

    init(context: GestureContext) {
        self.context = context
    }

    /// Update the gesture state based on current active finger count.
    /// Returns true if the state changed.
    @discardableResult
    func update() -> Bool {
        let count = context.activeFingerCount
        let previous = context.state

        // Track max finger count
        if count > context.maxFingerCount {
            context.maxFingerCount = count
        }

        switch count {
        case 0:
            context.state = .idle
            context.maxFingerCount = 0
            context.hasTriggeredRightClick.removeAll()
            context.isDragging.removeAll()

            if previous != .idle {
                Log.debug(.gesture, "State: \(previous) -> idle (all fingers lifted)")
            }

        case 1:
            if context.state == .idle {
                context.state = .singleTouch
                Log.debug(.gesture, "State: idle -> singleTouch")
            }
            // If previously multiTouch with max > 1, keep multiTouch to prevent accidental single-finger ops
            // The state stays as multiTouch until all fingers lift (count == 0)

        default:
            let wasMultiTouch = context.state == .multiTouch
            context.state = .multiTouch

            if previous != .multiTouch {
                Log.debug(.gesture, "State: \(previous) -> multiTouch (fingers: \(count))")
            }

            // If transitioning from single to multi, release left button if we emitted a mouseDown.
            // Use our own mouseButtonIsDown flag instead of CGEventSource.buttonState:
            // buttonState checks hardware HID state which can be stale — our synthetic events
            // posted via cghidEventTap may not have propagated yet, causing false positives.
            if !wasMultiTouch && previous == .singleTouch {
                if context.mouseButtonIsDown {
                    Log.debug(.gesture, "Transitioning to multiTouch, releasing left mouse button")
                    if let firstTouch = context.activeTouches.values.first {
                        context.emit(.mouseUp(firstTouch))
                    }
                }
            }
        }

        return context.state != previous
    }

    /// Set event filter period to ignore delayed HID events.
    func startEventFilter(duration: TimeInterval, reason: String = "unspecified") {
        context.eventFilterEndTime = Date().addingTimeInterval(duration)
        Log.info(.fourFinger, "TouchTrace filter-start reason=\(reason) durationMs=\(Int(duration * 1000)) tracked=\(context.activeTouches.keys.sorted())")
        Log.debug(.gesture, "Event filter active for \(Int(duration * 1000))ms")
    }

    /// Set four-finger protection period.
    func startFourFingerProtection(duration: TimeInterval) {
        context.fourFingerProtectionEndTime = Date().addingTimeInterval(duration)
        Log.debug(.fourFinger, "Four-finger protection active for \(Int(duration * 1000))ms")
    }

    /// Set right-click protection period.
    func startRightClickProtection(duration: TimeInterval) {
        context.rightClickProtectionEndTime = Date().addingTimeInterval(duration)
        Log.debug(.singleTouch, "Right-click protection active for \(Int(duration * 1000))ms")
    }
}
