// Shared, side-effect-free motion analysis and arbitration for 4/5 contacts.
import Foundation
import CoreGraphics

enum MultiFingerKind: String {
    case pinch, horizontal, vertical, longPress
}

/// One consistent screen-space snapshot shared by every gesture candidate.
struct MultiFingerEvidence {
    let contactCount: Int
    let dx: Double
    let dy: Double
    let distance: Double
    let initialSpan: Double
    let spanChange: Double
    let scale: Double
    let pinchCoherent: Bool
    let translationVotes: Int
    let maxContactTravel: Double
    let movingContactCount: Int
    let coMovingVotes: Int
    let hasLaggingContacts: Bool
    let parallelVotes: Int
    let panDX: Double
    let panDY: Double
    let thumbID: Int?
    let verticalFingerVotes: Int
    let thumbRadialScale: Double?
    let diagnosticDetails: String
    var panDistance: Double { hypot(panDX, panDY) }
    var parallelHand: Bool { parallelVotes >= 3 && parallelVotes * 5 >= movingContactCount * 4 }
    var pinchSignal: Double { abs(scale) * initialSpan }

    init?(initial: [Int: CGPoint], current: [Int: CGPoint], thumbHint: Int? = nil) {
        let ids = initial.keys.sorted()
        guard (3...5).contains(ids.count), Set(ids) == Set(current.keys) else { return nil }
        let count = Double(ids.count)
        let start = CGPoint(x: initial.values.reduce(0) { $0 + $1.x } / count,
                            y: initial.values.reduce(0) { $0 + $1.y } / count)
        let end = CGPoint(x: current.values.reduce(0) { $0 + $1.x } / count,
                          y: current.values.reduce(0) { $0 + $1.y } / count)
        let dx = end.x - start.x, dy = end.y - start.y
        let distance = hypot(dx, dy)
        var votes = 0, maxTravel = 0.0
        var displacements: [CGPoint] = []
        for id in ids {
            let a = initial[id]!, b = current[id]!
            let x = b.x - a.x, y = b.y - a.y
            let travel = hypot(x, y)
            displacements.append(CGPoint(x: x, y: y))
            maxTravel = max(maxTravel, travel)
            if distance > 0 {
                let projection = (x * dx + y * dy) / distance
                if projection >= max(8, distance * 0.35) && projection >= travel * 0.8 { votes += 1 }
            }
        }
        var changes: [(ratio: Double, pixels: Double, initial: Double)] = []
        var startTotal = 0.0, endTotal = 0.0
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                let a = ids[i], b = ids[j]
                let before = hypot(initial[a]!.x - initial[b]!.x, initial[a]!.y - initial[b]!.y)
                let after = hypot(current[a]!.x - current[b]!.x, current[a]!.y - current[b]!.y)
                startTotal += before; endTotal += after
                changes.append(((after - before) / max(20, before), after - before, before))
            }
        }
        func median(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            guard !sorted.isEmpty else { return 0 }
            let middle = sorted.count / 2
            return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        }
        // Count support before comparing magnitude: one short initial pair or one
        // bad contact must not flip the sign chosen by the rest of the hand.
        let positive = changes.filter { $0.pixels > max(2, $0.initial * 0.025) }
        let negative = changes.filter { -$0.pixels > max(2, $0.initial * 0.025) }
        let sign: Double
        if positive.count != negative.count { sign = positive.count > negative.count ? 1 : -1 }
        else { sign = median(positive.map { $0.ratio }) >= -median(negative.map { $0.ratio }) ? 1 : -1 }
        let supported = sign > 0 ? positive : negative
        let supportedScale = median(supported.map { $0.ratio })
        let oppose = changes.filter { $0.pixels * sign < -max(8, $0.initial * 0.06) }.count
        var outward = 0, inward = 0
        for id in ids {
            let a = initial[id]!, b = current[id]!
            let rx = a.x - start.x, ry = a.y - start.y
            let radius = hypot(rx, ry)
            guard radius > 1 else { continue }
            let projection = ((b.x - a.x) * rx + (b.y - a.y) * ry) / radius * sign
            let tolerance = max(2, radius * 0.025)
            if projection > tolerance { outward += 1 }
            if projection < -tolerance { inward += 1 }
        }
        let broadPairSupport = supported.count >= 3 && oppose <= 1 && supported.count >= oppose * 2
        let radialHandSupport = supported.count >= 3 && outward >= 3 && inward <= 1
        // Unlike rigid matching, direction grouping tolerates different finger
        // speeds during an angled swipe. Preserve the majority's axis direction.
        let moving = displacements.filter { hypot($0.x, $0.y) >= 8 }
        let groups = moving.map { anchor in
            moving.filter { value in
                (value.x * anchor.x + value.y * anchor.y) >= hypot(value.x, value.y) * hypot(anchor.x, anchor.y) * 0.9
            }
        }
        let dominant = groups.max { $0.count < $1.count } ?? []
        // HID supplies contact IDs, not anatomical labels. Only identify a thumb
        // when its initial separation clearly exceeds the other contacts'. Keep
        // this estimate anchored to touchdown so motion cannot change identity.
        let nearest = ids.map { id -> (id: Int, distance: Double) in
            let point = initial[id]!
            let gap = ids.filter { $0 != id }.map {
                hypot(initial[$0]!.x - point.x, initial[$0]!.y - point.y)
            }.min()!
            return (id, gap)
        }
        let isolated = nearest.max { $0.distance < $1.distance }!
        let otherGaps = nearest.filter { $0.id != isolated.id }.map { $0.distance }
        let estimatedThumb = isolated.distance > median(otherGaps) * 1.4 &&
            isolated.distance > (otherGaps.max() ?? 0) * 1.2 ? isolated.id : nil
        let thumb = thumbHint.flatMap { initial[$0] == nil ? nil : $0 } ?? estimatedThumb
        thumbID = thumb
        let fingers = ids.filter { $0 != thumb }
        verticalFingerVotes = fingers.filter { id in
            let a = initial[id]!, b = current[id]!
            let x = b.x - a.x, y = b.y - a.y
            return abs(y) >= 8 && abs(y) > abs(x) * 1.15 && y * median(dominant.map { $0.y }) > 0
        }.count
        var thumbScale: Double?
        var thumbDistanceScale: Double?
        var partialThumbCoherent = false
        if let thumb {
            let a = initial[thumb]!, b = current[thumb]!
            // Four ordinary fingers contribute six internal pairs, versus only
            // four thumb/finger pairs. Their slight closing must not outvote an
            // opening thumb. Use the same signed measurement throughout the
            // gesture, including staggered reports and the animation updates.
            let thumbChanges = fingers.map { id -> Double in
                let before = hypot(initial[id]!.x - a.x, initial[id]!.y - a.y)
                let after = hypot(current[id]!.x - b.x, current[id]!.y - b.y)
                return (after - before) / max(20, before)
            }
            thumbDistanceScale = median(thumbChanges)
            partialThumbCoherent = ids.count == 3 &&
                (thumbChanges.allSatisfy { $0 >= 0.04 } || thumbChanges.allSatisfy { $0 <= -0.04 })
            let fingerStart = CGPoint(x: fingers.reduce(0) { $0 + initial[$1]!.x } / Double(fingers.count),
                                      y: fingers.reduce(0) { $0 + initial[$1]!.y } / Double(fingers.count))
            let fingerEnd = CGPoint(x: fingers.reduce(0) { $0 + current[$1]!.x } / Double(fingers.count),
                                    y: fingers.reduce(0) { $0 + current[$1]!.y } / Double(fingers.count))
            let tx = b.x - a.x, ty = b.y - a.y
            let fx = fingerEnd.x - fingerStart.x, fy = fingerEnd.y - fingerStart.y
            let before = hypot(a.x - fingerStart.x, a.y - fingerStart.y)
            let after = hypot(b.x - fingerEnd.x, b.y - fingerEnd.y)
            // Opposing thumb/finger motion distinguishes a closing/opening hand
            // from a swipe with a stationary or similarly moving thumb.
            if hypot(tx, ty) >= 8 && hypot(fx, fy) >= 8 &&
                tx * fx + ty * fy < -0.15 * hypot(tx, ty) * hypot(fx, fy) {
                let gapScale = (after - before) / max(20, before)
                // Opposing motion is a priority signal only if the robust
                // thumb/finger distances agree with the centroid gap direction.
                if gapScale * (thumbDistanceScale ?? 0) > 0 { thumbScale = thumbDistanceScale }
            }
        }
        thumbRadialScale = thumbScale
        func number(_ value: Double?) -> String { value.map { String(format: "%.4f", $0) } ?? "none" }
        let pairs = changes.map { String(format: "%.3f", $0.ratio) }.joined(separator: ",")
        diagnosticDetails = "source=\(thumbDistanceScale == nil ? "all-pairs" : "thumb-pairs") thumb=\(thumb.map(String.init) ?? "unknown") thumbScale=\(number(thumbDistanceScale)) opposingThumbScale=\(number(thumbScale)) pairScale=\(number(supportedScale)) pairSupport=+\(positive.count)/-\(negative.count) radialVotes=\(outward)/\(inward) pairs=[\(pairs)]"
        parallelVotes = dominant.count
        panDX = median(dominant.map { $0.x })
        panDY = median(dominant.map { $0.y })
        contactCount = ids.count
        self.dx = dx; self.dy = dy; self.distance = distance
        initialSpan = startTotal / Double(changes.count)
        spanChange = (endTotal - startTotal) / Double(changes.count)
        scale = thumbDistanceScale ?? supportedScale
        pinchCoherent = broadPairSupport || radialHandSupport || partialThumbCoherent || (thumbScale.map { abs($0) >= 0.04 } ?? false)
        translationVotes = votes
        maxContactTravel = maxTravel
        movingContactCount = displacements.filter { hypot($0.x, $0.y) >= 8 }.count
        hasLaggingContacts = displacements.contains { hypot($0.x, $0.y) < maxTravel * 0.35 }
        // Find a rigidly co-moving group, rather than merely similar directions.
        // Three fingers swiping together with a sticky thumb are still a swipe.
        coMovingVotes = displacements.map { anchor -> Int in
            let travel = hypot(anchor.x, anchor.y)
            guard travel >= 8, distance > 0,
                  (anchor.x * dx + anchor.y * dy) / distance >= travel * 0.8 else { return 0 }
            let tolerance = max(6, travel * 0.25)
            return displacements.filter { hypot($0.x - anchor.x, $0.y - anchor.y) <= tolerance }.count
        }.max() ?? 0
    }
}

/// Recognition is independent of whether the selected gesture uses native events
/// or a keyboard shortcut. Ambiguous evidence keeps observing; selection locks.
struct MultiFingerArbiter {
    struct Settings {
        var pinchEnabled = true
        var translationAllowed = true
        var translationThreshold = 30.0
    }
    private(set) var selected: MultiFingerKind?
    private(set) var isAmbiguous = false
    private(set) var nextEvaluationTime: TimeInterval?
    private var ambiguitySince: TimeInterval?
    private var partialPinchSince: TimeInterval?

    mutating func reset() { self = MultiFingerArbiter() }

    mutating func selectLongPress() -> Bool {
        guard selected == nil, !isAmbiguous else { return false }
        selected = .longPress
        return true
    }

    @discardableResult
    mutating func update(_ motion: MultiFingerEvidence, time: TimeInterval, settings: Settings) -> MultiFingerKind? {
        nextEvaluationTime = nil
        if let selected { return selected }
        let radial = settings.pinchEnabled && motion.pinchCoherent && abs(motion.scale) >= 0.04
        let radialFloor = max(4, min(12, motion.initialSpan * 0.06))
        let pinchReady = radial && abs(motion.scale) >= 0.10 && motion.pinchSignal >= radialFloor
        let axis: MultiFingerKind?
        if abs(motion.panDX) > abs(motion.panDY) * 1.15 { axis = .horizontal }
        else if abs(motion.panDY) > abs(motion.panDX) * 1.15 { axis = .vertical }
        else { axis = nil }
        // Vertical swipes require four non-thumb contacts when a thumb can be
        // identified. With only three fingers plus a thumb, keep observing pinch.
        let verticalAllowed = motion.thumbID == nil ||
            (motion.contactCount == 5 && motion.verticalFingerVotes >= 3)
        let panReady = settings.translationAllowed && motion.parallelVotes >= 3 &&
            motion.panDistance >= settings.translationThreshold && (axis != .vertical || verticalAllowed)

        // Translation supported by only part of the hand is weaker than a whole-
        // hand swipe; use its support fraction when comparing against radial motion.
        let translationStrength = motion.panDistance * Double(motion.parallelVotes) / Double(motion.contactCount)
        isAmbiguous = false
        if pinchReady && (motion.thumbRadialScale.map { abs($0) >= 0.10 } ?? false) {
            selected = .pinch
            return selected
        }
        if settings.translationAllowed && motion.parallelHand && (axis != .vertical || verticalAllowed) {
            // A majority moving in parallel is a swipe, even with staggered
            // speeds, a sticky thumb, or a diagonal direction. Do not let radial
            // artifacts win while the axis/translation threshold is unresolved.
            if !panReady || axis == nil { isAmbiguous = true; return nil }
            if !radial { selected = axis; return selected }
            if ambiguitySince == nil { ambiguitySince = time }
            if time - ambiguitySince! >= 0.035 { selected = axis; return selected }
            isAmbiguous = true
            nextEvaluationTime = ambiguitySince! + 0.035
            return nil
        }
        if pinchReady && !panReady && motion.movingContactCount <= 2 {
            // HID reports X/Y per contact. Wait one short observation interval so
            // the first moving contact cannot masquerade as a whole-hand spread.
            if partialPinchSince == nil { partialPinchSince = time }
            if time - partialPinchSince! < 0.016 {
                isAmbiguous = true
                nextEvaluationTime = partialPinchSince! + 0.016
                return nil
            }
        } else if !pinchReady {
            partialPinchSince = nil
        }
        if pinchReady && (!panReady || motion.pinchSignal > translationStrength * 1.15) {
            selected = .pinch
        } else if panReady, let axis {
            if radial {
                // Give emerging pinch evidence one short observation window before
                // choosing translation. The coordinator may re-evaluate the latest
                // snapshot at the deadline; clear translations need no delay.
                if ambiguitySince == nil { ambiguitySince = time }
                isAmbiguous = true
                if time < ambiguitySince! + 0.06 { nextEvaluationTime = ambiguitySince! + 0.06 }
                if time - ambiguitySince! >= 0.06 && translationStrength > motion.pinchSignal * 1.5 {
                    selected = axis
                }
            } else {
                selected = axis
            }
        } else {
            isAmbiguous = radial || (panReady && axis == nil)
            if !isAmbiguous { ambiguitySince = nil }
        }
        if selected != nil { isAmbiguous = false; nextEvaluationTime = nil }
        return selected
    }
}
