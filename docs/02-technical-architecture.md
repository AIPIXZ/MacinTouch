# 技术架构详解

## 系统架构图

```
┌──────────────────────────────────────────────────────────────┐
│                       MacinTouch (CLI)                       │
│                                                              │
│   HIDSetup.c ──→ TouchHandler.swift ──→ Gestures/           │
│       ↓                                      ↓              │
│   [HID 设备]                         InputSimulator.swift    │
│                          ↕                                   │
│                   DisplayManager.swift                       │
│                          ↕                                   │
│                    DriverConfig.swift                        │
└──────────────────────────────────────────────────────────────┘
                              ↑ 共用驱动层
┌──────────────────────────────────────────────────────────────┐
│                    MacinTouchApp (菜单栏应用)                │
│                                                              │
│   MacinTouchCore.swift ──→ TouchDriverInterface             │
│         ↓                                                    │
│   MacinTouchModel.swift                                     │
│         ↓                                                    │
│   MenuBarView / SettingsView                                 │
└──────────────────────────────────────────────────────────────┘
```

## 核心组件

### 1. HIDSetup.c — HID 底层接口

**职责**: 与 macOS IOKit 框架交互，处理 HID 设备底层通信。

**关键功能**:
- 发现并连接 ILITEK 设备（VID: 0x222a, PID: 0x0001）
- 解析 HID 报告数据
- 通过回调将 `HIDElement` 传递给 Swift 层

**核心 API**:
```c
// 初始化 HID 通知并注册回调
void InitHIDNotifications(SInt32 vendorID, SInt32 productID, HIDElementCallback callback);
```

---

### 2. TouchHandler.swift — 触摸事件协调器

**职责**: 精简的协调器（298 行）。解析 HID 元素，维护触摸状态，将事件路由到手势识别器，将 GestureAction 分发给 InputSimulator。

**关键 Cookie 映射**:
| Cookie | 含义 |
|--------|------|
| 43 | F0 X 坐标 |
| 44 | F0 Y 坐标 |
| 46 | F1 X 坐标 |
| 47 | F1 Y 坐标 |
| 27 | F0 压力 |
| 28 | F1 压力 |

---

### 3. Gestures/ — 手势识别模块

8 个独立文件，各司其职：

#### GestureRecognizer.swift — 协议与共享上下文
```swift
protocol GestureRecognizer {
    func touchBegan(id: Int, point: CGPoint, context: GestureContext)
    func touchMoved(id: Int, point: CGPoint, context: GestureContext)
    func touchEnded(id: Int, context: GestureContext)
}

class GestureContext {
    var activeTouches: [Int: CGPoint]
    func emit(_ action: GestureAction)       // 分发动作给 TouchHandler
    func pixelDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat
}
```

#### GestureStateMachine.swift — 状态管理
管理 `idle → singleTouch → multiTouch` 转换，跟踪最大手指数，处理单指到多指过渡时的鼠标释放。

#### SingleTouchGesture.swift — 单指手势（双指滚动模式）
- 点击、双击检测（基于近期抬起事件历史）
- 长按右键（带保护期检查）
- 50ms 延迟 mouseDown（避免多指触摸时误触）

#### SingleFingerScrollGesture.swift — 单指滚动手势（单指滚动模式）

状态机：`idle → pending → scrolling / dragging`

| 阶段 | 触发条件 | 行为 |
|------|---------|------|
| `pending` | 手指落下 | 吸收抖动（<5px），等待意图确认 |
| `scrolling` | 移动超过 5px | 发出滚动事件；光标跳转到手指位置（确保滚动区域匹配） |
| `dragging` | 长按 ~0.6s 未移动 | 发出 mouseDown+拖拽+mouseUp，用于文字选择 |
| 回到 `idle` | 手指抬起 | 轻拍→单击（100ms 延迟），快速双拍→双击，带速度→惯性滚动 |

**双指单击右键**（单指滚动模式）：
- 两指同时按下→右键（直接触发）
- 先后按下（A 抬起后 B 才落下）：通过 `pendingClickFingerId` 检测，取消 A 的待定点击，触发右键
- 右键坐标直接从 `NSEvent.mouseLocation` 转换（不走硬件坐标，避免光标位移）

#### TwoFingerDetector.swift — 双指分类器
状态机：`idle → detecting → scrolling/pinching`

通过三个分数决策：
1. **parallel_score** - 两指移动方向相似度
2. **distance_change** - 距离变化一致性（捏合特征）
3. **avg_similarity** - 综合方向相似度

达到阈值后委托给 ScrollGesture 或 PinchGesture。

#### ScrollGesture.swift — 双指滚动
- 直接映射模式（默认）+ 平滑模式可选
- 惯性滚动：采集样本估算速度 → 速度衰减动画（decay=0.98）
- 加速度增强：检测快速滑动时提升初速度（最大 2x boost）

#### PinchGesture.swift — 双指捏合缩放
- 监测两指距离变化 → 模拟 Cmd+滚轮事件
- 累积 delta 确保缩放平滑
- 结束时确保 Command 键释放

#### FourFingerGesture.swift — 4指手势
- **150ms 缓冲**：等待第4根手指到达
- **快速意图检测**：30px 位移即锁定方向，防止误触发长按
- **滑动**：速度检查 + 方向判断 → Control+Arrow 键
- **轻拍**：≤0.5s、位移 ≤40px → F4（Launchpad）

---

### 4. DisplayManager.swift — 坐标转换

**职责**: 单例，管理显示器配置，提供坐标转换方法。

**坐标转换流程**:
```
硬件坐标 (0-16383)
    ↓ 标准化 + Y轴翻转
归一化坐标 (0.0-1.0)
    ↓ 映射到屏幕
AppKit 屏幕坐标 (左下原点)
    ↓ Y轴翻转（primaryScreenHeight - y）
CGEvent 坐标 (左上原点)
```

**关键方法**:
```swift
func convertHardwareToCGEvent(x: Int, y: Int) -> CGPoint
func convertAppKitScreenToCGEvent(_ point: CGPoint) -> CGPoint
func setAutomaticDisplaySelection()
func selectDisplay(byID: CGDirectDisplayID)
```

---

### 5. InputSimulator.swift — 事件生成

**职责**: 纯 CGEvent 生成层（287 行）。不做坐标转换，直接使用 DisplayManager 提供的坐标。

**支持的事件**:
- 鼠标按下/抬起/移动
- 右键单击、双击
- 滚动事件（方向性和双向）
- 捏合缩放（Cmd+滚轮模拟）
- 4指手势（Control+Arrow）
- Launchpad（Process 调用 `/usr/bin/open -a Launchpad`）
- 修饰键管理（确保 Control/Command 正确释放）

---

### 6. DriverConfig.swift — 共享配置

**职责**: Driver 和 GUI 的配置契约。Codable 结构体，JSON 持久化。

**存储路径**: `~/Library/Application Support/MacinTouch/config.json`

**结构**:
```swift
struct DriverConfig: Codable, Equatable {
    var device: DeviceConfig       // VID/PID、分辨率、压力阈值
    var gestures: GestureConfig    // 延迟、阈值、保护时长
    var scroll: ScrollConfig       // 平滑、惯性、加速
    var pinch: PinchConfig         // 灵敏度、距离范围
    var fourFinger: FourFingerConfig  // 滑动速度、缓冲时间
    var display: DisplayConfig     // 显示器选择
    var logging: LogConfig         // 日志级别和分类
}

struct DriverStatus: Equatable {
    var isRunning: Bool
    var deviceConnected: Bool
    var hasAccessibilityPermission: Bool
    var hasInputMonitoringPermission: Bool
    var errorMessage: String?
}
```

---

### 7. TouchDriverInterface.swift — GUI 接口协议

**职责**: Driver 与 GUI 的解耦契约。当前 GUI 内嵌驱动（in-process），协议设计允许未来分离为 IPC 通信。

```swift
protocol TouchDriverInterface: AnyObject {
    var status: DriverStatus { get }
    var config: DriverConfig { get set }   // set 时立即生效并持久化
    func start()
    func stop()
    func restart()
    func onStatusChange(_ handler: @escaping (DriverStatus) -> Void)
}
```

---

## GUI 架构

### 层次结构

```
MacinTouchAppApp (SwiftUI @main)
    └── MenuBarExtra
        └── MenuBarView                    ← 菜单栏下拉面板
            ├── 状态指示 (DriverStatus)
            ├── 快速开关 (四指/捏合/滚动)
            └── 操作按钮 (设置/重启/退出)

        └── NSWindow → SettingsWindowView  ← 设置窗口
            └── 分页导航
                ├── PermissionsTabView
                ├── DevicesTabView
                ├── GesturesTabView        ← 绑定到 DriverConfig
                ├── StartupTabView
                └── AboutTabView
```

### 数据流

```
DriverConfig (持久化)
    ↕ load/save
TouchDriverCore (实现 TouchDriverInterface)
    ↕ @Published status/config
TouchDriverModel (ObservableObject)
    ↕ SwiftUI Binding
Views (MenuBarView / SettingsView)
```

**变更追踪**: `TouchDriverModel.$config` 通过 Combine 自动检测变化，`saveConfiguration()` 时写回 `TouchDriverCore.config`（触发持久化）。

---

## 数据流总览

```
ILITEK 设备
    ↓ USB HID 报告
HIDSetup.c (IOKit 回调)
    ↓ HIDElement
TouchHandler.swift (解析 cookie)
    ↓ 触摸坐标 + 状态
GestureContext.activeTouches
    ↓ 路由到对应 GestureRecognizer
GestureAction (mouseDown/scroll/pinch/fourFinger...)
    ↓ emit()
InputSimulator.swift (CGEvent 生成)
    ↓ CGEvent.post()
macOS 鼠标/键盘系统事件
```

## 关键设计决策

| 决策 | 原因 |
|------|------|
| C + Swift 混合 | C 处理 IOKit 底层，Swift 处理业务逻辑 |
| 手势模块拆分 | TouchHandler 从 2308 行减至 298 行，各手势独立可测试 |
| DriverConfig 共享 | CLI 和 GUI 使用同一配置结构，避免同步问题 |
| TouchDriverInterface 协议 | 当前 in-process，协议允许未来 XPC 分离 |
| 延迟 mouseDown (50ms) | 双指滚动模式：多指触摸时避免误触发单指点击 |
| pending 阶段吸收抖动 | 单指滚动模式：5px 阈值防止轻放手指误触发滚动 |
| 滚动提交时跳转光标 | 单指滚动模式：确保滚动事件发到手指所在窗口，不是上次光标位置 |
| 右键用 `mouseButtonIsDown` 而非 `CGEventSource.buttonState` | 合成事件通过 cghidEventTap 发出，HID 硬件状态更新有延迟，直接查询会误判 |
| DisplayManager 单例 | 坐标转换需要全局一致的显示器状态 |
