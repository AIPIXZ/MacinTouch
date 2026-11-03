# 调试指南

## 调试构建

```bash
# 构建调试版
make debug

# 运行（CLI 需要 sudo）
sudo make run-debug

# GUI 调试版（不需要 sudo）
make gui-run-debug
```

## 结构化日志

新版驱动使用 `Logger.swift` 替代原来的 `DEBUG_ENABLED` 全局变量。日志按分类和级别过滤：

```swift
// Logger 分类
LogCategory: hid, gesture, singleTouch, scroll, pinch, fourFinger,
             coordinates, mouse, display, system

// Logger 级别
LogLevel: debug, info, warning, error
```

通过 `DriverConfig.logging` 配置（运行时生效）：

```swift
// 在 main.swift 中加载配置后自动应用
let config = DriverConfig.loadOrDefault()
Log.configure(with: config.logging)
```

启用详细输出时，日志格式示例：
```
[HID]    F0 XCOORD=6323 YCOORD=3972 PRESS=DOWN
[COORD]  Hardware(6323,3972) → CGEvent(-1179,210)
[SCROLL] Δ(0,-8.3) velocity=312px/s inertial=true
[4FIN]   swipe detected: UP velocity=450px/s → Control+↑
```

## 调试工具

工具位于 `tools/core/`：

```bash
# 检查设备连接和 VID/PID
swift tools/core/device-check-simple.swift

# 系统兼容性检查（权限、macOS 版本、架构）
swift tools/core/system-check.swift

# 验证 DriverConfig 文件内容
swift tools/core/config-validate.swift

# 实时监控 HID 触摸事件流
swift tools/core/debug-monitor.swift

# 测试手势识别
swift tools/core/gesture-test.swift

# 测试坐标映射精度
swift tools/core/coordinate-test.swift

# 交互式触摸测试
swift tools/core/touch-test.swift
```

## 典型调试场景

### 设备未识别

```bash
# 1. 确认 USB 连接
swift tools/core/device-check-simple.swift

# 2. 查看系统 HID 列表
system_profiler SPUSBDataType | grep -A5 "ILITEK"

# 3. 检查权限
make check-all
```

### 坐标偏移

1. 运行 `swift tools/core/coordinate-test.swift` 查看转换链输出
2. 点击屏幕四个角，观察 CGEvent 坐标是否对应
3. 确认 DisplayManager 选中了正确的显示器（CLI：检查启动日志；GUI：Devices 标签页）

坐标转换流程：
```
硬件 (0-16383) → 归一化 (0-1, Y轴翻转) → AppKit 屏幕坐标 → CGEvent 坐标 (Y再翻转)
```

### 手势不响应

```bash
# 实时查看触摸事件，确认手指数量和坐标被正确接收
swift tools/core/debug-monitor.swift
```

常见原因：
- 4指手势：手指间距不足（默认 min 60px），或速度太慢（默认 min 100px/s）
- 捏合缩放：未启用（检查 `DriverConfig.pinch.enabled`）
- 滚动：两指分类为捏合（检查 TwoFingerDetector 的 parallel_score）

### 权限问题

```
错误: CGEventCreateMouseEvent 返回 nil
原因: 缺少辅助功能权限
修复: 系统设置 → 隐私与安全性 → 辅助功能 → 添加 MacinTouch / MacinTouchApp
```

```
错误: InitHIDNotifications 设备未打开
原因: 缺少输入监控权限（或 CLI 未用 sudo）
修复: 系统设置 → 隐私与安全性 → 输入监控；或 CLI 使用 sudo
```

## 故障排查清单

**设备问题**
- [ ] USB 连接正常
- [ ] VID: 0x222a, PID: 0x0001 匹配
- [ ] 输入监控权限已授予（CLI 用 sudo 跳过此项）

**坐标问题**
- [ ] DisplayManager 选中了正确的显示器
- [ ] Y轴翻转两次（归一化时 + CGEvent 转换时）
- [ ] 屏幕 origin 偏移已计入（多显示器场景可能有负坐标）

**事件模拟问题**
- [ ] 辅助功能权限已授予
- [ ] CGEvent source 可用

**手势问题**
- [ ] 对应手势在 DriverConfig 中已启用
- [ ] 参数阈值合理（可通过 GUI Gestures 标签页调整）
