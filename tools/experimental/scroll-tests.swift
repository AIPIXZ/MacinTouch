// Captures actions only; no scroll or mouse events are posted to macOS.
import AppKit
import Foundation

@main
struct ScrollTests {
    final class Fixture {
        let context = GestureContext()
        var now = 100.0
        var events: [(Int32, Int32, CGPoint, Int64, Int64)] = []
        lazy var machine = GestureStateMachine(context: context)
        lazy var scroll = ScrollGesture(context: context, stateMachine: machine, clock: { [unowned self] in self.now })
        init() {
            context.config.scroll.minFingerDistance = 0
            context.config.scroll.maxFingerDistance = 10000
            context.config.scroll.inertialMinVelocity = 1
            context.config.scroll.accelerationEnabled = false
            context.onAction = { [weak self] action in
                if case let .continuousScroll(dx, dy, point, phase, momentum) = action {
                    self?.events.append((dx, dy, point, phase, momentum))
                }
            }
        }
        func begin() { scroll.startScrolling(center: Touch(x: 5000, y: 4000)) }
        func move(_ dy: Int) {
            now += 0.02
            scroll.handleScroll(touch1: Touch(x: 4500, y: 4000 + dy),
                                touch2: Touch(x: 5500, y: 4000 + dy), distance: 100)
        }
        func tick() {
            now += 1.0 / 60
            RunLoop.current.run(until: Date().addingTimeInterval(0.021))
        }
        func close() { scroll.reset() }
    }
    static func main() {
        do {
            let curve = ScrollInertiaCurve(decay: 0.96, frameRate: 60)
            precondition((0.04...0.06).contains(curve.peakTime), "launch peaks within about 50ms")
            let peak = curve.velocityMultiplier(at: curve.peakTime)
            precondition(peak > 1.5 && curve.velocityMultiplier(at: 0.01) > 1, "velocity initially accelerates into a launch pulse")
            precondition(curve.velocityMultiplier(at: 0.15) < peak && curve.velocityMultiplier(at: 1.1) < 0.02,
                         "pulse brakes quickly without a long tail")
            var stopTime = curve.peakTime
            while curve.velocityMultiplier(at: stopTime) * 1000 >= 20 { stopTime += 0.001 }
            precondition((0.85...1.1).contains(stopTime), "representative flick ends in about one second")
            let previousDistance = -1 / (log(0.96) * 60)
            precondition(abs(curve.integral(from: 0, to: 10) - previousDistance) < 0.00001,
                         "concentrating motion in the pulse preserves total travel")
            for rate in [30, 60, 120] {
                let steps = rate * 2
                let distance = (0..<steps).reduce(0.0) {
                    $0 + curve.integral(from: Double($1) / Double(rate), to: Double($1 + 1) / Double(rate))
                }
                precondition(abs(distance - curve.integral(from: 0, to: 2)) < 0.00001,
                             "integrated travel is independent of refresh rate")
            }
        }
        print("PASS: launch acceleration, 50ms peak, rapid braking, preserved distance, refresh-rate invariance")
        do {
            let f = Fixture(); f.context.config.scroll.inertialMinVelocity = 200
            f.begin()
            for step in 1...100 {
                f.now += 0.0002
                f.scroll.handleScroll(touch1: Touch(x: 4500, y: 4000 + step * 8),
                                      touch2: Touch(x: 5500, y: 4000 + step * 8), distance: 100)
            }
            f.scroll.stopScrolling(); f.tick()
            precondition(f.events.contains { $0.4 == 1 }, "dense HID callbacks cannot erase the velocity time baseline")
            f.close()
        }
        do {
            let f = Fixture(); f.context.config.scroll.inertialMinVelocity = 200
            f.begin(); f.now += 0.008
            f.scroll.handleScroll(touch1: Touch(x: 4500, y: 4600), touch2: Touch(x: 5500, y: 4600), distance: 100)
            f.scroll.stopScrolling(); f.tick()
            precondition(f.events.contains { $0.4 == 1 }, "short flick with one scroll update still starts inertia conservatively")
            f.close()
        }
        do {
            let f = Fixture(); f.context.config.scroll.inertialMinVelocity = 200
            let detector = TwoFingerDetector(context: f.context, stateMachine: f.machine, clock: { f.now })
            detector.update(touch1: Touch(x: 4500, y: 4000), touch2: Touch(x: 5500, y: 4000))
            f.now += 0.02
            detector.update(touch1: Touch(x: 4500, y: 4600), touch2: Touch(x: 5500, y: 4600))
            detector.endTwoFingerGesture(); f.tick()
            precondition(f.events.contains { $0.4 == 1 }, "flick velocity includes pre-recognition movement and timing")
            detector.reset()
        }
        print("PASS: high-rate HID velocity window, short single-update flick, detection-period velocity")
        do {
            let baseline = Fixture(), amplified = Fixture()
            baseline.context.config.scroll.inertialDistanceMultiplier = 1
            amplified.context.config.scroll.inertialDistanceMultiplier = 2
            for f in [baseline, amplified] {
                f.context.config.scroll.inertialMinSpeed = 300
                f.begin(); f.move(400); f.move(800); f.scroll.stopScrolling()
            }
            for _ in 0..<90 {
                baseline.tick(); amplified.tick()
                let ended1 = baseline.events.last?.4 == 3
                let ended2 = amplified.events.last?.4 == 3
                precondition(ended1 == ended2, "distance multiplier cannot change momentum end time")
                if ended1 { break }
            }
            precondition(baseline.events.last?.4 == 3 && amplified.events.last?.4 == 3, "both inertia streams finish")
            let firstDistance = baseline.events.filter { $0.4 == 1 || $0.4 == 2 }.reduce(0) { $0 + Int($1.1) }
            let secondDistance = amplified.events.filter { $0.4 == 1 || $0.4 == 2 }.reduce(0) { $0 + Int($1.1) }
            precondition(abs(secondDistance - firstDistance * 2) <= 2, "twice the distance over the same duration, allowing pixel rounding")
            precondition(baseline.events.filter { $0.3 != 0 }.map { $0.1 } == amplified.events.filter { $0.3 != 0 }.map { $0.1 }, "direct drag distance is unaffected")
            baseline.close(); amplified.close()
            let oldData = try! JSONEncoder().encode(ScrollConfig())
            precondition((try! JSONDecoder().decode(ScrollConfig.self, from: oldData)).inertialDistanceMultiplier == nil,
                         "old configurations without distance gain still decode")
        }
        print("PASS: 2x momentum distance with unchanged stopping time and direct drag, old config compatibility")
        do {
            let f = Fixture(); f.context.config.scroll.inertialEnabled = false
            f.begin(); f.move(300); f.move(600); f.scroll.stopScrolling()
            precondition(f.events.map { $0.3 } == [1, 2, 4], "direct scroll emits began/changed/ended")
            precondition(f.events.allSatisfy { $0.4 == 0 && $0.2 == f.events[0].2 }, "direct scroll keeps a fixed target")
            let count = f.events.count
            f.scroll.stopScrolling()
            precondition(f.events.count == count, "repeated stop cannot duplicate end")
            f.close()
        }
        for direct in [true, false] {
            for invert in [true, false] {
                let f = Fixture()
                f.context.config.scroll.directMappingEnabled = direct
                f.context.config.scroll.invertY = invert
                f.begin(); f.move(400); f.move(800); f.move(1200)
                let direction = f.events.last!.1
                f.scroll.stopScrolling(); f.tick(); f.tick()
                let momentum = f.events.filter { $0.4 == 1 || $0.4 == 2 }
                precondition(!momentum.isEmpty && momentum[0].4 == 1, "release starts explicit momentum")
                precondition(momentum.allSatisfy { $0.1 * direction > 0 && $0.2 == f.events[0].2 }, "momentum direction and target match direct scrolling in both mapping modes")
                f.scroll.stopInertialScrolling()
                precondition(f.events.last!.4 == 3, "interruption emits momentum end")
                let count = f.events.count; f.tick()
                precondition(f.events.count == count, "no events after momentum cancellation")
                f.close()
            }
        }
        do {
            let f = Fixture(); f.begin(); f.move(400); f.move(800)
            f.now += 0.3 // Hand paused before lifting.
            f.scroll.stopScrolling(); f.tick()
            precondition(f.events.allSatisfy { $0.4 == 0 }, "paused release does not reuse stale velocity")
            f.close()
        }
        do {
            let f = Fixture(); f.begin(); f.move(400); f.move(800)
            f.scroll.stopScrolling(allowInertia: false); f.tick()
            precondition(f.events.allSatisfy { $0.4 == 0 }, "gesture switch never starts inertia")
            precondition(!f.context.isInEventFilterPeriod, "gesture switch cannot filter incoming fingers")
            f.close()
        }
        do {
            let f = Fixture(); f.begin(); f.move(400); f.scroll.reset()
            precondition(f.events.last!.3 == 8, "reset cancels direct scroll phase")
            let count = f.events.count; f.tick()
            precondition(f.events.count == count, "reset has no trailing scroll")
        }
        do {
            let f = Fixture(); f.context.config.scroll.inertialEnabled = false
            let detector = TwoFingerDetector(context: f.context, stateMachine: f.machine, clock: { f.now })
            for frame in 0..<100 {
                let offset = frame % 2 == 0 ? 0 : 2
                detector.update(touch1: Touch(x: 4500, y: 4000 + offset), touch2: Touch(x: 5500, y: 4000 + offset))
            }
            precondition(detector.state == .detecting && f.events.isEmpty, "stationary jitter and callback count cannot start scrolling")
            detector.update(touch1: Touch(x: 4500, y: 4600), touch2: Touch(x: 5500, y: 4600))
            precondition(detector.state == .scrolling && f.events.first?.3 == 1, "translation starts scroll without dropping detection displacement")
            detector.endTwoFingerGesture(allowInertia: false)
            precondition(f.events.last?.3 == 4 && !f.context.isInEventFilterPeriod, "switch ends scroll without filtering other gestures")
            detector.reset()
        }
        do {
            let f = Fixture()
            let detector = TwoFingerDetector(context: f.context, stateMachine: f.machine, clock: { f.now })
            detector.update(touch1: Touch(x: 4500, y: 4000), touch2: Touch(x: 5500, y: 4000))
            detector.update(touch1: Touch(x: 4200, y: 4000), touch2: Touch(x: 5800, y: 4000))
            precondition(detector.state == .pinching && f.events.isEmpty, "radial two-finger motion remains pinch rather than scroll")
            detector.endTwoFingerGesture()
            precondition(f.context.isInEventFilterPeriod, "pinch release filters late single-contact DOWN callbacks")
            detector.reset()
        }
        do {
            let f = Fixture()
            let detector = TwoFingerDetector(context: f.context, stateMachine: f.machine, clock: { f.now })
            detector.update(touch1: Touch(x: 4500, y: 4000), touch2: Touch(x: 5500, y: 4000))
            detector.update(touch1: Touch(x: 4200, y: 4000), touch2: Touch(x: 5800, y: 4000))
            for id in 0..<3 { f.context.activeTouches[id] = Touch(x: 4000 + id * 1000, y: 4000) }
            detector.endTwoFingerGesture(allowInertia: false)
            precondition(!f.context.isInEventFilterPeriod, "pinch-to-multi-finger transition does not filter incoming fingers")
            detector.reset()
        }
        print("PASS: scroll phases, fixed targeting, momentum directions, stale velocity, interruption, gesture switch, reset")
    }
}
