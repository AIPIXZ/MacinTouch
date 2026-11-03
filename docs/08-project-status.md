# 项目状态

## 完成状态

### 驱动核心
- [x] HID 设备识别与连接（ILITEK-TP: 0x222a/0x0001）
- [x] 触摸事件解析与坐标映射
- [x] 单点/多点触控（最多10点）
- [x] 单指：点击、双击、右键（长按）、拖拽（双指滚动模式）
- [x] 单指：滚动、轻拍点击、长按拖拽、惯性滚动（单指滚动模式）
- [x] 双指单击右键（单指滚动模式，含顺序落下检测）
- [x] 双指滚动（带惯性加速）
- [x] 双指捏合缩放
- [x] 4指手势（滑动 + 轻拍）
- [x] 动态屏幕分辨率适配
- [x] 多显示器支持

### 架构重构（完成）
- [x] TouchHandler 拆分为 8 个独立手势模块（2308 → 298 行）
- [x] InputSimulator 精简（1009 → 287 行）
- [x] DriverConfig（Codable 运行时配置，替代编译期常量）
- [x] Logger（结构化日志，替代 30+ 个 DEBUG 布尔变量）
- [x] TouchDriverInterface 协议（driver/GUI 解耦契约）

### GUI 应用（完成）
- [x] SwiftUI 菜单栏应用
- [x] 设备状态实时监控
- [x] 图形化手势配置
- [x] 显示器选择
- [x] 权限引导
- [x] 配置持久化（与 CLI 驱动共享同一 JSON 文件）

## 快速开始

```bash
# GUI 方式（推荐）
make gui-debug && make gui-run-debug

# CLI 方式
make debug && sudo make run-debug

# 安装
sudo make install        # CLI → /usr/local/bin
make gui-install         # GUI → /Applications
```

## 已知限制

| 问题 | 说明 |
|------|------|
| 休眠唤醒后设备消失 | HID 连接断开，需重启驱动（GUI 有 Restart 按钮） |
| 多显示器热插拔 | DisplayManager 会自动刷新，但极少数情况需手动重启 |
| CLI 需要 sudo | IOKit HID 访问权限要求，GUI 已通过系统权限对话框解决 |

## 潜在改进方向

- [ ] 自定义手势映射（用户可定义4指手势触发的操作）
- [ ] LaunchAgent 自动启动（launchd plist）
- [ ] 触摸压力感应支持
- [ ] 更多 ILITEK 设备型号（不同 VID/PID）
- [ ] 手势录制与回放（测试辅助）
