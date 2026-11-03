//
//  FourFingerGesture.swift
//  MacinTouch
//
//  Four-finger gesture recognition: swipe (up/down/left/right) and long press (tap).
//

import AppKit
import Foundation

class FourFingerGesture: GestureRecognizer {
    private let context: GestureContext
    private let stateMachine: GestureStateMachine

    // Gesture state
    private var isActive = false
    private var startTime: TimeInterval?
    private var startCenter: Touch?
    private var startPositions: [Int: Touch] = [:]
    private var recognition = MultiFingerArbiter()
    private var shortcutDispatched = false
    private var candidateTimer: Timer?
    private var candidateDeadline: TimeInterval?
    private var gestureDetected: Bool { recognition.selected != nil }

    private struct Frame {
        let motion: MultiFingerEvidence
        let hardwareCenter: Touch
    }
    private var initialScreenPoints: [Int: CGPoint] = [:]

    // DockSwipe state. Accept four or five contacts; freeze membership after axis lock.
    private var dockSwipeActive = false
    private var dockMotion: Int32 = 1
    private var startSpan = 0.0
    private var translationAllowed = true
    private var dockPinchRange = 1.0
    private var dockVerticalRange = 1.0
    private var dockVerticalOrigin = 0.0
    private var dockSwipeProgress = 0.0
    private var dockSwipeOriginX = 0.0
    private var dockSwipeRange = 1.0
    private var lastDockSwipeFrame = 0.0
    private var waitingForRelease = false
    // Only unselected candidates may survive a short, same-ID interruption.
    // Native gestures keep their existing first-lift completion semantics.
    private var candidateGapTimer: Timer?
    private var candidateGapDeadline: TimeInterval?
    private var candidateGapMissing: Set<Int> = []
    private var candidateSubset: Set<Int> = []
    private var candidateSubsetSince = 0.0
    private var lockedPinchThumb: Int?

    private func clearCandidateGap() {
        candidateGapTimer?.invalidate()
        candidateGapTimer = nil
        candidateGapDeadline = nil
        candidateGapMissing = []
        candidateSubset = []
    }

    private func waitForCandidateContact() {
        let missing = Set(startPositions.keys).subtracting(context.activeTouches.keys)
        if candidateGapDeadline != nil && missing != candidateGapMissing {
            Log.info(.fourFinger, "PinchTrace seq=\(diagnosticSequence) stage=contact-gap-update missing=\(missing.sorted()) actual=\(context.activeTouches.keys.sorted()) deadlineUnchanged=true")
        }
        candidateGapMissing = missing
        guard candidateGapDeadline == nil else { return }
        cancelCandidateCheck()
        cancelLongPressTimer()
        let deadline = ProcessInfo.processInfo.systemUptime + 0.120
        candidateGapDeadline = deadline
        Log.info(.fourFinger, "PinchTrace seq=\(diagnosticSequence) stage=contact-gap waiting=120ms expected=\(startPositions.keys.sorted()) actual=\(context.activeTouches.keys.sorted())")
        let timer = Timer(timeInterval: 0.120, repeats: false) { [weak self] _ in
            guard let self, self.candidateGapDeadline == deadline else { return }
            self.check()
        }
        candidateGapTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    // One summary per contact sequence, to separate recognition from system delivery.
    private var diagnosticSamples = 0
    private var diagnosticMinSpanChange = 0.0
    private var diagnosticMaxSpanChange = 0.0
    private var diagnosticMaxCenterTravel = 0.0
    private var diagnosticPinchCandidates = 0
    private var diagnosticCoherenceRejects = 0
    private var diagnosticSequence = 0
    private var lastDiagnosticTime = -Double.infinity
    private var lastDiagnosticState = ""

    private func tracePinch(_ sample: Frame, stage: String, force: Bool = false) {
        guard Log.isEnabled(.info, .fourFinger) else { return }
        let motion = sample.motion
        let direction = motion.scale > 0.005 ? "spread" : (motion.scale < -0.005 ? "pinch" : "neutral")
        let state = "\(stage):\(direction):\(motion.thumbID.map(String.init) ?? "unknown")"
        let now = ProcessInfo.processInfo.systemUptime
        guard force || state != lastDiagnosticState || now - lastDiagnosticTime >= 0.08 else { return }
        lastDiagnosticTime = now
        lastDiagnosticState = state
        let current = screenPoints(context.activeTouches.filter { startPositions[$0.key] != nil })
        let points = initialScreenPoints.keys.sorted().compactMap { id -> String? in
            guard let a = initialScreenPoints[id], let b = current[id] else { return nil }
            return String(format: "%d:(%.1f,%.1f)>(%.1f,%.1f)", id, a.x, a.y, b.x, b.y)
        }.joined(separator: " ")
        Log.info(.fourFinger, "PinchTrace seq=\(diagnosticSequence) t=\(String(format: "%.3f", now - (startTime ?? now))) stage=\(stage) contacts=\(motion.contactCount) direction=\(direction) scale=\(String(format: "%.4f", motion.scale)) coherent=\(motion.pinchCoherent) spanDelta=\(String(format: "%.2f", motion.spanChange)) center=(\(String(format: "%.1f", motion.dx)),\(String(format: "%.1f", motion.dy))) parallel=\(motion.parallelVotes) pan=(\(String(format: "%.1f", motion.panDX)),\(String(format: "%.1f", motion.panDY))) verticalVotes=\(motion.verticalFingerVotes) motion=\(dockSwipeActive ? dockMotion : 0) progress=\(String(format: "%.4f", dockSwipeProgress)) ambiguous=\(recognition.isAmbiguous) \(motion.diagnosticDetails) points=[\(points)]")
    }

    private var nativeHorizontalEnabled: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 &&
        context.config.fourFinger.nativeHorizontalSwipe != false
    }

    private var nativePinchEnabled: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 &&
        context.config.fourFinger.nativePinchGesture != false
    }
    private var nativeVerticalEnabled: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 &&
        context.config.fourFinger.nativeVerticalSwipe != false
    }

    private func screenPoints(_ touches: [Int: Touch]) -> [Int: CGPoint] {
        touches.mapValues {
            DisplayManager.shared.convertHardwareToAppKitScreen(hardwareX: $0.x, hardwareY: $0.y)
        }
    }

    private func frame(allowPartial: Bool = false) -> Frame? {
        let participating = context.activeTouches.filter { startPositions[$0.key] != nil }
        let initial = allowPartial ? initialScreenPoints.filter { participating[$0.key] != nil } : initialScreenPoints
        let thumb = lockedPinchThumb ?? MultiFingerEvidence(initial: initialScreenPoints, current: initialScreenPoints)?.thumbID
        // Missing thumb evidence cannot be replaced with a guessed frozen point.
        if allowPartial, let thumb, participating[thumb] == nil { return nil }
        guard let motion = MultiFingerEvidence(initial: initial, current: screenPoints(participating), thumbHint: thumb) else { return nil }
        let points = Array(participating.values)
        return Frame(motion: motion, hardwareCenter: Touch(
            x: points.map(\.x).reduce(0, +) / points.count,
            y: points.map(\.y).reduce(0, +) / points.count))
    }

    private func admitFifthContact() {
        // Retain original starts for existing fingers; only the newcomer starts now.
        for (id, touch) in context.activeTouches where startPositions[id] == nil {
            startPositions[id] = touch
        }
        let points = Array(startPositions.values)
        startCenter = Touch(x: points.map(\.x).reduce(0, +) / points.count,
                            y: points.map(\.y).reduce(0, +) / points.count)
        initialScreenPoints = screenPoints(startPositions)
        startSpan = MultiFingerEvidence(initial: initialScreenPoints, current: initialScreenPoints)?.initialSpan ?? 0
        Log.info(.fourFinger, "Fifth contact joined; preserved existing movement")
    }

    private func emitDock(_ phase: Int32) {
        if dockMotion == 1 {
            context.emit(.dockSwipe(phase: phase, progress: dockSwipeProgress))
        } else {
            context.emit(.dockGesture(motion: dockMotion, phase: phase, progress: dockSwipeProgress))
        }
    }

    // Buffer mechanism (waiting for 4th finger)
    private var bufferTimer: Timer?
    private var bufferActive = false

    // Long press timer
    private var longPressTimer: Timer?
    private var longPressPending = false

    init(context: GestureContext, stateMachine: GestureStateMachine) {
        self.context = context
        self.stateMachine = stateMachine
    }

    deinit { candidateTimer?.invalidate(); candidateGapTimer?.invalidate() }

    private func cancelCandidateCheck() {
        candidateTimer?.invalidate()
        candidateTimer = nil
        candidateDeadline = nil
    }

    private func scheduleCandidateCheck(at requestedDeadline: TimeInterval? = nil) {
        guard let deadline = requestedDeadline ?? recognition.nextEvaluationTime else { cancelCandidateCheck(); return }
        guard deadline != candidateDeadline else { return }
        cancelCandidateCheck()
        candidateDeadline = deadline
        let timer = Timer(timeInterval: max(0.001, deadline - ProcessInfo.processInfo.systemUptime), repeats: false) { [weak self] _ in
            guard let self else { return }
            self.candidateDeadline = nil
            self.candidateTimer = nil
            if self.isActive { self.check() }
        }
        candidateTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    // MARK: - Public: called from TouchHandler on each coordinate update

    func check() {
        guard context.config.fourFinger.enabled else {
            if isActive { reset() }
            return
        }
        let count = context.activeFingerCount
        if count == 0 {
            if isActive { endGesture() }
            waitingForRelease = false
            cancelBuffer()
            return
        }
        guard !waitingForRelease else { return }
        if isActive {
            var expected = Set(startPositions.keys)
            let actual = Set(context.activeTouches.keys)
            if let deadline = candidateGapDeadline, ProcessInfo.processInfo.systemUptime >= deadline {
                Log.info(.fourFinger, "PinchTrace seq=\(diagnosticSequence) stage=contact-gap-timeout")
                endGesture()
                return
            }
            // A late fifth DOWN can precede the return of one of the original
            // four slots in the same report. Admit it without declaring a
            // replacement or resetting the existing gap deadline.
            if !gestureDetected && expected.count == 4 && expected.union(actual).count == 5 && count <= 5 {
                admitFifthContact()
                expected = Set(startPositions.keys)
            }
            if candidateGapDeadline != nil && expected.isSubset(of: actual) && count <= 5 {
                clearCandidateGap()
                recognition.reset()
                Log.info(.fourFinger, "PinchTrace seq=\(diagnosticSequence) stage=contact-restored preservedInitialPositions=true")
            }
            if count > 5 {
                endGesture(cancelled: true)
            } else if !expected.isSubset(of: actual) {
                if !gestureDetected && actual.isSubset(of: expected) {
                    waitForCandidateContact()
                    // A report may deliver several UPs before its DOWNs. A
                    // transient one/two-contact snapshot cannot classify motion,
                    // but must not terminate an otherwise recoverable candidate.
                    // The first gap's deadline still bounds the entire wait.
                    if count < 3 {
                        cancelCandidateCheck()
                        recognition.reset()
                        candidateSubset = []
                        return
                    }
                    let now = ProcessInfo.processInfo.systemUptime
                    if candidateSubset != actual {
                        candidateSubset = actual
                        candidateSubsetSince = now
                        recognition.reset()
                    }
                    // Require a stable set of observed IDs before interpreting
                    // its geometry; never include coordinates of absent contacts.
                    if now < candidateSubsetSince + 0.016 {
                        scheduleCandidateCheck(at: candidateSubsetSince + 0.016)
                    } else {
                        detectSwipe(allowPartial: true)
                    }
                    return
                }
                // End on the first participating finger lifted; replacements cancel.
                endGesture(cancelled: count >= expected.count)
            } else if actual != expected && !gestureDetected {
                admitFifthContact()
                detectSwipe()
            } else {
                // Once locked, keep the original contacts. An extra finger must not
                // change the centroid/span and cause a jump in native progress.
                detectSwipe()
            }
        } else if (4...5).contains(count) {
            cancelBuffer()
            startGesture()
        } else if count == 3 && !bufferActive {
            startBuffer()
        } else if count < 3 {
            cancelBuffer()
        }
    }

    func reset() {
        endGesture(cancelled: true)
        cancelBuffer()
        waitingForRelease = context.activeFingerCount > 0
    }

    // MARK: - Buffer (waiting for 4th finger)

    private func startBuffer() {
        bufferActive = true
        bufferTimer = Timer.scheduledTimer(withTimeInterval: context.config.fourFinger.detectionBuffer, repeats: false) { [weak self] _ in
            self?.bufferTimeout()
        }
        Log.debug(.fourFinger, "Waiting for 4th finger...")
    }

    private func cancelBuffer() {
        guard bufferActive else { return }
        bufferActive = false
        bufferTimer?.invalidate()
        bufferTimer = nil
    }

    private func bufferTimeout() {
        Log.debug(.fourFinger, "Buffer timeout, 4th finger not detected")
        bufferActive = false
        bufferTimer = nil
    }

    // MARK: - Gesture Lifecycle

    private func startGesture() {
        let touches = Array(context.activeTouches.values)
        guard (4...5).contains(touches.count) else { return }

        // Calculate center
        let cx = Double(touches.map(\.x).reduce(0, +)) / Double(touches.count)
        let cy = Double(touches.map(\.y).reduce(0, +)) / Double(touches.count)
        let center = Touch(x: Int(cx), y: Int(cy))

        // Check average finger spacing
        var totalDist = 0.0
        for t in touches {
            totalDist += context.pixelDistance(from: center, to: t)
        }
        let avgDist = totalDist / Double(touches.count)

        let minimum = nativePinchEnabled ? min(20, context.config.fourFinger.minDistance) : context.config.fourFinger.minDistance
        guard avgDist >= minimum && avgDist <= context.config.fourFinger.maxDistance else {
            Log.debug(.fourFinger, "Finger spacing out of range: \(String(format: "%.1f", avgDist))px")
            return
        }

        translationAllowed = avgDist >= context.config.fourFinger.minDistance
        initialScreenPoints = screenPoints(context.activeTouches)
        startSpan = MultiFingerEvidence(initial: initialScreenPoints, current: initialScreenPoints)?.initialSpan ?? 0
        diagnosticSamples = 0
        diagnosticMinSpanChange = 0
        diagnosticMaxSpanChange = 0
        diagnosticMaxCenterTravel = 0
        diagnosticPinchCandidates = 0
        diagnosticCoherenceRejects = 0
        lockedPinchThumb = nil
        diagnosticSequence += 1
        lastDiagnosticTime = -Double.infinity
        lastDiagnosticState = ""
        dockMotion = 1
        dockSwipeProgress = 0
        isActive = true
        startTime = ProcessInfo.processInfo.systemUptime
        startCenter = center
        recognition.reset()
        shortcutDispatched = false

        startPositions.removeAll()
        for (id, touch) in context.activeTouches {
            startPositions[id] = touch
        }

        // Start long press timer
        if translationAllowed { startLongPressTimer(at: center) }

        Log.info(.fourFinger, "Multi-finger gesture started (\(touches.count) contacts), avg distance: \(String(format: "%.1f", avgDist))px")
    }

    private func endGesture(cancelled: Bool = false) {
        clearCandidateGap()
        cancelCandidateCheck()
        guard isActive else { return }

        // A lifted contact may already be absent, so the last complete trace is
        // retained above; this line always records terminal phase and progress.
        Log.info(.fourFinger, "PinchTrace seq=\(diagnosticSequence) stage=end selected=\(recognition.selected?.rawValue ?? "none") motion=\(dockMotion) progress=\(String(format: "%.4f", dockSwipeProgress)) phase=\(cancelled ? 8 : 4) cancelled=\(cancelled) expected=\(startPositions.keys.sorted()) actual=\(context.activeTouches.keys.sorted())")

        cancelLongPressTimer()
        let result = dockSwipeActive ? "native-axis-\(dockMotion)" : (gestureDetected ? "shortcut-or-long-press" : "unclassified")
        Log.info(.fourFinger, "FourFinger summary result=\(result) cancelled=\(cancelled) samples=\(diagnosticSamples) startSpan=\(String(format: "%.1f", startSpan)) spanDelta[min=\(String(format: "%.1f", diagnosticMinSpanChange)) max=\(String(format: "%.1f", diagnosticMaxSpanChange))] maxCenterTravel=\(String(format: "%.1f", diagnosticMaxCenterTravel)) pinchCandidates=\(diagnosticPinchCandidates) coherenceRejects=\(diagnosticCoherenceRejects) finalProgress=\(String(format: "%.3f", dockSwipeProgress))")
        if dockSwipeActive {
            // Let Dock decide whether the current displacement should commit or snap back.
            // The output backend supplies pinch exit velocity; horizontal stays at zero.
            emitDock(2)
            emitDock(cancelled ? 8 : 4)
            dockSwipeActive = false
        }
        waitingForRelease = context.activeFingerCount > 0

        // Set protection periods
        stateMachine.startFourFingerProtection(duration: context.config.gestures.fourFingerProtectionDuration)
        stateMachine.startRightClickProtection(duration: context.config.gestures.rightClickProtectionDuration)

        isActive = false
        startTime = nil
        startCenter = nil
        startPositions.removeAll()
        initialScreenPoints.removeAll()
        recognition.reset()
        shortcutDispatched = false
        cancelBuffer()

        Log.info(.fourFinger, "Multi-finger gesture ended")
    }

    // MARK: - Swipe Detection

    private func detectSwipe(allowPartial: Bool = false) {
        guard let origin = startCenter, let start = startTime, !shortcutDispatched,
              let sample = frame(allowPartial: allowPartial) else { return }
        let motion = sample.motion
        let timestamp = ProcessInfo.processInfo.systemUptime
        diagnosticSamples += 1
        diagnosticMinSpanChange = min(diagnosticMinSpanChange, motion.spanChange)
        diagnosticMaxSpanChange = max(diagnosticMaxSpanChange, motion.spanChange)
        diagnosticMaxCenterTravel = max(diagnosticMaxCenterTravel, motion.distance)
        if nativePinchEnabled && abs(motion.scale) >= 0.10 && motion.pinchSignal >= 12 && !gestureDetected {
            diagnosticPinchCandidates += 1
            if !motion.pinchCoherent { diagnosticCoherenceRejects += 1 }
        }

        if dockSwipeActive {
            updateDockGesture(sample)
            tracePinch(sample, stage: "active-\(recognition.selected?.rawValue ?? "none")")
            return
        }
        // The same evidence cancels long press for every motion candidate.
        let tolerance = nativePinchEnabled ? min(8, context.config.fourFinger.longPressMaxMovement) : context.config.fourFinger.longPressMaxMovement
        if max(motion.maxContactTravel, abs(motion.spanChange)) > tolerance { cancelLongPressTimer() }

        let previous = recognition.selected
        let settings = MultiFingerArbiter.Settings(
            pinchEnabled: nativePinchEnabled, translationAllowed: translationAllowed && !allowPartial,
            translationThreshold: context.config.fourFinger.swipeEarlyDetection)
        guard let selected = recognition.update(motion, time: timestamp, settings: settings) else {
            tracePinch(sample, stage: allowPartial ? "candidate-partial" : "candidate")
            scheduleCandidateCheck()
            return
        }
        cancelCandidateCheck()
        cancelLongPressTimer()
        if previous == nil {
            tracePinch(sample, stage: "selected-\(selected.rawValue)", force: true)
            Log.info(.fourFinger, "Unified recognition selected=\(selected.rawValue) contacts=\(startPositions.count) dx=\(String(format: "%.1f", motion.dx)) dy=\(String(format: "%.1f", motion.dy)) scale=\(String(format: "%.3f", motion.scale)) votes=\(motion.translationVotes) coMoving=\(motion.coMovingVotes) thumb=\(motion.thumbID.map(String.init) ?? "unknown") fingerVerticalVotes=\(motion.verticalFingerVotes)")
        }
        switch selected {
        case .pinch:
            if allowPartial {
                // Freeze the observed subset only after a genuine radial gesture
                // wins. It keeps its original touchdown coordinates for progress.
                lockedPinchThumb = motion.thumbID
                startPositions = startPositions.filter { context.activeTouches[$0.key] != nil }
                initialScreenPoints = initialScreenPoints.filter { startPositions[$0.key] != nil }
                clearCandidateGap()
                Log.info(.fourFinger, "PinchTrace seq=\(diagnosticSequence) stage=partial-pinch-selected participants=\(startPositions.keys.sorted())")
            }
            dockMotion = 3
            let ratio = motion.scale > 0
                ? (context.config.fourFinger.dockSpreadTravelRatio ?? 1.0)
                : (context.config.fourFinger.dockPinchTravelRatio ?? 0.60)
            dockPinchRange = ratio.isFinite ? min(2, max(0.15, ratio)) : 0.60
            beginDockGesture(sample: sample)
        case .horizontal where nativeHorizontalEnabled:
            dockMotion = 1
            dockSwipeOriginX = Double(origin.x)
            let fraction = context.config.fourFinger.dockSwipeTravelFraction ?? 0.30
            let safeFraction = fraction.isFinite ? min(1, max(0.05, fraction)) : 0.30
            dockSwipeRange = max(1, context.config.device.touchResolutionX * safeFraction)
            beginDockGesture(sample: sample)
        case .vertical where nativeVerticalEnabled:
            dockMotion = 2
            dockVerticalOrigin = Double(origin.y)
            dockVerticalRange = max(1, context.config.device.touchResolutionY * 0.30)
            beginDockGesture(sample: sample)
        case .horizontal, .vertical:
            // Output policy only: recognition above is identical for native and
            // shortcut backends. Preserve the existing shortcut activation limits.
            guard motion.distance >= context.config.fourFinger.swipeThreshold,
                  motion.distance / max(timestamp - start, 0.001) >= context.config.fourFinger.swipeMinVelocity else { return }
            let type: InputType
            if selected == .horizontal {
                type = motion.dx > 0 ? .FOUR_FINGER_SWIPE_RIGHT : .FOUR_FINGER_SWIPE_LEFT
            } else {
                type = motion.dy > 0 ? .FOUR_FINGER_SWIPE_UP : .FOUR_FINGER_SWIPE_DOWN
            }
            shortcutDispatched = true
            let point = DisplayManager.shared.convertHardwareToAppKitScreen(
                hardwareX: sample.hardwareCenter.x, hardwareY: sample.hardwareCenter.y)
            context.emit(.fourFingerGesture(type, at: point))
        case .longPress:
            break
        }
    }

    private func beginDockGesture(sample: Frame) {
        cancelLongPressTimer()
        dockSwipeActive = true
        if dockMotion == 3 {
            dockSwipeProgress = max(-1, min(1, sample.motion.scale / max(0.15, dockPinchRange)))
        } else if dockMotion == 2 {
            dockSwipeProgress = max(-1, min(1, (dockVerticalOrigin - Double(sample.hardwareCenter.y)) / dockVerticalRange))
        } else {
            dockSwipeProgress = 0
        }
        lastDockSwipeFrame = 0
        emitDock(1)
        updateDockGesture(sample)
        tracePinch(sample, stage: "begin-native", force: true)
    }

    private func updateDockGesture(_ sample: Frame) {
        let progress: Double
        switch dockMotion {
        case 3: progress = sample.motion.scale / max(0.15, dockPinchRange)
        case 2: progress = (dockVerticalOrigin - Double(sample.hardwareCenter.y)) / dockVerticalRange
        default: progress = (Double(sample.hardwareCenter.x) - dockSwipeOriginX) / dockSwipeRange
        }
        dockSwipeProgress = max(-1, min(1, progress))
        let timestamp = ProcessInfo.processInfo.systemUptime
        if timestamp - lastDockSwipeFrame >= 0.008 {
            emitDock(2)
            lastDockSwipeFrame = timestamp
        }
    }

    // MARK: - Long Press

    private func startLongPressTimer(at center: Touch) {
        longPressPending = true
        longPressTimer = Timer.scheduledTimer(withTimeInterval: context.config.fourFinger.longPressDuration, repeats: false) { [weak self] _ in
            self?.fireLongPress(at: center)
        }
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        longPressPending = false
    }

    private func fireLongPress(at center: Touch) {
        guard longPressPending, isActive, !gestureDetected, Set(startPositions.keys).isSubset(of: Set(context.activeTouches.keys)) else { return }

        // Check that no finger has moved too far
        var maxMove = 0.0
        for (id, startPos) in startPositions {
            if let curPos = context.activeTouches[id] {
                maxMove = max(maxMove, context.pixelDistance(from: startPos, to: curPos))
            }
        }
        guard maxMove <= context.config.fourFinger.longPressMaxMovement else { return }

        guard recognition.selectLongPress() else { return }
        longPressPending = false
        shortcutDispatched = true

        let screenPoint = DisplayManager.shared.convertHardwareToAppKitScreen(
            hardwareX: center.x, hardwareY: center.y)
        context.emit(.fourFingerGesture(.FOUR_FINGER_TAP, at: screenPoint))

        Log.info(.fourFinger, "Long press triggered (Launchpad), max movement: \(String(format: "%.1f", maxMove))px")
    }
}
