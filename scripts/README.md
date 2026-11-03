# 脚本使用指南

```
scripts/
├── create-icon.sh   # 从源图生成 AppIcon.icns
├── create-dmg.sh    # 构建 GUI 并打包为 DMG
├── uninstall.sh     # 卸载驱动和 GUI
├── test.sh          # 综合测试（构建 / 验证 / 手势 / 坐标）
└── README.md
```

---

## create-icon.sh — 图标生成

从源图生成完整的 `AppIcon.icns`（10个尺寸）。

```bash
# 使用项目根目录的 icon-1024.png（默认）
bash scripts/create-icon.sh

# 指定任意源图
bash scripts/create-icon.sh path/to/image.png
```

**源图要求**：PNG 格式，建议 1024×1024 或更大，非正方形会自动用背景色填充为方形。

**输出**：`MacinTouchApp/Resources/AppIcon.icns`

> 打包时不会自动重新生成，换图后需手动运行此脚本再执行 `make dmg`。

---

## create-dmg.sh — DMG 打包

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

---

## uninstall.sh — 卸载

完全卸载驱动及 GUI 应用。

```bash
bash scripts/uninstall.sh
```

**卸载内容**：
- `/usr/local/bin/MacinTouch`（CLI 驱动）
- `/Applications/MacinTouchApp.app`（GUI 应用）
- `~/Library/Application Support/MacinTouch/`（配置文件）
- LaunchAgent（如已安装）

---

## test.sh — 综合测试

```bash
./scripts/test.sh help       # 显示帮助
./scripts/test.sh build      # 构建验证
./scripts/test.sh validate   # 系统环境和项目完整性检查
./scripts/test.sh coordinate # 坐标映射分析
sudo ./scripts/test.sh touch # 触摸功能测试（需要 sudo）
./scripts/test.sh all        # 运行所有非交互式测试
```

---

## 常用工作流

### 首次使用
```bash
make check-all                              # 系统兼容性检查
make gui-debug && make gui-run-debug        # 编译并运行 GUI
```

### 换图标后重新打包
```bash
# 把新图放到项目根目录并命名为 icon-1024.png
bash scripts/create-icon.sh
make dmg
```

### 问题排查
```bash
swift tools/core/device-check-simple.swift  # 检查设备连接
swift tools/core/system-check.swift         # 系统状态
swift tools/core/config-validate.swift      # 配置验证
sudo make run-debug                         # 运行并查看调试输出
```
