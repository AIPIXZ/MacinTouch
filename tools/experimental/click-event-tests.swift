// Constructs CGEvents and captures gesture actions; never posts input events.
import AppKit
import Foundation

@main
struct ClickEventTests {
    static func main() {
        let point = CGPoint(x: 893.9, y: 248.8)
        let first = InputSimulator.makeClickEvents(at: point, clickState: 1)
        let second = InputSimulator.makeClickEvents(at: point, clickState: 2)
        precondition(first.count == 2 && second.count == 2, "each tap creates exactly one down/up pair")
        precondition((first + second).map { $0.type } == [.leftMouseDown, .leftMouseUp, .leftMouseDown, .leftMouseUp], "two taps produce four events, not six")
        precondition((first + second).map { $0.getIntegerValueField(.mouseEventClickState) } == [1, 1, 2, 2], "click count continues the first click")
        precondition((first + second).allSatisfy { $0.location == point }, "click event target is preserved")
        precondition((first + second).allSatisfy {
            $0.getIntegerValueField(.eventSourceStateID) == Int64(CGEventSourceStateID.hidSystemState.rawValue)
        }, "both clicks share the HID system state source")
        for deferred in [false, true] {
            let context = GestureContext()
            context.config.gestures.tapTimeout = 0.02
            let machine = GestureStateMachine(context: context)
            let gesture = SingleFingerScrollGesture(context: context, stateMachine: machine)
            let touch = Touch(x: 7628, y: 2212)
            var actions: [String] = []
            var clickTargets: [Touch] = []
            context.onAction = { action in
                switch action {
                case .mouseDown: actions.append("down")
                case .mouseUp: actions.append("up")
                case .doubleClick(let point): actions.append("full-double"); clickTargets.append(point)
                case .secondClick(let point): actions.append("second"); clickTargets.append(point)
                default: break
                }
            }
            func tap(_ target: Touch) {
                context.activeTouches[0] = target
                machine.update()
                gesture.touchBegan(fingerId: 0, touch: target, context: context)
                gesture.touchEnded(fingerId: 0, touch: target, context: context)
                context.activeTouches.removeAll()
                machine.update()
            }
            tap(touch)
            if !deferred { RunLoop.current.run(until: Date().addingTimeInterval(0.035)) }
            tap(Touch(x: touch.x + 80, y: touch.y + 40))
            RunLoop.current.run(until: Date().addingTimeInterval(0.035))
            precondition(actions == (deferred ? ["full-double"] : ["down", "up", "second"]),
                         "deferred first tap needs full double; posted first tap needs only second click")
            precondition(clickTargets.count == 1 && clickTargets[0].x == touch.x && clickTargets[0].y == touch.y,
                         "both single-finger scroll double-click paths target the first tap")
            gesture.reset()
        }
        print("PASS: four-event double-click sequence, click states 1/2, deferred and already-posted first tap")
    }
}
