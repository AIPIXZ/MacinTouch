// Captures recognizer actions only; never posts mouse events.
import AppKit
import Foundation

@main
struct SingleTouchTests {
    static func main() {
        let context = GestureContext()
        let machine = GestureStateMachine(context: context)
        let gesture = SingleTouchGesture(context: context, stateMachine: machine)
        var actions: [(String, Touch)] = []
        context.onAction = { action in
            switch action {
            case .mouseMove(let point): actions.append(("move", point))
            case .mouseDown(let point): actions.append(("down", point))
            case .mouseUp(let point): actions.append(("up", point))
            case .doubleClick(let point): actions.append(("double", point))
            case .secondClick(let point): actions.append(("second", point))
            default: break
            }
        }
        let point = Touch(x: 9778, y: 3228) // Stationary tap from the user's log.
        func begin() {
            context.activeTouches[0] = point
            context.gestureStartPoints[0] = point
            machine.update()
            gesture.touchBegan(fingerId: 0, touch: point, context: context)
        }
        func release() {
            gesture.touchEnded(fingerId: 0, touch: point, context: context)
            context.activeTouches.removeAll()
            machine.update()
        }
        begin()
        precondition(actions.isEmpty, "touchdown must not move cursor before single-touch intent is known")
        release()
        precondition(actions.map { $0.0 } == ["move", "down", "up"], "stationary tap aligns before pressing")
        precondition(actions.allSatisfy { $0.1.x == point.x && $0.1.y == point.y }, "move and click use identical touchdown coordinates")
        actions.removeAll()
        begin(); release()
        precondition(actions.map { $0.0 } == ["move", "second"], "second tap emits only the second click after alignment")
        actions.removeAll()
        let shifted = Touch(x: point.x + 80, y: point.y + 40)
        context.activeTouches[0] = shifted
        context.gestureStartPoints[0] = shifted
        machine.update()
        gesture.touchBegan(fingerId: 0, touch: shifted, context: context)
        gesture.touchEnded(fingerId: 0, touch: shifted, context: context)
        context.activeTouches.removeAll(); machine.update()
        precondition(actions.map { $0.0 } == ["move", "second"], "shifted recognized double tap still emits a single continuation")
        precondition(actions.allSatisfy { $0.1.x == point.x && $0.1.y == point.y }, "second-click alignment and button events use the first click location")
        gesture.reset(); actions.removeAll()
        begin()
        context.activeTouches[1] = Touch(x: 11000, y: 3500)
        machine.update()
        gesture.cancelDelayedMouseDown()
        gesture.cancelContextMenuTimer()
        release()
        precondition(actions.isEmpty, "multitouch cancellation cannot align or click")
        // No reset here: reproduce a multi-touch release immediately followed
        // by a new tap using the same slot. The release must not seed double-click.
        begin(); release()
        precondition(actions.map { $0.0 } == ["move", "down", "up"], "multi-touch UP cannot become the first click of a false double-click")
        gesture.reset(); actions.removeAll()
        context.fourFingerProtectionEndTime = Date().addingTimeInterval(1)
        begin(); release()
        precondition(actions.isEmpty, "gesture protection blocks alignment as well as clicking")
        gesture.reset()
        actions.removeAll()
        begin()
        context.activeTouches[1] = Touch(x: 11000, y: 3500)
        context.activeTouches[2] = Touch(x: 11500, y: 4000)
        context.activeTouches[3] = Touch(x: 12000, y: 4500)
        machine.update()
        gesture.cancelDelayedMouseDown()
        gesture.cancelContextMenuTimer()
        context.activeTouches.removeValue(forKey: 3)
        machine.startFourFingerProtection(duration: 0.8)
        machine.update()
        context.activeTouches.removeValue(forKey: 2)
        context.activeTouches.removeValue(forKey: 1)
        machine.update()
        precondition(!context.isSingleTouchAllowed, "residual last finger remains blocked after multi-finger gesture")
        gesture.touchMoved(fingerId: 0, touch: point, context: context)
        gesture.touchEnded(fingerId: 0, touch: point, context: context)
        precondition(actions.isEmpty, "residual movement/lift cannot become a cursor move or click")
        context.activeTouches.removeAll()
        machine.update()
        precondition(context.isInFourFingerProtection, "all-up retains tail protection against late reports")
        gesture.reset()
        begin()
        precondition(!context.isSingleTouchAllowed, "reappearing contact inside cooldown remains protected")
        release()
        precondition(actions.isEmpty, "brief all-up then DOWN cannot bypass protection")
        context.fourFingerProtectionEndTime = .distantPast
        gesture.reset()
        begin(); release()
        precondition(actions.map { $0.0 } == ["move", "down", "up"], "normal tap works after protection expires")
        actions.removeAll()
        machine.startFourFingerProtection(duration: 0.8)
        precondition(context.isInFourFingerProtection, "empty gesture end retains legacy cooldown semantics")
        gesture.reset()
        print("PASS: stationary tap target alignment, event order, double tap, multitouch cancellation, protection")
        print("PASS: multi-finger tail blocked, brief full release retains cooldown, normal tap after expiry")
    }
}
