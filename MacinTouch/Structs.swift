//
//  Structs.swift
//  MacinTouch
//
//  Data structures for touch events and HID processing
//

import Foundation

/*--------------------------------   Enums   ---------------------------------*/

enum InputType {
    case UP
    case DOWN
    case RIGHT_CLICK
    case DBL_CLICK
    case NO_CHANGE
    case MOVE
    case DRAG

    // Gesture types
    case NOTIFICATION_CENTER
    case SCROLL_UP
    case SCROLL_DOWN
    case PINCH_ZOOM_IN
    case PINCH_ZOOM_OUT
    
    // Four-finger gestures - 4指手势
    case FOUR_FINGER_SWIPE_UP      // 4指向上滑动 - Mission Control
    case FOUR_FINGER_SWIPE_DOWN    // 4指向下滑动 - App Exposé
    case FOUR_FINGER_SWIPE_LEFT    // 4指向左滑动 - 切换到右边的桌面
    case FOUR_FINGER_SWIPE_RIGHT   // 4指向右滑动 - 切换到左边的桌面
    case FOUR_FINGER_TAP           // 4指轻拍 - Launchpad
}

enum HIDEventType {
    case TIPSWITCH      // 触摸开关
    case PRESS          // 按压事件
    case CONTACTID      // 触摸点ID
    case XCOORD         // X坐标
    case YCOORD         // Y坐标
    case FINGERCOUNT    // 手指数量
    case PRESSURE       // 压力值
    case CONTACT_WIDTH  // 触摸宽度
    case CONTACT_HEIGHT // 触摸高度
}

enum TouchState {
    case INACTIVE       // 未激活
    case ACTIVE         // 激活中
    case MOVING         // 移动中
    case RELEASED       // 已释放
}

/*-----------------------------  Touch struct  -------------------------------*/

struct Touch {
    var x: Int
    var y: Int
    var pressure: Int
    var contactId: Int
    var width: Int
    var height: Int
    let when: Date
    var state: TouchState
    
    init(x: Int, y: Int, pressure: Int = 0, contactId: Int = 0, 
         width: Int = 0, height: Int = 0, state: TouchState = .INACTIVE) {
        self.x = x
        self.y = y
        self.pressure = pressure
        self.contactId = contactId
        self.width = width
        self.height = height
        self.when = Date()
        self.state = state
    }
    
    // 计算两个触摸点之间的距离
    func distFrom(p: Touch) -> Double {
        return sqrt(pow(Double(x - p.x), 2) + pow(Double(y - p.y), 2))
    }
    
    // 检查是否在指定区域内
    func isInRegion(x: Int, y: Int, width: Int, height: Int) -> Bool {
        return self.x >= x && self.x <= x + width && 
               self.y >= y && self.y <= y + height
    }
}

/*-----------------------------  Event struct  -------------------------------*/

struct TouchEvent {
    let finger: Int
    let when: Date
    let type: HIDEventType
    let button: InputType?
    let input: Int
    let touch: Touch?
    
    init(finger: Int, type: HIDEventType, button: InputType? = nil, 
         input: Int = 0, touch: Touch? = nil) {
        self.finger = finger
        self.when = Date()
        self.type = type
        self.button = button
        self.input = input
        self.touch = touch
    }
}

// Pretty Print Events
extension TouchEvent: CustomStringConvertible {
    public var description: String {
        let time = when.timeIntervalSince1970
            .truncatingRemainder(dividingBy: 1000)
        let time_str = String(format: "%.4f", time)
        
        let type_str = String(describing: type)
            .padding(toLength: 12, withPad: " ", startingAt: 0)
        
        var s = "[\(time_str)] F\(finger) | \(type_str)"
        
        if let button = button {
            s += " \(button)"
        }
        
        if type == .XCOORD || type == .YCOORD {
            s += " \(input)"
        }
        
        if let touch = touch {
            s += " (\(touch.x),\(touch.y))"
            if touch.pressure > 0 {
                s += " P:\(touch.pressure)"
            }
        }
        
        return s
    }
}

/*---------------------------  Gesture struct  -------------------------------*/

struct Gesture {
    let type: InputType
    let startTime: Date
    let endTime: Date
    let startTouch: Touch
    let endTouch: Touch
    let fingerCount: Int
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    var distance: Double {
        return startTouch.distFrom(p: endTouch)
    }
}

/*-------------------------  Multi-touch Context  ----------------------------*/

class MultiTouchContext {
    var activeTouches: [Int: Touch] = [:]
    var touchHistory: [TouchEvent] = []
    var gestureInProgress: Gesture?
    var lastFingerCount: Int = 0
    
    func addTouch(_ touch: Touch, fingerId: Int) {
        activeTouches[fingerId] = touch
    }
    
    func removeTouch(fingerId: Int) {
        activeTouches.removeValue(forKey: fingerId)
    }
    
    func updateTouch(_ touch: Touch, fingerId: Int) {
        activeTouches[fingerId] = touch
    }
    
    func getActiveFingerCount() -> Int {
        return activeTouches.count
    }
    
    func clearAll() {
        activeTouches.removeAll()
        gestureInProgress = nil
        lastFingerCount = 0
    }
}