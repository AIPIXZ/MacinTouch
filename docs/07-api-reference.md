# API 参考文档

## HIDSetup.c

```c
// 初始化 HID 通知，发现设备后持续监听
void InitHIDNotifications(SInt32 vendorID, SInt32 productID, HIDElementCallback callback);

// 回调类型
typedef void (*HIDElementCallback)(HIDElement* element);

// HID 元素结构
typedef struct {
    uint32_t  usagePage;
    uint32_t  usage;
    uint32_t  cookie;
    CFIndex   currentValue;
    CFIndex   minValue;
    CFIndex   maxValue;
} HIDElement;
```

---

## TouchHandler.swift

```swift
class TouchHandler {
    init(context: MultiTouchContext)

    // 处理来自 HIDSetup.c 的单个元素
    func processHIDElement(element: HIDElement)
}
```

Cookie 到手指/轴的映射：

| Cookie | 含义 |
|--------|------|
| 43 | F0 X 坐标 |
| 44 | F0 Y 坐标 |
| 46 | F1 X 坐标 |
| 47 | F1 Y 坐标 |
| 27 | F0 压力 |
| 28 | F1 压力 |

---

## Gestures/GestureRecognizer.swift

```swift
// 手势动作枚举（TouchHandler 将其分发给 InputSimulator）
enum GestureAction {
    case mouseDown(CGPoint)
    case mouseUp(CGPoint)
    case mouseMove(CGPoint)
    case rightClick(CGPoint)
    case doubleClick(CGPoint)
    case scroll(dx: CGFloat, dy: CGFloat)
    case pinchZoom(delta: CGFloat)
    case fourFingerGesture(FourFingerDirection)
    case ensureCommandKeyReleased
    case cleanupAllModifierKeys
}

// 手势识别器协议
protocol GestureRecognizer {
    func touchBegan(id: Int, point: CGPoint, context: GestureContext)
    func touchMoved(id: Int, point: CGPoint, context: GestureContext)
    func touchEnded(id: Int, context: GestureContext)
    func fingerCountChanged(count: Int, context: GestureContext)
    func reset(context: GestureContext)
}

// 共享上下文（跨识别器共享触摸状态）
class GestureContext {
    var activeTouches: [Int: CGPoint]
    var gestureStartPoints: [Int: CGPoint]

    func emit(_ action: GestureAction)
    func pixelDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat
}
```

---

## DisplayManager.swift

```swift
class DisplayManager {
    static let shared: DisplayManager

    // 三步转换的快捷方式（推荐使用）
    func convertHardwareToCGEvent(x: Int, y: Int) -> CGPoint

    // 分步转换
    func convertHardwareToAppKitScreen(x: Int, y: Int) -> CGPoint
    func convertAppKitScreenToCGEvent(_ point: CGPoint) -> CGPoint
    func convertCGEventToAppKitScreen(_ point: CGPoint) -> CGPoint

    // 显示器选择
    func setAutomaticDisplaySelection()
    func selectDisplay(byID: CGDirectDisplayID)
    func getCurrentDisplayID() -> CGDirectDisplayID?

    // 回调
    var onDisplayConfigChanged: (() -> Void)?
}
```

---

## InputSimulator.swift

```swift
class InputSimulator {
    // 鼠标事件
    static func mouseDown(at cgPoint: CGPoint)
    static func mouseUp(at cgPoint: CGPoint)
    static func mouseMove(to cgPoint: CGPoint)
    static func rightClick(at cgPoint: CGPoint)
    static func doubleClick(at cgPoint: CGPoint)

    // 滚动（单位：像素，dy>0 向上）
    static func scroll(dx: CGFloat, dy: CGFloat)

    // 捏合缩放（delta>0 放大，Cmd+滚轮模拟）
    static func pinchZoom(delta: CGFloat)

    // 4指手势（Control+Arrow）
    static func fourFingerGesture(_ direction: FourFingerDirection)

    // Launchpad
    static func launchLaunchpad()

    // 修饰键清理
    static func ensureControlKeyReleased()
    static func ensureCommandKeyReleased()
    static func cleanupAllModifierKeys()
}
```

---

## DriverConfig.swift

```swift
struct DriverConfig: Codable, Equatable {
    var device: DeviceConfig
    var gestures: GestureConfig
    var scroll: ScrollConfig
    var pinch: PinchConfig
    var fourFinger: FourFingerConfig
    var display: DisplayConfig
    var logging: LogConfig

    static let `default`: DriverConfig

    // 持久化（~/Library/Application Support/MacinTouch/config.json）
    func save() throws
    static func load() throws -> DriverConfig
    static func loadOrDefault() -> DriverConfig
}

struct DriverStatus: Equatable {
    var isRunning: Bool
    var deviceConnected: Bool
    var hasAccessibilityPermission: Bool
    var hasInputMonitoringPermission: Bool
    var errorMessage: String?
    var isFullyOperational: Bool { get }
}
```

关键配置默认值：

| 字段 | 默认值 |
|------|--------|
| `gestures.contextMenuDelay` | 0.6s |
| `gestures.movementThreshold` | 15px |
| `gestures.mouseDownDelay` | 0.05s |
| `scroll.invertY` | true |
| `scroll.inertialEnabled` | true |
| `scroll.accelerationBoost` | 1.5× |
| `pinch.enabled` | true |
| `pinch.scaleFactor` | 0.8 |
| `fourFinger.minDistance` | 60px |
| `fourFinger.swipeThreshold` | 60px |
| `fourFinger.swipeMinVelocity` | 100px/s |
| `fourFinger.longPressDuration` | 0.6s |
| `fourFinger.detectionBuffer` | 0.15s |

---

## TouchDriverInterface.swift

```swift
protocol TouchDriverInterface: AnyObject {
    var status: DriverStatus { get }
    var config: DriverConfig { get set }  // set 立即生效并持久化

    func start()
    func stop()
    func restart()
    func onStatusChange(_ handler: @escaping (DriverStatus) -> Void)
}
```

实现类：`TouchDriverCore`（GUI 内嵌 in-process 实现）

---

## Logger.swift

```swift
struct Log {
    static func configure(with config: LogConfig)
    static func debug(_ category: LogCategory, _ message: String)
    static func info(_ category: LogCategory, _ message: String)
    static func warn(_ category: LogCategory, _ message: String)
    static func error(_ category: LogCategory, _ message: String)
}

enum LogCategory {
    case hid, gesture, singleTouch, scroll, pinch, fourFinger
    case coordinates, mouse, display, system
}

enum LogLevel: Int {
    case debug = 0, info, warning, error
}
```
