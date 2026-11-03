# Contributing to MacinTouch

## 开始之前

1. **确认环境**

   ```bash
   make check-all
   ```

   需要：macOS 13+、Xcode 命令行工具、ILITEK 触摸屏设备（用于手动测试）

2. **Fork & Clone**

   ```bash
   git clone https://github.com/<your-fork>/ilitek-touch-driver.git
   cd ilitek-touch-driver
   ```

## 开发流程

### 构建

```bash
make gui-debug       # GUI（推荐开发时使用）
make debug           # CLI 驱动
```

### 测试

目前没有自动化单元测试，验证方式：

```bash
# 构建验证
make debug
make gui-debug

# 设备和系统检查
swift tools/core/device-check-simple.swift
swift tools/core/system-check.swift

# 手势功能验证（需要物理设备）
sudo make run-debug
```

### 提交规范

- 每次提交只做一件事
- commit message 使用中文或英文均可，说明"做了什么"和"为什么"
- 修复 bug 请在 message 中注明复现条件

### Pull Request

1. 基于 `main` 创建新分支：`git checkout -b feat/your-feature`
2. 确保 `make debug` 和 `make gui-debug` 都能编译通过
3. 在物理设备上验证手势功能（如果改动涉及手势识别）
4. 提交 PR 时说明：改动内容、测试方法、已知限制

## 项目结构

```
MacinTouch/           驱动核心（CLI + GUI 共用）
MacinTouch/Gestures/  手势识别模块（每个手势一个文件）
MacinTouchApp/        SwiftUI 菜单栏应用
tools/core/            诊断和测试工具
docs/                  技术文档
scripts/               构建和分发脚本
```

详见 [docs/02-technical-architecture.md](docs/02-technical-architecture.md)

## 常见贡献方向

- **新设备支持**：适配不同 VID/PID 的 ILITEK 设备，修改 `DriverConfig.DeviceConfig`
- **手势优化**：改进识别准确性，在 `MacinTouch/Gestures/` 对应文件中修改
- **Bug 修复**：复现步骤 + 修复 + 说明根本原因
- **文档改进**：发现文档与实际行为不符，直接提 PR 修正

## 报告问题

提 Issue 时请包含：
- macOS 版本
- `make check-all` 输出
- 复现步骤
- 期望行为 vs 实际行为
