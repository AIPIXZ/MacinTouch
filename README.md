# MacinTouch for macOS

[English](README_EN.md) | 中文

macOS 触摸屏驱动程序，支持 ILITEK-TP 设备，将 HID 硬件输入桥接为 macOS 鼠标事件，支持多点触控手势。包含命令行驱动和 SwiftUI 菜单栏 GUI 两种使用方式。

## 设备支持

| 参数 | 值 |
|------|-----|
| 设备型号 | ILITEK-TP |
| 厂商 ID | 0x222a |
| 产品 ID | 0x0001 |
| 接口 | USB HID |

## 功能特性

驱动支持两种触摸模式，可按需切换：

### 双指滚动模式（默认）

- **单/双击** - 标准鼠标操作
- **长按右键** - 0.6秒长按触发右键菜单
- **单指拖拽** - 按住后移动进行拖拽/文字选择
- **双指滚动** - 自然滚动方向，支持惯性加速
- **双指捏合缩放** - 两指捏合/展开控制缩放

### 单指滚动模式（`--single-finger`）

- **单指滚动** - 直接滑动滚动页面，带惯性，光标自动对齐手指位置
- **轻拍** - 单击；快速连拍 → 双击
- **长按（0.6s）** - 进入拖拽模式，用于文字选择
- **双指单击** - 右键菜单，光标不移动

### 通用

- **4指手势**
  - 上滑 → Mission Control（Control + ↑）
  - 下滑 → App Exposé（Control + ↓）
  - 左滑 → 切换到右侧桌面（Control + →）
  - 右滑 → 切换到左侧桌面（Control + ←）
  - 轻拍 → Launchpad
- **macOS 27 原生四指手势**
  - 左右平移 → 跟手切换桌面
  - 向上轻扫 → 跟手打开调度中心；向下轻扫 → 跟手打开 App Exposé
  - 拇指和其他三或四指捏拢 → Apps（聚焦中的应用视图）
  - 拇指和其他三或四指张开 → 显示桌面
  - 捏合与平移互斥识别；GUI 可关闭捏合并调整灵敏度
  - 新增捏合路径仍待实机验收，详见 [原生手势实验](tools/experimental/README.md)
- **菜单栏 GUI** - 图形界面配置，无需命令行

## 系统要求

- macOS 13.0+
- Apple Silicon 或 Intel
- 辅助功能权限（用于事件模拟）
- 输入监控权限（用于 HID 设备访问）

## 快速开始

### 方式一：GUI 应用（推荐）

```bash
# 编译 GUI 应用
make gui-debug

# 运行（或直接打开 build/MacinTouchApp.app）
make gui-run-debug
```

GUI 会自动引导权限设置，无需 `sudo`。

### 方式二：命令行驱动

```bash
# 编译
make debug

# 运行（双指滚动模式，需要 sudo 访问 HID 设备）
sudo make run-debug

# 运行（单指滚动模式）
sudo make run-debug-sf

# 安装到系统
sudo make install
```

### 方式三：打包 dmg
构建 GUI 发布版并打包为可分发的 DMG 文件。

```bash
make dmg
# 或直接运行
bash scripts/create-dmg.sh
```

**流程**：
1. `make gui`（Release 编译 + 代码签名）
2. 创建含 Applications 快捷方式的暂存目录
3. 设置 DMG 卷图标
4. 压缩输出为 `build/MacinTouch-1.0.0.dmg`

**安装方式**：
1. 双击 DMG
2. 拖动应用到 Applications
3. 从 Launchpad 或 Applications 启动

## 编译命令

```bash
# CLI 驱动
make debug          # 调试版
make release        # 发布版
make clean          # 清理构建产物

# GUI 应用
make gui-debug      # 调试版
make gui            # 发布版
make gui-install    # 安装到 /Applications

# 系统检查
make check-all                          # 全部检查
swift tools/core/device-check-simple.swift  # 检查设备连接
```

## 手势说明

### 双指滚动模式（默认）

| 操作 | 效果 |
|------|------|
| 单指点击 | 左键单击 |
| 单指双击 | 左键双击 |
| 单指长按（0.6s）| 右键菜单 |
| 单指拖动 | 鼠标拖拽 |
| 双指上下滑动 | 页面滚动（带惯性） |
| 双指左右滑动 | 横向滚动 |
| 双指捏合/展开 | 缩放（Cmd+滚轮） |

### 单指滚动模式（`--single-finger`）

| 操作 | 效果 |
|------|------|
| 单指滑动 | 页面滚动（带惯性） |
| 单指轻拍 | 左键单击 |
| 单指连拍 | 左键双击 |
| 单指长按（0.6s）| 拖拽模式（文字选择） |
| 双指单击 | 右键菜单（光标不移动） |

### 4指手势（两种模式通用）

| 操作 | 效果 |
|------|------|
| 4指上滑 | Mission Control |
| 4指下滑 | App Exposé |
| 4指左滑 | 切换到右侧桌面 |
| 4指右滑 | 切换到左侧桌面 |
| 4指轻拍 | Launchpad |

## 架构概览

```
HIDSetup.c ──→ TouchHandler.swift ──→ Gestures/ ──→ InputSimulator.swift
                                            ↕
                                    DisplayManager.swift
                                            ↕
                                      DriverConfig.swift
```

- `MacinTouch/` — 驱动核心（CLI + GUI 共用）
- `MacinTouch/Gestures/` — 手势识别模块（8个独立文件）
- `MacinTouchApp/` — SwiftUI 菜单栏应用
- 详见 [docs/02-technical-architecture.md](docs/02-technical-architecture.md)

## 调试工具

```bash
swift tools/core/device-check-simple.swift  # 检查设备连接
swift tools/core/config-validate.swift      # 验证配置
swift tools/core/system-check.swift         # 系统兼容性检查
swift tools/core/debug-monitor.swift        # 实时监控触摸事件
swift tools/core/gesture-test.swift         # 测试手势识别
swift tools/core/coordinate-test.swift      # 坐标映射测试
```

## 文档

| 文档 | 说明 |
|------|------|
| [技术架构](docs/02-technical-architecture.md) | 完整架构说明和模块详解 |
| [坐标系统](docs/03-coordinate-system.md) | 坐标转换原理 |
| [手势指南](docs/09-gesture-guide.md) | 手势识别详细说明 |
| [调试指南](docs/05-debugging-guide.md) | 调试方法和工具 |
| [GUI 应用](docs/11-gui-application.md) | GUI 应用使用说明 |
| [部署指南](docs/10-deployment-guide.md) | 安装和分发 |

## 许可证

MIT License
