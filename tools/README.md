# MacinTouch 工具集

本目录包含 ILITEK 触摸屏驱动程序的诊断、测试和调试工具。

## 📁 目录结构

```
tools/
├── core/           # 核心工具 - 日常使用和基础测试（8个）
├── dev/            # 开发工具 - 高级调试和开发辅助（预留）
└── README.md       # 本说明文档
```

## 🔧 核心工具 (tools/core/)

### 1. 设备检测工具
```bash
./core/device-check.swift
```
- **功能**: 检测 ILITEK 设备连接状态
- **检查内容**: 设备连接、HID权限、辅助功能权限
- **使用场景**: 驱动无法启动时的首要诊断工具

### 2. 系统检查工具
```bash
./core/system-check.swift
```
- **功能**: 全面的系统兼容性检查
- **检查内容**: 系统版本、权限状态、开发环境、系统框架
- **使用场景**: 安装后的兼容性验证

### 3. 配置验证工具
```bash
./core/config-validate.swift
```
- **功能**: 验证驱动配置参数的正确性
- **检查内容**: 坐标范围、缩放比例、配置建议
- **使用场景**: 触摸映射不准确时的配置诊断

### 4. 触控功能测试工具
```bash
./core/touch-test.swift
```
- **功能**: 基础触控功能测试指南
- **测试内容**: 坐标映射、权限状态、手动测试步骤
- **使用场景**: 验证基本触控功能是否正常

### 5. 手势测试工具
```bash
./core/gesture-test.swift
```
- **功能**: 全面的手势功能测试指南
- **测试内容**: 右键、滚动、四指手势、缩放手势
- **使用场景**: 验证各种触控手势是否正常工作

### 6. 坐标测试工具
```bash
./core/coordinate-test.swift
```
- **功能**: 详细的坐标映射分析
- **测试内容**: 屏幕信息、坐标转换、宽高比分析
- **使用场景**: 触摸位置不准确时的深度诊断

### 7. 调试监控工具
```bash
./core/debug-monitor.swift
```
- **功能**: 实时监控驱动状态和事件
- **监控内容**: 系统状态、事件频率、手势识别
- **使用场景**: 实时调试和性能监控

## 🚀 使用流程

### 新安装验证流程
```bash
# 1. 系统兼容性检查
./core/system-check.swift

# 2. 设备连接检查  
./core/device-check.swift

# 3. 配置验证
./core/config-validate.swift

# 4. 基础功能测试
./core/touch-test.swift
```

### 问题诊断流程
```bash
# 如果触摸无响应
./core/device-check.swift    # 检查设备和权限
./core/system-check.swift    # 检查系统状态

# 如果触摸位置不准确
./core/coordinate-test.swift  # 分析坐标映射
./core/config-validate.swift # 验证配置参数

# 如果手势失效
./core/gesture-test.swift    # 手势功能测试
```

### 开发调试流程
```bash
# 实时监控（后台运行）
./core/debug-monitor.swift &

# 功能测试
./core/touch-test.swift
./core/gesture-test.swift
```

## 💡 使用技巧

### 权限要求
- **系统检查工具**: 无需特殊权限
- **设备检测工具**: 需要输入监控权限
- **调试监控工具**: 需要辅助功能权限

### 输出重定向
```bash
# 保存检测结果到文件
./core/device-check.swift > device-status.log 2>&1

# 保存配置分析到文件
./core/config-validate.swift > config-analysis.log
```

### 批量测试
```bash
# 创建测试脚本
cat > quick-test.sh << 'EOF'
#!/bin/bash
echo "=== ILITEK 驱动快速测试 ==="
./tools/core/device-check.swift
./tools/core/config-validate.swift
echo "=== 测试完成 ==="
EOF

chmod +x quick-test.sh
./quick-test.sh
```

## 🛠️ 开发工具 (tools/dev/)

开发工具目录预留给高级调试工具，目前为空。
计划添加的工具：
- HID 原始数据监控工具
- 性能基准测试工具
- 坐标校准工具
- 配置文件生成器

## 🆘 故障排查

### 常见问题

**1. 工具无法执行**
```bash
# 检查权限
ls -la tools/core/device-check.swift
# 如果没有执行权限，添加权限
chmod +x tools/core/device-check.swift
```

**2. Swift 编译错误**
```bash
# 检查 Swift 环境
which swift
swift --version

# 如果 Swift 不可用，安装 Xcode 命令行工具
xcode-select --install
```

**3. 权限不足错误**
- 前往 系统偏好设置 > 安全性与隐私 > 隐私
- 添加终端应用到 "辅助功能" 和 "输入监控"

### 调试技巧

**1. 详细错误信息**
```bash
# 使用 swift 直接运行以获取详细错误
swift tools/core/device-check.swift
```

**2. 分步执行**
```bash
# 逐步执行工具，定位问题环节
./core/system-check.swift && ./core/device-check.swift
```

**3. 日志收集**
```bash
# 收集完整诊断信息
./core/system-check.swift > diagnostic.log 2>&1
./core/device-check.swift >> diagnostic.log 2>&1
./core/config-validate.swift >> diagnostic.log 2>&1
```

## 📚 相关文档

- [驱动安装指南](../README.md)
- [开发文档](../docs/README.md)
- [故障排查指南](../docs/05-debugging-guide.md)
- [配置参考](../MacinTouch/DriverConfig.swift)

## 🔄 更新记录

- **v1.0.0**: 8个核心工具，覆盖设备检测、系统兼容、坐标诊断、手势测试全流程

---

💡 **提示**: 如果工具无法解决您的问题，请查看主项目的 [故障排查指南](../docs/05-debugging-guide.md) 或提交 Issue。