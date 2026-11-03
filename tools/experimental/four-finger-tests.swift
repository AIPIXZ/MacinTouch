// Runs the real recognizer with captured actions; never posts system events.
import AppKit
import Foundation

@main
struct FourFingerTests {
    final class Fixture {
        let context = GestureContext()
        let gesture: FourFingerGesture
        var frames: [(Int32, Double)] = []
        var shortcuts: [InputType] = []
        var pointerActions = 0
        var radialFrames: [(Int32, Int32, Double)] = []
        var points = [(4000, 3000), (6000, 3000), (4000, 5000), (6000, 5000)]
        init(native: Bool = true) {
            context.config.fourFinger.nativeHorizontalSwipe = native
            // Existing geometry tests use explicit legacy vertical output and the
            // original spread range; separate cases below verify the new defaults.
            context.config.fourFinger.nativeVerticalSwipe = false
            context.config.fourFinger.dockSpreadTravelRatio = 0.60
            context.config.fourFinger.minDistance = 0
            context.config.fourFinger.maxDistance = 10000
            gesture = FourFingerGesture(context: context, stateMachine: GestureStateMachine(context: context))
            context.onAction = { [weak self] action in
                switch action {
                case .dockSwipe(let phase, let progress): self?.frames.append((phase, progress))
                case .dockGesture(let motion, let phase, let progress): self?.radialFrames.append((motion, phase, progress))
                case .fourFingerGesture(let type, _): self?.shortcuts.append(type)
                case .mouseMove, .mouseDrag, .mouseDown, .mouseUp: self?.pointerActions += 1
                default: break
                }
            }
        }
        func set(_ dx: Int = 0, dy: Int = 0) {
            for (i, p) in points.enumerated() {
                context.activeTouches[i] = Touch(x: p.0 + dx, y: p.1 + dy)
            }
        }
        func move(_ dx: Int, dy: Int = 0) {
            set(dx, dy: dy)
            gesture.check()
        }
        func scale(_ factor: Double, translateX: Int = 0, translateY: Int = 0) {
            for (i, p) in points.enumerated() {
                context.activeTouches[i] = Touch(x: 5000 + Int(Double(p.0 - 5000) * factor) + translateX,
                                                y: 4000 + Int(Double(p.1 - 4000) * factor) + translateY)
            }
            gesture.check()
        }
        func lift() { context.activeTouches.removeValue(forKey: 0); gesture.check() }
        func releaseAll() { context.activeTouches.removeAll(); gesture.check() }
        func close() {
            gesture.reset(); releaseAll()
            FourFingerTests.require(pointerActions == 0, "multi-finger start/update/end/reset must not emit pointer events")
        }
    }
    static func require(_ pass: Bool, _ message: String) {
        precondition(pass, message)
    }
    static func testUnifiedArbitration() {
        let starts: [Int: CGPoint] = [0: CGPoint(x: -100, y: -100), 1: CGPoint(x: 100, y: -100),
                                     2: CGPoint(x: -100, y: 100), 3: CGPoint(x: 100, y: 100)]
        func sample(scale: Double = 1, x: Double = 0, y: Double = 0) -> MultiFingerEvidence {
            let current = starts.mapValues { CGPoint(x: $0.x * scale + x, y: $0.y * scale + y) }
            return MultiFingerEvidence(initial: starts, current: current)!
        }
        let settings = MultiFingerArbiter.Settings()
        for mirror in [-1.0, 1.0] {
            let hand: [Int: CGPoint] = [0: CGPoint(x: -60, y: 0), 1: CGPoint(x: -20, y: -15),
                                       2: CGPoint(x: 20, y: -10), 3: CGPoint(x: 60, y: 0),
                                       4: CGPoint(x: -100 * mirror, y: 160)]
            for direction in [-1.0, 1.0] {
                var current = hand
                // Four fingers move nearly parallel while the thumb opposes them.
                // This common hand shape must remain a pinch/spread, not a swipe.
                for id in 0..<4 { current[id]!.y += direction * 40 }
                current[4]!.y -= direction * 30
                let evidence = MultiFingerEvidence(initial: hand, current: current)!
                require(evidence.thumbID == 4, "initial isolated thumb is identified independently of contact order")
                var arbiter = MultiFingerArbiter()
                require(arbiter.update(evidence, time: 0, settings: settings) == .pinch, "opposing thumb wins over parallel four-finger motion")
                require(evidence.scale * direction < 0, "thumb/finger closing and opening signs")
                current = hand
                for id in 0..<4 { current[id]!.y += direction * 50 }
                arbiter.reset()
                let swipe = MultiFingerEvidence(initial: hand, current: current)!
                _ = arbiter.update(swipe, time: 0, settings: settings)
                require(arbiter.update(swipe, time: 0.07, settings: settings) == .vertical, "four non-thumb fingers swipe with stationary thumb")
                var four = hand; four.removeValue(forKey: 3)
                var threeMoving = four
                for id in 0..<3 { threeMoving[id]!.y += direction * 50 }
                arbiter.reset()
                let incomplete = MultiFingerEvidence(initial: four, current: threeMoving)!
                _ = arbiter.update(incomplete, time: 0, settings: settings)
                require(arbiter.update(incomplete, time: 0.07, settings: settings) != .vertical, "three fingers plus thumb cannot trigger four-finger vertical swipe")
            }
            for opening in [true, false] {
                var current = hand
                // Internal finger spacing changes opposite to thumb opening:
                // six internal pairs must not outvote the four thumb pairs.
                let factor = opening ? 0.75 : 1.25
                for id in 0..<4 { current[id]!.x *= factor; current[id]!.y *= factor }
                current[4]!.y += opening ? 65 : -65
                let motion = MultiFingerEvidence(initial: hand, current: current)!
                require(opening ? motion.scale > 0.1 : motion.scale < -0.1, "thumb gap determines opening/closing despite opposing internal pair majority")
                var arbiter = MultiFingerArbiter()
                _ = arbiter.update(motion, time: 0, settings: settings)
                require(arbiter.update(motion, time: 0.02, settings: settings) == .pinch, "asynchronous thumb-led opening/closing remains recognized")
                // Crossing the opposing-motion gate must not switch scale sign.
                for id in 0..<4 { current[id]!.y += opening ? -15 : 15 }
                let next = MultiFingerEvidence(initial: hand, current: current)!
                require(next.scale * motion.scale > 0, "thumb-led direction stays consistent when the other fingers join")
            }
        }
        for axis in [MultiFingerKind.horizontal, .vertical] {
            var arbiter = MultiFingerArbiter()
            let movement = axis == .horizontal ? sample(x: 40) : sample(y: 40)
            require(arbiter.update(movement, time: 0, settings: settings) == axis, "both swipe axes share activation rule")
            require(arbiter.update(sample(scale: 0.4), time: 0.1, settings: settings) == axis, "confirmed swipe cannot become pinch")
        }
        do {
            var arbiter = MultiFingerArbiter()
            require(arbiter.update(sample(x: 40, y: 40), time: 0, settings: settings) == nil && arbiter.isAmbiguous, "diagonal waits for axis evidence")
            require(!arbiter.selectLongPress(), "ambiguous movement cannot become long press")
            require(arbiter.update(sample(x: 40, y: 90), time: 0.02, settings: settings) == .vertical, "diagonal resolves to dominant axis")
        }
        do {
            var arbiter = MultiFingerArbiter()
            let mixed = sample(scale: 0.95, y: 40)
            require(arbiter.update(mixed, time: 0, settings: settings) == nil, "emerging radial motion waits")
            require(arbiter.update(mixed, time: 0.03, settings: settings) == nil, "ambiguity window uses elapsed time")
            require(arbiter.update(mixed, time: 0.07, settings: settings) == .vertical, "sustained translation resolves minor radial deformation")
        }
        do {
            var arbiter = MultiFingerArbiter()
            _ = arbiter.update(sample(scale: 0.95, y: 40), time: 0, settings: settings)
            require(arbiter.update(sample(scale: 0.6, y: 40), time: 0.02, settings: settings) == .pinch, "growing pinch wins before shortcut")
            require(arbiter.update(sample(y: 150), time: 0.2, settings: settings) == .pinch, "pinch remains locked during later translation")
            arbiter.reset()
            require(arbiter.selected == nil && !arbiter.isAmbiguous, "release/reset clears arbitration state")
            require(arbiter.selectLongPress(), "stationary hand can select long press")
            require(arbiter.update(sample(y: 150), time: 0.3, settings: settings) == .longPress, "long press shares selection ownership")
        }
        do {
            var arbiter = MultiFingerArbiter()
            var disabled = settings; disabled.pinchEnabled = false
            require(arbiter.update(sample(scale: 0.5), time: 0, settings: disabled) == nil, "disabled pinch is not a candidate")
            require(arbiter.update(sample(y: 40), time: 0.01, settings: disabled) == .vertical, "translation still works with pinch disabled")
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.move(0, dy: -2000)
            f.move(0, dy: -2500); f.scale(0.4)
            require(f.shortcuts.count == 1 && f.radialFrames.isEmpty, "vertical shortcut dispatches once and cannot turn into pinch")
            f.close()
        }
        for count in [4, 5] {
            let ids = Array(0..<count)
            let initial = Dictionary(uniqueKeysWithValues: ids.map { id in
                (id, id < 4 ? starts[id]! : CGPoint(x: 0, y: -180))
            })
            for direction in [-1.0, 1.0] {
                var current = initial
                var arbiter = MultiFingerArbiter()
                // Model per-contact reports: thumb stays still, the other contacts
                // swipe together. Early partial reports must not select a spread.
                for (step, id) in ids.dropLast().enumerated() {
                    current[id]!.y += direction * 80
                    let motion = MultiFingerEvidence(initial: initial, current: current)!
                    _ = arbiter.update(motion, time: Double(step) * 0.002, settings: settings)
                    require(arbiter.selected != .pinch, "sticky thumb must not turn upward/downward swipe into spread")
                }
                _ = arbiter.update(MultiFingerEvidence(initial: initial, current: current)!, time: 0.05, settings: settings)
                require(arbiter.selected == .vertical, "co-moving group selects vertical swipe despite lagging thumb")
            }
        }
        do {
            var arbiter = MultiFingerArbiter()
            var current = starts; current[2] = CGPoint(x: -20, y: -20)
            let motion = MultiFingerEvidence(initial: starts, current: current)!
            require(arbiter.update(motion, time: 0, settings: settings) == nil, "single moving contact needs confirmation")
            require(arbiter.update(motion, time: 0.02, settings: settings) == .pinch, "intentional thumb pinch remains supported")
        }
        for direction in [-1, 1] {
            let f = Fixture(); f.context.config.fourFinger.nativeVerticalSwipe = nil
            f.set(); f.gesture.check(); f.move(0, dy: direction * 2000)
            f.move(0, dy: direction * 3000); f.lift()
            require(f.shortcuts.isEmpty && f.radialFrames.first?.0 == 2 && f.radialFrames.last?.1 == 4, "default vertical gestures use continuous native output")
            require(f.radialFrames.last!.2 * Double(-direction) > 0, "up/down native progress directions")
            f.close()
        }
        do {
            let f = Fixture(); f.context.config.fourFinger.dockSpreadTravelRatio = nil
            f.set(); f.gesture.check(); f.scale(1.4)
            require(abs(f.radialFrames.last!.2 - 0.4) < 0.002, "spread gets a longer travel without early saturation")
            f.close()
        }
        do {
            var initial = starts; initial[4] = CGPoint(x: 0, y: 180)
            var current = initial
            var arbiter = MultiFingerArbiter()
            for id in [0, 1, 2] { current[id]!.y -= 40 }
            let partial = MultiFingerEvidence(initial: initial, current: current)!
            require(arbiter.update(partial, time: 0, settings: settings) == nil, "co-moving partial hand below swipe threshold cannot become pinch")
            current[3]!.y -= 40
            _ = arbiter.update(MultiFingerEvidence(initial: initial, current: current)!, time: 0.002, settings: settings)
            require(arbiter.update(MultiFingerEvidence(initial: initial, current: current)!, time: 0.05, settings: settings) == .vertical, "remaining contact completes upward swipe")
        }
        for count in [4, 5] {
            var initial = starts
            if count == 5 { initial[4] = CGPoint(x: 0, y: 180) }
            for angle in [20.0, 35.0, 60.0, 75.0] {
                for sign in [-1.0, 1.0] {
                    var current = initial
                    for id in 0..<count {
                        let travel = id == count - 1 ? 0 : Double(45 + id * 25)
                        current[id]!.x += cos(angle * .pi / 180) * travel * sign
                        current[id]!.y += sin(angle * .pi / 180) * travel * sign
                    }
                    let motion = MultiFingerEvidence(initial: initial, current: current)!
                    var arbiter = MultiFingerArbiter()
                    _ = arbiter.update(motion, time: 0, settings: settings)
                    require(arbiter.selected != .pinch, "angled unequal-speed swipe cannot become spread")
                    let expected: MultiFingerKind = angle < 45 ? .horizontal : .vertical
                    require(arbiter.update(motion, time: 0.05, settings: settings) == expected, "angled swipe resolves despite sticky contact")
                }
            }
        }
        do {
            let offsets = [CGPoint(x: -20, y: -18), CGPoint(x: 22, y: -12),
                           CGPoint(x: -14, y: 20), CGPoint(x: -45, y: -45)]
            var current = starts
            for id in 0..<4 { current[id]!.x += offsets[id].x; current[id]!.y += offsets[id].y }
            var arbiter = MultiFingerArbiter()
            require(arbiter.update(MultiFingerEvidence(initial: starts, current: current)!, time: 0, settings: settings) == .pinch, "three outward contacts tolerate one opposing contact")
        }
        do {
            let initial = starts.mapValues { CGPoint(x: $0.x * 0.3, y: $0.y * 0.3) }
            let current = initial.mapValues { CGPoint(x: $0.x * 1.11, y: $0.y * 1.11) }
            var arbiter = MultiFingerArbiter()
            let compact = MultiFingerEvidence(initial: initial, current: current)!
            _ = arbiter.update(compact, time: 0, settings: settings)
            require(arbiter.update(compact, time: 0.02, settings: settings) == .pinch, "compact hand spread uses adaptive pixel threshold")
            arbiter.reset()
            require(arbiter.update(sample(scale: 1.015, x: 2, y: 1), time: 0, settings: settings) == nil, "small contact jitter does not select gesture")
        }
        print("PASS: angled unequal-speed swipes, opposing-contact spread tolerance, compact-hand spread, jitter rejection")
        print("PASS: sticky-thumb swipe arbitration, partial-report confirmation, native up/down defaults, longer spread travel")
        print("PASS: shared axis rules, diagonal ambiguity, timed evidence resolution, pinch/swipe/long-press ownership, one-shot vertical output")
    }

    static func main() throws {
        require(ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27, "macOS 27 required")
        for count in [4, 5] {
            let f = Fixture()
            if count == 5 { f.points.append((5000, 6500)) }
            f.set(); f.gesture.check()
            f.scale(1.06)
            f.context.activeTouches.removeValue(forKey: 0); f.gesture.check()
            RunLoop.current.run(until: Date().addingTimeInterval(0.025))
            require(f.radialFrames.isEmpty, "missing candidate contact cannot emit gesture")
            f.scale(1.4)
            require(f.radialFrames.first?.0 == 3 && f.radialFrames.first!.2 > 0, "same-ID candidate recovery preserves spread displacement")
            f.lift()
            require(f.radialFrames.last?.1 == 4, "selected native gesture still ends immediately on first lift")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.lift()
            RunLoop.current.run(until: Date().addingTimeInterval(0.145))
            f.scale(1.4)
            require(f.radialFrames.isEmpty, "expired candidate gap cannot resume before all contacts lift")
            f.releaseAll(); f.set(); f.gesture.check(); f.scale(1.4)
            require(!f.radialFrames.isEmpty, "new contact sequence works after gap timeout")
            f.close()
        }
        do {
            let f = Fixture(); f.points.append((5000, 6500)); f.set(); f.gesture.check(); f.lift()
            f.context.activeTouches[9] = Touch(x: 4000, y: 3000); f.gesture.check()
            f.scale(1.4)
            require(f.radialFrames.isEmpty, "replacement ID must not recover interrupted five-contact candidate")
            f.close()
        }
        print("PASS: candidate-only same-ID gap recovery, bounded timeout, replacement rejection, native lift unchanged")
        for missingIDs in [[1, 4], [4, 3]] {
            let f = Fixture(); f.points.append((5000, 6500))
            f.set(); f.gesture.check()
            for id in missingIDs {
                f.context.activeTouches.removeValue(forKey: id); f.gesture.check()
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.025))
            let first = missingIDs[0], point = f.points[first]
            f.context.activeTouches[first] = Touch(x: point.0, y: point.1); f.gesture.check()
            require(f.radialFrames.isEmpty, "5-to-3-to-4 candidate must not output with one contact still missing")
            f.scale(1.4)
            require(f.radialFrames.first?.0 == 3 && f.radialFrames.first!.2 > 0, "5-to-3-to-4-to-5 replay preserves spread recognition")
            f.close()
        }
        do {
            let f = Fixture(); f.points.append((5000, 6500)); f.set(); f.gesture.check()
            f.context.activeTouches.removeValue(forKey: 4); f.gesture.check()
            RunLoop.current.run(until: Date().addingTimeInterval(0.035))
            f.context.activeTouches.removeValue(forKey: 3); f.gesture.check()
            RunLoop.current.run(until: Date().addingTimeInterval(0.100))
            f.scale(1.4)
            require(f.radialFrames.isEmpty, "second missing contact must not extend original gap deadline")
            f.close()
        }
        print("PASS: sequential two-contact interruption recovery and non-extending deadline")
        for count in [4, 5] {
            for remaining in [1, 2] {
                let f = Fixture()
                if count == 5 { f.points.append((5000, 6500)) }
                f.set(); f.gesture.check()
                for id in remaining..<count {
                    f.context.activeTouches.removeValue(forKey: id); f.gesture.check()
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.025))
                require(f.radialFrames.isEmpty && f.frames.isEmpty && f.shortcuts.isEmpty,
                        "one/two remaining contacts only wait and cannot classify")
                f.scale(1.4)
                require(f.radialFrames.first?.0 == 3 && f.radialFrames.first!.2 > 0,
                        "candidate survives transient one/two-contact report until original contacts recover")
                f.lift()
                require(f.radialFrames.last?.1 == 4, "debounce does not delay selected native gesture completion")
                f.close()
            }
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check()
            f.context.activeTouches.removeValue(forKey: 3); f.gesture.check()
            RunLoop.current.run(until: Date().addingTimeInterval(0.035))
            for id in [1, 2] { f.context.activeTouches.removeValue(forKey: id); f.gesture.check() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.100))
            f.scale(1.4)
            require(f.radialFrames.isEmpty, "deep contact dip does not extend first gap deadline")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check()
            for id in [1, 2, 3] { f.context.activeTouches.removeValue(forKey: id); f.gesture.check() }
            f.releaseAll()
            f.set(); f.gesture.check(); f.scale(0.6)
            require(f.radialFrames.first?.0 == 3 && f.radialFrames.first!.2 < 0,
                    "full release ends debounce and next gesture gets a fresh baseline")
            f.close()
        }
        print("PASS: candidate end debounce for one/two-contact dips, bounded deadline, full release, native completion unchanged")
        do {
            let f = Fixture(); f.set(); f.gesture.check()
            // Reproduce seq=8: 4 -> 3 -> 2 -> 3 -> (late fifth) 4 -> 5.
            f.context.activeTouches.removeValue(forKey: 2); f.gesture.check()
            f.context.activeTouches.removeValue(forKey: 3); f.gesture.check()
            f.context.activeTouches[2] = Touch(x: 4000, y: 5000); f.gesture.check()
            f.points.append((5000, 6500))
            f.context.activeTouches[4] = Touch(x: 5000, y: 6500); f.gesture.check()
            f.context.activeTouches[3] = Touch(x: 6000, y: 5000); f.gesture.check()
            f.scale(1.4)
            require(f.radialFrames.first?.0 == 3 && f.radialFrames.first!.2 > 0,
                    "late fifth before original fourth returns does not end debounced candidate")
            f.close()
        }
        for factor in [0.65, 1.4] {
            let f = Fixture(); f.points.append((5000, 6500)); f.set(); f.gesture.check()
            for id in [3, 4] { f.context.activeTouches.removeValue(forKey: id); f.gesture.check() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.020))
            for id in 0..<3 {
                let p = f.points[id]
                f.context.activeTouches[id] = Touch(x: 5000 + Int(Double(p.0 - 5000) * factor),
                                                   y: 4000 + Int(Double(p.1 - 4000) * factor))
            }
            f.gesture.check()
            require(f.radialFrames.first?.0 == 3, "three observed original contacts can recognize radial motion during candidate gap")
            require(f.radialFrames.first!.2 * (factor - 1) > 0, "partial pinch/spread retains signed original displacement")
            f.context.activeTouches[4] = Touch(x: 5000, y: 6500); f.gesture.check()
            require(f.radialFrames.last?.1 != 4, "late absent contact does not interrupt locked partial pinch")
            f.context.activeTouches.removeValue(forKey: 4); f.gesture.check()
            require(f.radialFrames.last?.1 != 4, "nonparticipating late contact lift cannot end partial pinch")
            f.lift()
            require(f.radialFrames.last?.1 == 4, "partial pinch still ends on first participating lift")
            f.close()
        }
        do {
            let f = Fixture(); f.points.append((5000, 6500)); f.set(); f.gesture.check()
            for id in [3, 4] { f.context.activeTouches.removeValue(forKey: id); f.gesture.check() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.020))
            for id in 0..<3 { f.context.activeTouches[id]!.y -= 2000 }
            f.gesture.check()
            require(f.radialFrames.isEmpty && f.frames.isEmpty && f.shortcuts.isEmpty, "partial hand cannot select translation")
            f.close()
        }
        print("PASS: observed partial-hand pinch/spread, no synthetic points or partial swipes, locked-subset lift")
        do {
            let f = Fixture()
            f.points.append((3000, 8000)); f.set(); f.gesture.check()
            for id in [2, 3] { f.context.activeTouches.removeValue(forKey: id); f.gesture.check() }
            RunLoop.current.run(until: Date().addingTimeInterval(0.020))
            // Two ordinary fingers move toward a stationary, identifiable thumb.
            for id in [0, 1] { f.context.activeTouches[id]!.y += 1600 }
            f.gesture.check()
            RunLoop.current.run(until: Date().addingTimeInterval(0.020))
            require(f.radialFrames.first?.0 == 3 && f.radialFrames.first!.2 < 0, "stationary thumb plus two observed fingers can identify closing hand")
            f.close()
        }
        testUnifiedArbitration()
        // Existing config files must still decode with both new keys absent.
        let data = try JSONEncoder().encode(DriverConfig())
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        var four = json["fourFinger"] as! [String: Any]
        four.removeValue(forKey: "nativeHorizontalSwipe")
        four.removeValue(forKey: "dockSwipeTravelFraction")
        four.removeValue(forKey: "nativePinchGesture")
        four.removeValue(forKey: "dockPinchTravelRatio")
        four.removeValue(forKey: "dockSpreadTravelRatio")
        four.removeValue(forKey: "nativeVerticalSwipe")
        json["fourFinger"] = four
        let decoded = try JSONDecoder().decode(DriverConfig.self, from: JSONSerialization.data(withJSONObject: json))
        require(decoded.fourFinger.nativeHorizontalSwipe == nil, "old config compatibility")
        for sign in [-1, 1] {
            let f = Fixture()
            f.set(); f.gesture.check()
            // Slow drags must enter the native path regardless of swipeMinVelocity.
            f.context.config.fourFinger.swipeMinVelocity = 1e9
            f.move(sign * 1500)
            f.move(sign * 5000)
            f.lift()
            require(f.frames.first?.0 == 1 && f.frames.last?.0 == 4, "begin/end pairing")
            require(f.frames.last!.1 == Double(sign), "cumulative progress and saturation")
            require(f.shortcuts.isEmpty, "native swipe must not emit arrow shortcut")
            let count = f.frames.count
            f.set(); f.gesture.check() // bouncing contact must not restart
            f.move(sign * 1000)
            require(f.frames.count == count, "wait for all contacts to lift")
            f.releaseAll(); f.set(); f.gesture.check(); f.move(sign * 1500)
            require(f.frames.filter { $0.0 == 1 }.count == 2, "next swipe after full release")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.move(2000)
            f.move(100); f.lift()
            require(abs(f.frames.last!.1) < 0.05, "return-to-origin must not retain peak progress")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.move(2000)
            f.gesture.reset()
            require(f.frames.last?.0 == 8, "shutdown/config change cancels")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.move(2000)
            f.context.activeTouches[4] = Touch(x: 5000, y: 4000); f.gesture.check()
            require(f.frames.last?.0 == 2, "late fifth finger must not cancel locked swipe")
            f.context.activeTouches[5] = Touch(x: 5500, y: 4000); f.gesture.check()
            require(f.frames.last?.0 == 8, "sixth finger cancels")
            f.close()
        }
        do {
            let f = Fixture(native: false); f.set(); f.gesture.check(); f.move(2000)
            require(f.frames.isEmpty && f.shortcuts.count == 1, "explicit keyboard fallback")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.move(0, dy: 2000)
            require(f.frames.isEmpty && f.shortcuts.count == 1, "vertical shortcut unchanged")
            f.close()
        }
        for scale in [0.4, 1.6] {
            let f = Fixture(); f.set(); f.gesture.check(); f.scale(scale); f.lift()
            require(f.frames.isEmpty && f.shortcuts.isEmpty, "pinch must not switch spaces or trigger keys")
            require(f.radialFrames.first?.0 == 3 && f.radialFrames.first?.1 == 1, "pinch begins on axis 3")
            require(f.radialFrames.last?.1 == 4, "pinch ends on lift")
            require(abs(f.radialFrames.last!.2 - (scale < 1 ? -1 : 1)) < 0.002, "pinch direction and cumulative distance")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.scale(1.4); f.scale(1)
            f.gesture.reset()
            require(f.radialFrames.last!.1 == 8 && abs(f.radialFrames.last!.2) < 0.001, "pinch reversal and cancellation")
            f.close()
        }
        do {
            let f = Fixture(); f.context.config.fourFinger.nativePinchGesture = false
            f.set(); f.gesture.check(); f.scale(1.6)
            require(f.radialFrames.isEmpty, "pinch disable switch")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.scale(1.6, translateX: 400)
            require(f.radialFrames.first?.0 == 3 && f.frames.isEmpty, "pinch with centroid drift")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.move(2000); f.scale(0.4)
            require(f.radialFrames.isEmpty, "locked horizontal axis must not become a pinch")
            f.close()
        }
        do {
            let f = Fixture(); f.context.config.fourFinger.nativeVerticalSwipe = true
            f.set(); f.gesture.check(); f.move(0, dy: -3000); f.lift()
            require(f.radialFrames.first?.0 == 2 && f.radialFrames.last?.1 == 4 && f.shortcuts.isEmpty, "opt-in vertical path")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check()
            // Thumb moves inward against three stationary contacts.
            f.context.activeTouches[2] = Touch(x: 4800, y: 4200); f.gesture.check()
            require(f.radialFrames.isEmpty, "partial-hand pinch waits for one observation interval")
            RunLoop.current.run(until: Date().addingTimeInterval(0.025))
            require(f.radialFrames.first?.0 == 3, "candidate deadline confirms thumb pinch without another HID report")
            f.lift()
            require(f.frames.isEmpty && f.radialFrames.last?.0 == 3 && f.radialFrames.last!.2 < 0, "thumb against three fingers")
            f.close()
        }
        for finalScale in [0.4, 1.6] {
            let f = Fixture(); f.set(); f.gesture.check()
            // Replay individual HID X/Y elements rather than atomically moving four contacts.
            for step in 1...30 {
                let factor = 1 + (finalScale - 1) * Double(step) / 30
                for (i, p) in f.points.enumerated() {
                    var t = f.context.activeTouches[i]!
                    t.x = 5000 + Int(Double(p.0 - 5000) * factor)
                    f.context.activeTouches[i] = t; f.gesture.check()
                    t.y = 4000 + Int(Double(p.1 - 4000) * factor)
                    f.context.activeTouches[i] = t; f.gesture.check()
                }
            }
            f.lift()
            require(f.frames.isEmpty && f.radialFrames.last?.0 == 3, "sequential HID pinch classification")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check()
            for step in 1...30 {
                for (i, p) in f.points.enumerated() {
                    f.context.activeTouches[i] = Touch(x: p.0 + step * 80, y: p.1)
                    f.gesture.check()
                }
            }
            f.lift()
            require(f.radialFrames.isEmpty && f.frames.last?.0 == 4, "sequential translation must not look like a pinch")
            f.close()
        }
        for scale in [0.4, 1.6] {
            let f = Fixture()
            f.points.append((5000, 6500))
            f.set(); f.gesture.check(); f.scale(scale); f.lift()
            require(f.radialFrames.first?.0 == 3 && f.radialFrames.last?.1 == 4, "five-finger pinch lifecycle")
            require(f.radialFrames.last!.2 * (scale < 1 ? -1 : 1) > 0.9, "five-finger pinch direction")
            require(f.frames.isEmpty && f.shortcuts.isEmpty, "five-finger pinch must not switch spaces")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check()
            f.points.append((5000, 6500)); f.set(); f.gesture.check()
            require(f.radialFrames.isEmpty && f.frames.isEmpty, "fifth arrival must not look like movement")
            f.scale(0.4); f.lift()
            require(f.radialFrames.last?.1 == 4 && f.radialFrames.last!.2 < -0.9, "late fifth joins uncommitted pinch")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.scale(1.4)
            let previous = f.radialFrames.last!.2
            f.context.activeTouches[4] = Touch(x: 10000, y: 8000); f.gesture.check()
            require(f.radialFrames.last!.1 != 8 && abs(f.radialFrames.last!.2 - previous) < 0.001, "late fifth cannot jump locked pinch")
            f.context.activeTouches.removeValue(forKey: 4); f.gesture.check()
            require(f.radialFrames.last!.1 != 4, "ignored fifth lift cannot end participating pinch")
            f.lift(); require(f.radialFrames.last!.1 == 4, "participating lift ends pinch")
            f.close()
        }
        do {
            let f = Fixture(); f.set(); f.gesture.check(); f.scale(0.92)
            require(f.radialFrames.isEmpty, "small pinch remains a candidate")
            f.context.activeTouches[4] = Touch(x: 5000, y: 6500); f.gesture.check()
            // Continue the original fingers to 12%; the newcomer remains stationary.
            for (i, p) in f.points.enumerated() {
                f.context.activeTouches[i] = Touch(x: 5000 + Int(Double(p.0 - 5000) * 0.88),
                                                  y: 4000 + Int(Double(p.1 - 4000) * 0.88))
            }
            f.gesture.check()
            require(f.radialFrames.first?.0 == 3, "late fifth must preserve pre-arrival pinch displacement")
            f.close()
        }
        for count in [4, 5] {
            let f = Fixture()
            if count == 5 { f.points.append((5000, 6500)) }
            f.set(); f.gesture.check(); f.scale(0.89)
            require(f.radialFrames.first?.0 == 3, "same small scale change triggers four/five equally")
            f.close()
        }
        for nativeVertical in [false, true] {
            let f = Fixture(); f.points.append((5000, 6500))
            f.context.config.fourFinger.nativeVerticalSwipe = nativeVertical
            f.set(); f.gesture.check()
            f.scale(0.91, translateY: -800)
            require(f.shortcuts.isEmpty && f.radialFrames.isEmpty, "radial candidate must not be stolen by upward swipe")
            f.scale(0.6, translateY: -800)
            let starts = Dictionary(uniqueKeysWithValues: f.points.enumerated().map { ($0.offset, DisplayManager.shared.convertHardwareToAppKitScreen(hardwareX: $0.element.0, hardwareY: $0.element.1)) })
            let current = f.context.activeTouches.mapValues { DisplayManager.shared.convertHardwareToAppKitScreen(hardwareX: $0.x, hardwareY: $0.y) }
            let evidence = MultiFingerEvidence(initial: starts, current: current)!
            require(f.radialFrames.first?.0 == 3 && f.shortcuts.isEmpty, "pinch with upward drift stays a pinch: radial=\(evidence.pinchSignal) translation=\(evidence.distance) scale=\(evidence.scale) votes=\(evidence.translationVotes)")
            f.close()
        }
        do {
            let f = Fixture(); f.points.append((5000, 6500))
            f.set(); f.gesture.check(); f.move(0, dy: -2000)
            require(f.radialFrames.isEmpty && f.shortcuts.count == 1, "five-finger upward translation remains available")
            f.close()
        }
        print("PASS: equal four/five sensitivity, preserved late-contact displacement, pinch/upward arbitration, five-finger upward swipe")
        print("PASS: five-finger pinch-in/out, late fifth arrival before/after axis lock, sixth cancellation")
        print("PASS: sequential HID translation and pinch-in/out")
        print("PASS: pinch-in/out, pinch reversal/cancel, centroid drift, axis lock, optional vertical")
        print("PASS: config compatibility, both directions, saturation, slow drag, release ordering, bounce, reversal, reset, fifth finger, fallback, vertical")
    }
}
