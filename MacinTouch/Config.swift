//
//  Config.swift
//  MacinTouch
//
//  Legacy compile-time constants. Kept for backward compatibility.
//  New code should use DriverConfig (TouchDriver/DriverConfig.swift) instead —
//  it is Codable, runtime-configurable, and shared between the CLI driver and GUI.
//

import Foundation

// ILITEK Touchscreen Device Info
let TOUCH_VID: Int32 = 0x222a  // ILITEK Vendor ID
let TOUCH_PID: Int32 = 0x0001  // ILITEK Product ID

// Touchscreen Hardware Coordinate Range (基于实际测试确定)
// 硬件原始坐标范围: X: 1-16383, Y: 1-9599
let TOUCH_RESX = 16382.0  // 触摸屏X轴硬件坐标范围 (16383-1)
let TOUCH_RESY = 9598.0   // 触摸屏Y轴硬件坐标范围 (9599-1)

// Multi-touch Configuration
let NUM_TOUCHES = 10  // 最大支持触摸点数

// Gesture Timing Configuration
let DOUBLECLICK_DELAY: TimeInterval = 0.25  // 双击间隔时间
let CONTEXT_MENU_DELAY: TimeInterval = 0.6   // 右键菜单长按时间
let TAP_TIMEOUT: TimeInterval = 0.1          // 点击超时时间

// Delayed Mouse Down
let MOUSE_DOWN_DELAY: TimeInterval = 0.05  // Delay before sending mouseDown (prevents accidental clicks during multi-touch)

// Gesture Distance Thresholds
let MOVEMENT_THRESHOLD_PIXELS = 15.0  // 右键取消阈值(像素单位)
let DRAG_THRESHOLD_PIXELS = 8.0       // 拖动触发阈值(像素单位) - 调整为更合理的值
let NOTIFICATION_CENTER_X_DELTA = 60  // 通知中心手势X轴阈值
let NOTIFICATION_CENTER_Y_DELTA = 40  // 通知中心手势Y轴阈值

// Scroll Gesture Configuration
let SCROLL_THRESHOLD_PIXELS = 1.0     // 滚动触发阈值(像素单位) - 降低阈值提高响应
let MIN_FINGER_DISTANCE = 50.0        // 双指最小间距(像素)
let MAX_FINGER_DISTANCE = 500.0       // 双指最大间距(像素)

// Four-Finger Gesture Configuration - 4指手势配置
let FOUR_FINGER_GESTURE_ENABLED = true        // 启用4指手势
let FOUR_FINGER_MIN_DISTANCE = 60.0           // 4指最小间距(像素) - 降低以60px
let FOUR_FINGER_MAX_DISTANCE = 700.0          // 4指最大间距(像素) - 提高到700px
let FOUR_FINGER_SWIPE_THRESHOLD = 60.0        // 4指滑动触发阈值(像素) - 降低到60px更灵敏
let FOUR_FINGER_SWIPE_MIN_VELOCITY = 100.0    // 4指滑动最小速度(像素/秒) - 降低到100px/s
let FOUR_FINGER_LONG_PRESS_DURATION = 0.6     // 4指长按触发时间(秒) - 与单指右键一致
let FOUR_FINGER_LONG_PRESS_MAX_MOVEMENT = 40.0 // 4指长按最大移动距离(像素) - 放宽到40px
let FOUR_FINGER_DETECTION_BUFFER = 0.15       // 4指检测缓冲期(秒) - 缩短到150ms
let FOUR_FINGER_SWIPE_EARLY_DETECTION = 30.0  // 4指滑动早期检测阈值(像素) - 降低到30px

// Touch Direct Mapping Scroll - 触摸直接映射滚动配置
let DIRECT_SCROLL_ENABLED = true      // 启用直接映射滚动 (手指移动距离 = 滚动距离)
let SCROLL_DIRECTION_INVERT_Y = true  // Y轴方向反转 (向上滑动 = 向下滚动)

// Scroll Smoothing Configuration - 滚动平滑配置
let SCROLL_SMOOTHING_ENABLED = false   // 启用滚动平滑
let SCROLL_SMOOTHING_FACTOR = 0.4     // 平滑系数 (0.0-1.0, 越小越平滑，触摸直接映射建议0.3-0.5)
let SCROLL_HISTORY_SIZE = 3           // 滚动历史缓冲区大小
let SCROLL_MIN_DELTA = 0.5            // 最小滚动增量，过滤微小抖动 (直接映射时降低阈值)

// Inertial Scrolling Configuration - 惯性滚动配置
let INERTIAL_SCROLL_ENABLED = true              // 启用惯性滚动
let INERTIAL_SCROLL_MIN_VELOCITY = 200.0        // 最小触发速度 (pixels/second)
let INERTIAL_SCROLL_DECAY_FACTOR = 0.98         // 衰减系数 (每帧，0.95-0.98)
let INERTIAL_SCROLL_MIN_SPEED = 10.0            // 最小持续速度 (低于此值停止)
let INERTIAL_SCROLL_FRAME_RATE = 60.0           // 更新频率 (fps)
let INERTIAL_VELOCITY_TIME_WINDOW = 0.1         // 速度计算时间窗口 (100ms)
let INERTIAL_MIN_TIME_INTERVAL = 0.016          // 最小时间间隔 (16ms，避免除零)

// 🚀 Acceleration Enhancement - 加速度增强配置
let INERTIAL_ACCELERATION_ENABLED = true        // 启用加速度增强
let INERTIAL_ACCELERATION_BOOST = 1.5           // 加速度增强系数 (1.0-2.0，越大增强越明显)
let INERTIAL_ACCELERATION_WINDOW = 0.15         // 加速度计算时间窗口 (150ms)
let INERTIAL_MAX_BOOST_FACTOR = 2.0            // 最大增强倍数 (加速时的最大倍率)
let INERTIAL_MIN_BOOST_FACTOR = 0.5            // 最小减弱倍数 (减速时的最小倍率)

// Pinch Zoom Configuration - 双指缩放配置
let PINCH_ENABLED = true                    // 启用双指缩放
let PINCH_THRESHOLD = 3.0                   // 缩放触发阈值（像素）- 大幅降低以提高灵敏度
let PINCH_SCALE_FACTOR = 0.8                // 距离转滚轮系数 - 增加到0.8以提高缩放灵敏度
let PINCH_MIN_DISTANCE = 30.0               // 最小手指间距
let PINCH_MAX_DISTANCE = 600.0              // 最大手指间距

// Debug Configuration
let DEBUG_ENABLED = true        // 主调试输出开关
let VERBOSE_LOGGING = false     // 详细日志开关

// 细粒度调试开关
let DEBUG_TOUCH_EVENTS = false   // 触摸事件调试
let DEBUG_COORDINATES = false    // 坐标事件调试  
let DEBUG_GESTURES = false       // 手势调试（右键、拖动等）
let DEBUG_HID_PARSING = false    // HID解析调试
let DEBUG_FINGER_COUNT = false   // 手指数量调试
let DEBUG_DOUBLE_CLICK = false   // 双击调试
let DEBUG_RIGHT_CLICK_DETAIL = false   // 右键详细调试 - 问题已解决，关闭
let DEBUG_SCROLL = true          // 滚动手势调试
let DEBUG_FOUR_FINGER = false    // 4指手势调试
let DEBUG_FOUR_FINGER_VERBOSE = false // 4指手势详细调试
let DEBUG_PINCH = false           // 缩放手势调试 - 临时开启查看检测过程

// 简化日志开关 - 只显示关键手势事件
let DEBUG_GESTURE_SUMMARY = true  // 手势摘要：开始/结束/切换
let DEBUG_IMPORTANT_EVENTS = true // 重要事件：右键、双击、滚动开始/结束

// 🐭 鼠标位置跟踪调试开关（用于调试双指手势后的鼠标跳转问题）
let DEBUG_MOUSE_TRACKING = true  // 设为false可关闭所有鼠标跟踪日志

// Device Specific Settings
struct ILITEKConfig {
    // HID报告相关配置
    static let REPORT_SIZE = 256
    static let MAX_CONTACTS = 10
    
    // 坐标转换参数 (不在TouchHandler中应用偏移，由DisplayManager处理)
    static let COORDINATE_SCALE_X = 1.0
    static let COORDINATE_SCALE_Y = 1.0
    static let COORDINATE_OFFSET_X = 0      // 不在此处应用偏移
    static let COORDINATE_OFFSET_Y = 0      // 不在此处应用偏移
    
    // 触摸压力相关
    static let PRESSURE_THRESHOLD = 10
    static let MAX_PRESSURE = 255
}