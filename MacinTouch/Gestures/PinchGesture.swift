//
//  PinchGesture.swift
//  MacinTouch
//
//  Two-finger pinch zoom gesture recognition.
//

import AppKit
import Foundation

class PinchGesture: GestureRecognizer {
    private let context: GestureContext

    // Pinch state
    private(set) var isPinching = false
    private var pinchStartDistance: Double = 0.0
    private var lastPinchDistance: Double = 0.0
    private var pinchCenter: Touch?

    init(context: GestureContext) {
        self.context = context
    }

    // MARK: - Public Interface

    func startPinching(center: Touch, distance: Double) {
        isPinching = true
        pinchStartDistance = distance
        lastPinchDistance = distance
        pinchCenter = center

        Log.info(.pinch, "Pinch zoom started, initial distance: \(String(format: "%.1f", distance))px")
    }

    func handlePinch(touch1: Touch, touch2: Touch, currentDistance: Double) {
        let currentCenter = Touch(
            x: (touch1.x + touch2.x) / 2,
            y: (touch1.y + touch2.y) / 2
        )

        if !isPinching {
            startPinching(center: currentCenter, distance: currentDistance)
            return
        }

        let distanceDelta = currentDistance - lastPinchDistance
        // Convert pixel distance change to a magnification value.
        // Positive = zoom in (fingers spreading), negative = zoom out (fingers pinching).
        let magnification = distanceDelta * context.config.pinch.scaleFactor / 100.0

        if abs(magnification) > 0.001 {
            context.emit(.pinchZoom(magnification: magnification, at: currentCenter))
            Log.debug(.pinch, "Pinch zoom: \(magnification > 0 ? "in" : "out") mag=\(String(format: "%.3f", magnification))")
        }

        lastPinchDistance = currentDistance
        pinchCenter = currentCenter
    }

    func stopPinching() {
        guard isPinching else { return }

        isPinching = false

        // Send magnify ended event
        if let center = pinchCenter {
            context.emit(.pinchEnd(center))
        }

        pinchStartDistance = 0.0
        lastPinchDistance = 0.0
        pinchCenter = nil

        Log.info(.pinch, "Pinch zoom ended")
    }

    func reset() {
        stopPinching()
    }
}
