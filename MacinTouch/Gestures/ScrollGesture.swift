//
//  ScrollGesture.swift
//  MacinTouch
//
//  Two-finger scroll gesture: detection, direct mapping, smoothing, inertial scrolling.
//

import AppKit
import Foundation

/// Short launch pulse followed by exponential braking. Preserve the integral
/// of the previous decay model so a shorter tail does not sacrifice distance.
struct ScrollInertiaCurve {
    let timeConstant: Double
    let launchDuration: Double
    private let peakMultiplier: Double
    init(decay: Double, frameRate: Double) {
        let safeDecay = decay.isFinite ? min(0.9999, max(0.01, decay)) : 0.96
        let safeRate = frameRate.isFinite ? max(1, frameRate) : 60
        let originalTimeConstant = -1 / (log(safeDecay) * safeRate)
        launchDuration = min(0.05, originalTimeConstant * 0.2)
        timeConstant = originalTimeConstant * 0.5
        // Normalize launch + tail area to retain the previous total distance.
        peakMultiplier = (originalTimeConstant - launchDuration * 0.5) /
            (timeConstant + launchDuration * 0.5)
    }
    var peakTime: Double { launchDuration }
    func velocityMultiplier(at time: Double) -> Double {
        let t = max(0, time)
        if t <= launchDuration {
            let u = t / launchDuration
            return 1 + (peakMultiplier - 1) * u * u * (3 - 2 * u)
        }
        return peakMultiplier * exp(-(t - launchDuration) / timeConstant)
    }
    func integral(from start: Double, to end: Double) -> Double {
        func cumulative(_ time: Double) -> Double {
            let t = max(0, time)
            if t <= launchDuration {
                let u = t / launchDuration
                return t + (peakMultiplier - 1) * launchDuration * (pow(u, 3) - 0.5 * pow(u, 4))
            }
            return launchDuration * (1 + peakMultiplier) * 0.5 +
                peakMultiplier * timeConstant * (1 - exp(-(t - launchDuration) / timeConstant))
        }
        return max(0, cumulative(end) - cumulative(start))
    }
}

class ScrollGesture: GestureRecognizer {
    private let context: GestureContext
    private let stateMachine: GestureStateMachine

    // Scroll state
    private(set) var isScrolling = false
    private var scrollStartCenter: Touch?
    private var lastScrollCenter: Touch?
    private let clock: () -> TimeInterval
    private var scrollAnchor: CGPoint?
    private var scrollPhaseActive = false
    private var momentumPhaseActive = false
    private var lastInertialTime = 0.0
    private var velocityRejectionReason = "none"

    // Smoothing
    private var scrollHistory: [(deltaX: Double, deltaY: Double)] = []
    private var smoothedScrollX: Double = 0.0
    private var smoothedScrollY: Double = 0.0
    private var accumulatedScrollX: Double = 0.0
    private var accumulatedScrollY: Double = 0.0

    // Inertial scrolling
    private struct ScrollSample {
        let position: CGPoint
        let timestamp: TimeInterval
    }
    private var scrollSamples: [ScrollSample] = []
    private var inertialScrollTimer: Timer?
    private var isInertialScrolling = false
    private var currentInertialVelocity: CGPoint = .zero
    private var initialInertialVelocity: CGPoint = .zero
    private var inertiaElapsed = 0.0
    private var inertiaCurve = ScrollInertiaCurve(decay: 0.96, frameRate: 60)

    init(context: GestureContext, stateMachine: GestureStateMachine, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.context = context
        self.stateMachine = stateMachine
        self.clock = clock
    }

    // MARK: - Public Interface

    func startScrolling(center: Touch, sampleStartTime: TimeInterval? = nil) {
        stopInertialScrolling(reason: "new-scroll")
        scrollSamples.removeAll()
        scrollAnchor = nil
        scrollPhaseActive = false
        if context.config.scroll.inertialEnabled {
            let position = DisplayManager.shared.convertHardwareToAppKitScreen(hardwareX: center.x, hardwareY: center.y)
            scrollSamples.append(ScrollSample(position: position, timestamp: sampleStartTime ?? clock()))
        }
        isScrolling = true
        scrollStartCenter = center
        lastScrollCenter = nil
        resetSmoothing()

        // Release only a button that this driver actually pressed.
        if context.mouseButtonIsDown { context.emit(.mouseUp(center)) }

        Log.info(.scroll, "Two-finger scroll started")
    }

    func stopScrolling(allowInertia: Bool = true) {
        guard isScrolling else { return }
        let velocity = allowInertia ? getCurrentVelocity() : .zero
        Log.info(.scroll, "ScrollTrace release samples=\(scrollSamples.count) spanMs=\(Int(((scrollSamples.last?.timestamp ?? clock()) - (scrollSamples.first?.timestamp ?? clock())) * 1000)) lastAgeMs=\(Int((clock() - (scrollSamples.last?.timestamp ?? clock())) * 1000)) velocity=\(String(format: "%.1f", hypot(velocity.x, velocity.y))) reason=\(allowInertia ? velocityRejectionReason : "gesture-change")")
        if scrollPhaseActive, let anchor = scrollAnchor {
            context.emit(.continuousScroll(deltaX: 0, deltaY: 0, at: anchor, phase: 4, momentum: 0))
        }
        scrollPhaseActive = false
        if velocity != .zero { startInertialScrolling(velocity: velocity) }

        isScrolling = false
        scrollStartCenter = nil
        lastScrollCenter = nil
        resetSmoothing()
        scrollSamples.removeAll()
        context.isDragging.removeAll()

        // A switch to another gesture must not filter its incoming fingers.
        if allowInertia {
            stateMachine.startEventFilter(duration: context.config.gestures.eventFilterDuration, reason: "two-finger-scroll-ended")
        }
        stateMachine.startRightClickProtection(duration: 0.5)

        // Clean up any lingering mouse/right-button state
        if context.mouseButtonIsDown { cleanupMouseState() }

        Log.info(.scroll, "Two-finger scroll ended")
    }

    func handleScroll(touch1: Touch, touch2: Touch, distance: Double) {
        guard distance >= context.config.scroll.minFingerDistance && distance <= context.config.scroll.maxFingerDistance else {
            Log.info(.scroll, "ScrollTrace scroll-stop reason=finger-distance-out-of-range distance=\(String(format: "%.1f", distance))")
            Log.debug(.scroll, "Finger distance out of range: \(String(format: "%.1f", distance))px")
            stopScrolling(allowInertia: false)
            return
        }

        let centerX = Double(touch1.x + touch2.x) / 2.0
        let centerY = Double(touch1.y + touch2.y) / 2.0
        let currentCenter = Touch(x: Int(centerX), y: Int(centerY))

        // Determine reference point for incremental scroll
        let referenceCenter: Touch
        if let last = lastScrollCenter {
            referenceCenter = last
        } else if let start = scrollStartCenter {
            referenceCenter = start
        } else {
            return
        }

        let incrementalDistance = context.pixelDistance(from: referenceCenter, to: currentCenter)

        // Check threshold on first scroll only
        if lastScrollCenter == nil && incrementalDistance < context.config.scroll.scrollThreshold {
            return
        }

        // Convert to screen coordinates for delta calculation
        let refScreen = DisplayManager.shared.convertHardwareToAppKitScreen(
            hardwareX: referenceCenter.x, hardwareY: referenceCenter.y)
        let curScreen = DisplayManager.shared.convertHardwareToAppKitScreen(
            hardwareX: currentCenter.x, hardwareY: currentCenter.y)

        let screenDeltaX = curScreen.x - refScreen.x
        let screenDeltaY = curScreen.y - refScreen.y

        let shouldScroll = (lastScrollCenter != nil) ||
            (abs(screenDeltaY) >= context.config.scroll.scrollThreshold || abs(screenDeltaX) >= context.config.scroll.scrollThreshold)

        if shouldScroll && (abs(screenDeltaX) > 0.1 || abs(screenDeltaY) > 0.1) {
            let rawDeltaX: Double
            let rawDeltaY: Double

            if context.config.scroll.directMappingEnabled {
                rawDeltaX = screenDeltaX
                rawDeltaY = context.config.scroll.invertY ? -screenDeltaY : screenDeltaY
            } else {
                rawDeltaX = abs(screenDeltaX) * (screenDeltaX >= 0 ? 1.0 : -1.0)
                rawDeltaY = abs(screenDeltaY) * (screenDeltaY >= 0 ? -1.0 : 1.0)
            }

            let smoothed = applySmoothScrolling(deltaX: rawDeltaX, deltaY: rawDeltaY)
            accumulatedScrollX += smoothed.smoothX
            accumulatedScrollY += smoothed.smoothY

            let scrollDeltaX = Int32(accumulatedScrollX)
            let scrollDeltaY = Int32(accumulatedScrollY)

            if scrollDeltaX != 0 || scrollDeltaY != 0 {
                let scrollPoint = DisplayManager.shared.convertHardwareToAppKitScreen(
                    hardwareX: currentCenter.x, hardwareY: currentCenter.y)
                if scrollAnchor == nil { scrollAnchor = scrollPoint }
                context.emit(.continuousScroll(deltaX: scrollDeltaX, deltaY: scrollDeltaY,
                                               at: scrollAnchor!, phase: scrollPhaseActive ? 2 : 1, momentum: 0))
                scrollPhaseActive = true

                accumulatedScrollX -= Double(scrollDeltaX)
                accumulatedScrollY -= Double(scrollDeltaY)

                Log.debug(.scroll, "Scroll: dX=\(scrollDeltaX) dY=\(scrollDeltaY)")
            }

            lastScrollCenter = currentCenter

            // Add sample for inertial velocity calculation
            let screenCenter = DisplayManager.shared.convertHardwareToAppKitScreen(
                hardwareX: Int(centerX), hardwareY: Int(centerY))
            addScrollSample(position: screenCenter)

            scrollStartCenter = currentCenter
        }
    }

    func stopInertialScrolling(reason: String = "requested") {
        guard isInertialScrolling else { return }
        Log.info(.scroll, "ScrollTrace inertia-stop reason=\(reason) hadMomentumOutput=\(momentumPhaseActive)")
        if momentumPhaseActive, let anchor = scrollAnchor {
            context.emit(.continuousScroll(deltaX: 0, deltaY: 0, at: anchor, phase: 0, momentum: 3))
        }
        momentumPhaseActive = false
        isInertialScrolling = false
        inertialScrollTimer?.invalidate()
        inertialScrollTimer = nil
        currentInertialVelocity = .zero
        Log.debug(.scroll, "Inertial scrolling stopped")
    }

    func reset() {
        stopInertialScrolling(reason: "reset")
        if scrollPhaseActive, let anchor = scrollAnchor {
            context.emit(.continuousScroll(deltaX: 0, deltaY: 0, at: anchor, phase: 8, momentum: 0))
        }
        scrollPhaseActive = false
        scrollAnchor = nil
        isScrolling = false
        scrollStartCenter = nil
        lastScrollCenter = nil
        resetSmoothing()
        scrollSamples.removeAll()
    }

    // MARK: - Smoothing

    private func applySmoothScrolling(deltaX: Double, deltaY: Double) -> (smoothX: Double, smoothY: Double) {
        guard context.config.scroll.smoothingEnabled else {
            return (deltaX, deltaY)
        }

        scrollHistory.append((deltaX: deltaX, deltaY: deltaY))
        if scrollHistory.count > context.config.scroll.historySize {
            scrollHistory.removeFirst()
        }

        if context.config.scroll.directMappingEnabled {
            return applyDirectMappingSmoothing(deltaX: deltaX, deltaY: deltaY)
        } else {
            return applyTraditionalSmoothing()
        }
    }

    private func applyDirectMappingSmoothing(deltaX: Double, deltaY: Double) -> (smoothX: Double, smoothY: Double) {
        let weights = [0.5, 0.3, 0.2]
        var weightedX = 0.0, weightedY = 0.0, totalWeight = 0.0

        for (index, data) in scrollHistory.reversed().enumerated() {
            let w = weights[min(index, weights.count - 1)]
            weightedX += data.deltaX * w
            weightedY += data.deltaY * w
            totalWeight += w
        }

        if totalWeight > 0 {
            weightedX /= totalWeight
            weightedY /= totalWeight
        }

        smoothedScrollX = smoothedScrollX * (1.0 - context.config.scroll.smoothingFactor) + weightedX * context.config.scroll.smoothingFactor
        smoothedScrollY = smoothedScrollY * (1.0 - context.config.scroll.smoothingFactor) + weightedY * context.config.scroll.smoothingFactor

        return (
            abs(smoothedScrollX) < context.config.scroll.minDelta ? 0.0 : smoothedScrollX,
            abs(smoothedScrollY) < context.config.scroll.minDelta ? 0.0 : smoothedScrollY
        )
    }

    private func applyTraditionalSmoothing() -> (smoothX: Double, smoothY: Double) {
        let avgX = scrollHistory.map(\.deltaX).reduce(0, +) / Double(scrollHistory.count)
        let avgY = scrollHistory.map(\.deltaY).reduce(0, +) / Double(scrollHistory.count)

        smoothedScrollX = smoothedScrollX * (1.0 - context.config.scroll.smoothingFactor) + avgX * context.config.scroll.smoothingFactor
        smoothedScrollY = smoothedScrollY * (1.0 - context.config.scroll.smoothingFactor) + avgY * context.config.scroll.smoothingFactor

        return (
            abs(smoothedScrollX) < context.config.scroll.minDelta ? 0.0 : smoothedScrollX,
            abs(smoothedScrollY) < context.config.scroll.minDelta ? 0.0 : smoothedScrollY
        )
    }

    private func resetSmoothing() {
        scrollHistory.removeAll()
        smoothedScrollX = 0.0
        smoothedScrollY = 0.0
        accumulatedScrollX = 0.0
        accumulatedScrollY = 0.0
    }

    // MARK: - Inertial Scrolling

    private func addScrollSample(position: CGPoint) {
        guard context.config.scroll.inertialEnabled else { return }
        let now = clock()
        let sample = ScrollSample(position: position, timestamp: now)
        // Coalesce element callbacks into fixed 4ms buckets. A count of HID
        // callbacks is not a duration; retaining only 30 could erase the entire
        // useful velocity window. Preserve the initial sample within its bucket.
        if scrollSamples.count > 1, let last = scrollSamples.last,
           floor(last.timestamp / 0.004) == floor(now / 0.004) {
            scrollSamples[scrollSamples.count - 1] = sample
        } else {
            scrollSamples.append(sample)
        }
        scrollSamples = scrollSamples.filter {
            (now - $0.timestamp) <= context.config.scroll.inertialVelocityTimeWindow
        }
    }

    private func getCurrentVelocity() -> CGPoint {
        velocityRejectionReason = "ready"
        guard context.config.scroll.inertialEnabled else { velocityRejectionReason = "disabled"; return .zero }
        guard scrollSamples.count >= 2 else { velocityRejectionReason = "insufficient-samples"; return .zero }

        let latest = scrollSamples.last!
        guard clock() - latest.timestamp <= context.config.scroll.inertialVelocityTimeWindow else { velocityRejectionReason = "paused-before-release"; return .zero }
        let earliest = scrollSamples.first!
        let elapsed = latest.timestamp - earliest.timestamp
        guard elapsed > 0.001 else { velocityRejectionReason = "no-time-baseline"; return .zero }
        // Short real flicks still count. A conservative denominator prevents a
        // tiny interval from producing a huge velocity instead of rejecting it.
        let dt = max(elapsed, context.config.scroll.inertialMinTimeInterval)

        return CGPoint(
            x: (latest.position.x - earliest.position.x) / dt,
            y: (latest.position.y - earliest.position.y) / dt
        )
    }

    private func calculateAccelerationBoost() -> Double {
        guard context.config.scroll.accelerationEnabled, scrollSamples.count >= 3 else { return 1.0 }

        let now = clock()
        let recent = scrollSamples.filter {
            (now - $0.timestamp) <= context.config.scroll.accelerationWindow
        }
        guard recent.count >= 3 else { return 1.0 }

        let mid = recent.count / 2
        let firstHalf = Array(recent[0..<mid])
        let secondHalf = Array(recent[mid...])

        func avgSpeed(_ samples: [ScrollSample]) -> Double {
            guard samples.count >= 2 else { return 0 }
            let dp = CGPoint(
                x: samples.last!.position.x - samples.first!.position.x,
                y: samples.last!.position.y - samples.first!.position.y
            )
            let dt = (samples.last!.timestamp - samples.first!.timestamp)
            guard dt > 0.001 else { return 0 }
            let v = CGPoint(x: dp.x / dt, y: dp.y / dt)
            return sqrt(v.x * v.x + v.y * v.y)
        }

        let s1 = avgSpeed(firstHalf)
        let s2 = avgSpeed(secondHalf)
        let accel = (s2 - s1) / max(s1, 100.0)

        var boost = 1.0
        if accel > 0.1 {
            boost = 1.0 + accel * context.config.scroll.accelerationBoost
        } else if accel < -0.1 {
            boost = 1.0 + accel * context.config.scroll.accelerationBoost * 0.5
        }

        return max(context.config.scroll.minBoostFactor, min(boost, context.config.scroll.maxBoostFactor))
    }

    private func startInertialScrolling(velocity: CGPoint) {
        guard context.config.scroll.inertialEnabled else { return }

        let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        guard speed >= context.config.scroll.inertialMinVelocity else {
            Log.info(.scroll, "ScrollTrace inertia-skipped reason=below-minimum-velocity speed=\(String(format: "%.1f", speed)) threshold=\(context.config.scroll.inertialMinVelocity)")
            return
        }

        let boost = calculateAccelerationBoost()
        Log.info(.scroll, "ScrollTrace inertia-start speed=\(String(format: "%.1f", speed)) boost=\(String(format: "%.2f", boost))")
        currentInertialVelocity = CGPoint(
            x: velocity.x * boost,
            y: ((context.config.scroll.directMappingEnabled ? context.config.scroll.invertY : true) ? -velocity.y : velocity.y) * boost
        )
        initialInertialVelocity = currentInertialVelocity
        inertiaElapsed = 0
        inertiaCurve = ScrollInertiaCurve(decay: context.config.scroll.inertialDecayFactor,
                                         frameRate: context.config.scroll.inertialFrameRate)
        Log.info(.scroll, "ScrollTrace inertia-curve=launch-brake peakMs=\(Int(inertiaCurve.peakTime * 1000))")
        isInertialScrolling = true
        lastInertialTime = clock()

        let interval = 1.0 / context.config.scroll.inertialFrameRate
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateInertialScrolling()
        }
        inertialScrollTimer = timer
        RunLoop.current.add(timer, forMode: .common)

        Log.debug(.scroll, "Inertial scrolling started: speed=\(String(format: "%.0f", speed))px/s, boost=\(String(format: "%.2f", boost))")
    }

    private func updateInertialScrolling() {
        guard isInertialScrolling else {
            stopInertialScrolling()
            return
        }

        let now = clock()
        let dt = min(0.05, max(0, now - lastInertialTime))
        lastInertialTime = now
        let configuredGain = context.config.scroll.inertialDistanceMultiplier ?? 2.0
        let gain = configuredGain.isFinite ? min(8, max(0.1, configuredGain)) : 2.0
        // Scale emitted displacement, not the decaying velocity. Scaling the
        // latter would postpone crossing inertialMinSpeed and extend duration.
        let nextElapsed = inertiaElapsed + dt
        let travel = inertiaCurve.integral(from: inertiaElapsed, to: nextElapsed)
        let dx = initialInertialVelocity.x * travel * gain
        let dy = initialInertialVelocity.y * travel * gain

        if dt > 0 {
            accumulatedScrollX += dx
            accumulatedScrollY += dy

            let sdx = Int32(accumulatedScrollX)
            let sdy = Int32(accumulatedScrollY)

            if sdx != 0 || sdy != 0 {
                if let anchor = scrollAnchor {
                    context.emit(.continuousScroll(deltaX: sdx, deltaY: sdy, at: anchor,
                                                   phase: 0, momentum: momentumPhaseActive ? 2 : 1))
                    momentumPhaseActive = true
                }
                accumulatedScrollX -= Double(sdx)
                accumulatedScrollY -= Double(sdy)
            }
        }

        // Evaluate the same continuous curve at every refresh rate. Integrating
        // above rather than sampling v*dt preserves distance under timer jitter.
        inertiaElapsed = nextElapsed
        let multiplier = inertiaCurve.velocityMultiplier(at: inertiaElapsed)
        currentInertialVelocity.x = initialInertialVelocity.x * multiplier
        currentInertialVelocity.y = initialInertialVelocity.y * multiplier

        let speed = sqrt(currentInertialVelocity.x * currentInertialVelocity.x +
                         currentInertialVelocity.y * currentInertialVelocity.y)
        if inertiaElapsed >= inertiaCurve.peakTime && speed < context.config.scroll.inertialMinSpeed {
            stopInertialScrolling(reason: "velocity-decayed")
        }
    }

    // MARK: - Cleanup

    private func cleanupMouseState() {
        // Release only our own held button; hardware button state may belong to
        // a physical mouse or lag behind posted synthetic events.
        let position = scrollAnchor ?? NSEvent.mouseLocation
        let hardware = DisplayManager.shared.convertAppKitScreenToHardware(screenPoint: position)
        context.emit(.mouseUp(Touch(x: hardware.x, y: hardware.y)))
    }
}
