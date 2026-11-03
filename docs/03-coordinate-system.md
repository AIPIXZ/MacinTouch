# 坐标系统和转换详解

## 坐标系统概述

在触摸屏驱动开发中，需要处理多个不同的坐标系统，每个系统都有其特定的原点、方向和范围。

## 涉及的坐标系统

### 1. 硬件坐标系统 (Hardware Coordinates)

**特征**:
- **原点**: 左上角 (1, 1)
- **范围**: X: 1-16383, Y: 1-9599
- **方向**: X 向右递增，Y 向下递增
- **数据类型**: 整数

**示例**:
```
(1, 1)           (16383, 1)
  ┌─────────────────┐
  │                 │
  │                 │
  │                 │
  └─────────────────┘
(1, 9599)       (16383, 9599)
```

### 2. 标准化坐标系统 (Normalized Coordinates)

**特征**:
- **原点**: 左上角 (0.0, 0.0)
- **范围**: X: 0.0-1.0, Y: 0.0-1.0
- **方向**: X 向右递增，Y 向下递增
- **数据类型**: 浮点数

**转换公式**:
```swift
let normalizedX = (touchX - HARDWARE_MIN_X) / touchRangeX
let normalizedY = (touchY - HARDWARE_MIN_Y) / touchRangeY
```

### 3. AppKit 坐标系统 (AppKit/NSScreen Coordinates)

**特征**:
- **原点**: 左下角 (0, 0)
- **范围**: 根据屏幕分辨率
- **方向**: X 向右递增，Y 向上递增
- **用途**: NSScreen.frame, NSEvent.mouseLocation

**示例** (1920x1080 屏幕):
```
(0, 1080)       (1920, 1080)
  ┌─────────────────┐
  │                 │
  │                 │
  │                 │
  └─────────────────┘
(0, 0)           (1920, 0)
```

### 4. Core Graphics 坐标系统 (CGEvent Coordinates)

**特征**:
- **原点**: 左上角 (0, 0)
- **范围**: 根据屏幕分辨率
- **方向**: X 向右递增，Y 向下递增
- **用途**: CGEvent.mouseLocation, 鼠标事件模拟

**示例** (1920x1080 屏幕):
```
(0, 0)           (1920, 0)
  ┌─────────────────┐
  │                 │
  │                 │
  │                 │
  └─────────────────┘
(0, 1080)       (1920, 1080)
```

## 坐标转换流程

### 完整转换链路

```
硬件坐标 → 标准化坐标 → AppKit坐标 → CGEvent坐标
```

### 详细转换步骤

#### 步骤1: 硬件坐标 → 标准化坐标

```swift
// 硬件坐标范围
let HARDWARE_MIN_X = 1.0
let HARDWARE_MAX_X = 16383.0
let HARDWARE_MIN_Y = 1.0
let HARDWARE_MAX_Y = 9599.0

// 计算坐标范围
let touchRangeX = HARDWARE_MAX_X - HARDWARE_MIN_X  // 16382
let touchRangeY = HARDWARE_MAX_Y - HARDWARE_MIN_Y  // 9598

// 标准化坐标 (0.0 到 1.0)
let normalizedX = max(0.0, min(1.0, (Double(touchX) - HARDWARE_MIN_X) / touchRangeX))
let normalizedY = max(0.0, min(1.0, (Double(touchY) - HARDWARE_MIN_Y) / touchRangeY))
```

#### 步骤2: 标准化坐标 → AppKit坐标

```swift
// 获取目标屏幕信息
let screenFrame = targetScreen.frame
let screenOffsetX = screenFrame.origin.x
let screenOffsetY = screenFrame.origin.y
let screenWidth = screenFrame.width
let screenHeight = screenFrame.height

// 映射到 AppKit 坐标系
let appKitX = screenOffsetX + (normalizedX * screenWidth)
let appKitY = screenOffsetY + (normalizedY * screenHeight)
```

#### 步骤3: AppKit坐标 → CGEvent坐标

```swift
// 获取主显示器高度（用于Y轴翻转）
guard let primaryScreen = NSScreen.screens.first else { return }
let primaryScreenHeight = primaryScreen.frame.height

// Y轴翻转转换
let cgEventX = appKitX
let cgEventY = primaryScreenHeight - appKitY
```

## 关键问题和解决方案

### 1. Y轴方向不一致

**问题**: 不同坐标系统的Y轴方向不同
- 硬件坐标: Y向下递增
- AppKit坐标: Y向上递增  
- CGEvent坐标: Y向下递增

**解决方案**: 在适当的转换步骤中进行Y轴翻转

```swift
// 硬件 → 标准化：需要Y轴反转
let normalizedY = 1.0 - (Double(touchY) - HARDWARE_MIN_Y) / touchRangeY

// AppKit → CGEvent：需要Y轴翻转
let cgEventY = primaryScreenHeight - appKitY
```

### 2. 多显示器坐标偏移

**问题**: 外接显示器可能有负坐标偏移

**示例配置**:
- 主显示器: 1512x982 @ (0, 0)
- 4K显示器: 1920x1080 @ (-1920, 138)

**解决方案**: 使用屏幕的 origin 进行坐标偏移

```swift
let finalX = screenOffsetX + (normalizedX * screenWidth)
let finalY = screenOffsetY + (normalizedY * screenHeight)
```

### 3. NSScreen.main 动态变化

**问题**: NSScreen.main 会根据键盘焦点变化，导致坐标转换基准不稳定

**错误做法**:
```swift
// ❌ 错误：NSScreen.main 会变化
let mainScreen = NSScreen.main
let baseHeight = mainScreen.frame.height
```

**正确做法**:
```swift
// ✅ 正确：使用稳定的主显示器
guard let primaryScreen = NSScreen.screens.first else { return }
let baseHeight = primaryScreen.frame.height
```

### 4. 缩放因子处理

**问题**: 4K显示器通常有2.0x的缩放因子

**解决方案**: 使用逻辑分辨率而非物理分辨率

```swift
// 获取逻辑分辨率
let screenFrame = screen.frame  // 已经是逻辑分辨率
let screenWidth = screenFrame.width   // 1920 (不是 3840)
let screenHeight = screenFrame.height // 1080 (不是 2160)
```

## 调试坐标转换

### 调试输出示例

```
🖥️  步骤4: DisplayManager坐标转换
   硬件坐标: (6323, 3972)
   硬件范围: X=1.0-16383.0, Y=1.0-9599.0
   标准化坐标: (0.386, 0.586)
   屏幕Frame: origin=(-1920, 138), size=(1920x1080)
   映射计算: X=-1920 + (0.386 * 1920) = -1179
   AppKit Y计算: 138 + (0.586 * 1080) = 771
   主屏幕高度: 982（动态获取）
   CGEvent Y转换: 982 - 771 = 210
   最终CGEvent全局坐标: (-1179, 210)
```

### 验证方法

1. **边界测试**: 测试四个角落的坐标转换
2. **中心点测试**: 验证屏幕中心的坐标准确性
3. **鼠标位置对比**: 对比期望坐标与实际鼠标位置
4. **多显示器测试**: 在不同显示器间切换测试

## 最佳实践

### 1. 坐标转换原则
- 保持转换链路的一致性
- 在每个步骤验证坐标范围
- 使用稳定的基准坐标系

### 2. 调试策略
- 分步骤输出坐标转换过程
- 对比多个坐标系统的值
- 记录边界情况的处理

### 3. 错误处理
- 检查坐标范围的有效性
- 处理显示器配置异常
- 提供降级方案

## 常见坐标转换错误

### 1. Y轴方向错误
**症状**: 触摸上方，鼠标在下方
**原因**: 忘记进行Y轴翻转
**解决**: 检查Y轴转换逻辑

### 2. 坐标偏移错误
**症状**: 鼠标位置偏移固定距离
**原因**: 未考虑屏幕偏移量
**解决**: 添加屏幕origin偏移

### 3. 缩放因子错误
**症状**: 坐标比例不正确
**原因**: 混用物理分辨率和逻辑分辨率
**解决**: 统一使用逻辑分辨率

### 4. 基准不稳定
**症状**: 坐标时准时不准
**原因**: 使用了会变化的NSScreen.main
**解决**: 改用NSScreen.screens.first