# MacinTouch 项目概述

## 项目简介

MacinTouch 是专为 macOS 开发的 ILITEK 触摸屏驱动程序，将 USB HID 触摸输入转换为 macOS 鼠标事件，支持完整的多点触控手势。包含命令行驱动（CLI）和菜单栏 GUI 配置应用两种使用方式。

## 设备支持

- **设备型号**: ILITEK-TP
- **厂商 ID**: 0x222a
- **产品 ID**: 0x0001
- **接口**: USB HID

## 功能特性

### 双指滚动模式（默认）
- 单指点击、双击、拖拽
- 长按右键（0.6s，可配置）
- 双指滚动（带惯性加速）
- 双指捏合缩放
- 4指手势（Mission Control、App Exposé、桌面切换、Launchpad）

### 单指滚动模式（`--single-finger`）
- 单指滚动（主要用途）：带惯性，光标自动跳转到手指位置
- 单指轻拍/双击
- 长按进入拖拽模式（文字选择）
- 双指单击右键（光标不移动）
- 4指手势同双指滚动模式

### 通用
- 菜单栏 GUI（图形化配置，无需 sudo）
- 配置持久化（CLI/GUI 共享同一 JSON 文件）

## 架构总览

```
HIDSetup.c           ← IOKit HID 底层（C 语言）
    ↓
TouchHandler.swift   ← 触摸事件协调器（298 行）
    ↓
Gestures/            ← 8个独立手势识别模块
    ├── GestureRecognizer.swift         协议 + 共享上下文
    ├── GestureStateMachine.swift       状态机（idle/单指/多指）
    ├── SingleTouchGesture.swift        点击/双击/右键/拖拽（双指滚动模式）
    ├── SingleFingerScrollGesture.swift 单指滚动/点击/长按拖拽（单指滚动模式）
    ├── TwoFingerDetector.swift         滚动/捏合分类器
    ├── ScrollGesture.swift             双指滚动 + 惯性
    ├── PinchGesture.swift              捏合缩放
    └── FourFingerGesture.swift         4指手势
    ↓
InputSimulator.swift  ← CGEvent 生成（287 行）
    ↑
DisplayManager.swift  ← 坐标系统转换（单例）
    ↑
DriverConfig.swift    ← 运行时配置（Codable，CLI/GUI 共用）
```

## 开发环境

- **语言**: Swift 5 + C
- **系统要求**: macOS 13.0+
- **架构**: Apple Silicon (ARM64)
- **构建工具**: Xcode 15 + Makefile

## 文档导航

| 文档 | 内容 |
|------|------|
| [技术架构](02-technical-architecture.md) | 完整模块设计和数据流 |
| [坐标系统](03-coordinate-system.md) | 坐标转换原理 |
| [常见问题](04-common-pitfalls.md) | 历史踩坑记录 |
| [调试指南](05-debugging-guide.md) | 调试工具和方法 |
| [手势指南](09-gesture-guide.md) | 手势参数详解 |
| [GUI 应用](11-gui-application.md) | GUI 使用说明 |
| [部署指南](10-deployment-guide.md) | 安装和分发 |
