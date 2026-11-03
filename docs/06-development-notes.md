# 开发笔记和经验

## 🚀 项目开发历程

### 阶段1: 项目初始化和基础架构

#### 技术选型决策
- **语言选择**: Swift + C 混合开发
  - C 语言处理底层 HID 接口（性能关键）
  - Swift 处理业务逻辑（开发效率高）
- **构建系统**: Xcode + Makefile 双重支持
  - Xcode 用于开发和调试
  - Makefile 用于自动化构建和部署

#### 架构设计原则
- **单一职责**: 每个模块只负责一个特定功能
- **松耦合**: 模块间通过明确的接口交互
- **可测试性**: 每个组件都可以独立测试

### 阶段2: HID 接口开发

#### 关键挑战
1. **HID 报告格式解析**
   - ILITEK 设备的 HID 报告格式复杂
   - 需要根据 Usage Page 和 Usage 值区分不同数据类型
   - Cookie 值用于区分多点触摸的不同手指

2. **回调函数设计**
   - C 语言回调函数与 Swift 代码的桥接
   - 异步事件处理的线程安全问题

#### 解决方案
```c
// HIDSetup.c - 关键的回调函数设计
static void HIDInputValueCallback(void* context, IOReturn result, void* sender, IOHIDValueRef value) {
    // 解析 HID 数据
    IOHIDElementRef element = IOHIDValueGetElement(value);
    uint32_t usagePage = IOHIDElementGetUsagePage(element);
    uint32_t usage = IOHIDElementGetUsage(element);
    
    // 调用 Swift 回调
    if (hidElementCallback) {
        hidElementCallback(hidElement);
    }
}
```

### 阶段3: 触摸事件处理

#### 状态机设计
触摸事件的状态管理是一个复杂的状态机：

```
空闲 → 按下 → 移动 → 抬起 → 空闲
  ↓      ↓      ↓      ↓
手势识别 → 双击检测 → 右键检测
```

#### 多点触摸处理
```swift
// TouchHandler.swift - 多点触摸状态管理
private var activeTouches: [Int: Touch] = [:]
private var gestureStartPoints: [Int: Touch] = [:]
private var lastTouchTimes: [Int: CFAbsoluteTime] = [:]
```

### 阶段4: 坐标系统转换

#### 最大的技术挑战
坐标系统转换是整个项目最复杂的部分，涉及4个不同的坐标系统：

1. **硬件坐标系** (1-16383, 1-9599)
2. **标准化坐标系** (0.0-1.0, 0.0-1.0)
3. **AppKit坐标系** (屏幕坐标，Y向上)
4. **CGEvent坐标系** (全局坐标，Y向下)

#### 关键突破点
发现 `NSScreen.main` 会动态变化的问题是整个项目的关键突破点：

```swift
// 问题发现过程
// 1. 观察到主显示器高度在 982 和 1080 之间变化
// 2. 最初以为是菜单栏高度的问题
// 3. 深入分析后发现是焦点屏幕的变化
// 4. 查阅 Apple 文档确认了 NSScreen.main 的行为
```

#### 解决方案演进
```swift
// 版本1: 使用 NSScreen.main (错误)
let mainScreen = NSScreen.main

// 版本2: 固定初始化时的主屏幕 (部分正确)
let fixedMainScreen = NSScreen.main  // 初始化时获取

// 版本3: 使用 NSScreen.screens.first (正确)
let primaryScreen = NSScreen.screens.first  // 动态获取真正的主屏
```

## 💡 技术经验总结

### 1. macOS 开发经验

#### HID 设备编程
- **IOKit 框架**: macOS 底层硬件访问的标准方式
- **HID Manager**: 设备发现和管理的核心 API
- **回调机制**: 异步事件处理的标准模式

#### 权限和安全
- **辅助功能权限**: 模拟输入事件的必要权限
- **代码签名**: macOS 安全机制的要求
- **沙盒限制**: 系统级应用的特殊考虑

### 2. Swift 与 C 混合编程

#### 桥接技术
```swift
// MacinTouch-Bridging-Header.h
#import "HIDSetup.h"

// Swift 中调用 C 函数
InitializeHIDManager { hidElement in
    // Swift 回调处理
}
```

#### 内存管理
- C 语言部分需要手动管理内存
- Swift 部分使用 ARC 自动管理
- 跨语言边界的对象生命周期管理

### 3. 坐标系统编程经验

#### 坐标转换的通用原则
1. **明确每个坐标系统的特征**（原点、方向、范围）
2. **保持转换链路的一致性**
3. **在关键点进行边界检查**
4. **详细记录转换公式和原理**

#### Y轴处理经验
```swift
// Y轴翻转的通用模式
let flippedY = screenHeight - originalY

// 标准化坐标的Y轴翻转
let normalizedY = 1.0 - rawNormalizedY
```

## 🔮 未来改进方向

### 1. 功能扩展
- **多设备支持**: 支持不同型号的 ILITEK 设备（不同 VID/PID）
- ~~**配置界面**: 提供图形化的配置界面~~ ✅ 已完成（SwiftUI 菜单栏 GUI）
- **手势扩展**: 自定义手势映射（用户可定义4指手势触发的操作）
- **热键支持**: 支持自定义热键功能

### 2. 性能优化
- **GPU 加速**: 使用 Metal 进行坐标转换计算
- **多线程优化**: 优化事件处理的并发性能
- **内存优化**: 减少内存分配和释放

### 3. 用户体验
- ~~**安装程序**: 提供自动化的安装和配置~~ ✅ 已完成（DMG 分发，拖拽安装）
- ~~**状态指示**: 提供系统托盘状态指示~~ ✅ 已完成（菜单栏 GUI）
- **错误恢复**: 自动检测和恢复连接错误（睡眠唤醒后自动重连）