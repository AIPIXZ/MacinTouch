# 部署与打包指南

## 编译构建

### Makefile 命令

```bash
# 编译调试版本
make debug

# 编译发布版本
make release

# 清理构建文件
make clean

# 运行调试版本（双指滚动模式）
sudo make run-debug

# 运行调试版本（单指滚动模式）
sudo make run-debug-sf

# 运行发布版本
sudo make run

# 安装到系统
sudo make install
```

### Xcode 构建

```bash
# Debug 配置
xcodebuild -project MacinTouch.xcodeproj -scheme MacinTouch -configuration Debug

# Release 配置
xcodebuild -project MacinTouch.xcodeproj -scheme MacinTouch -configuration Release
```

## 系统安装

### 手动安装

1. **编译驱动**
```bash
make release
```

2. **复制到系统目录**
```bash
sudo cp build/Release/MacinTouch /usr/local/bin/macintouch
sudo chmod +x /usr/local/bin/macintouch
```

3. **设置权限**
- 打开系统偏好设置 → 安全性与隐私 → 辅助功能
- 添加 ilitek-driver 并启用权限

### 自动启动配置

创建 LaunchAgent 配置文件：

```bash
# 创建 plist 文件
cat > ~/Library/LaunchAgents/com.ilitek.touchdriver.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ilitek.touchdriver</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/macintouch</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/ilitek-driver.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ilitek-driver.error.log</string>
</dict>
</plist>
EOF

# 加载服务
launchctl load ~/Library/LaunchAgents/com.ilitek.touchdriver.plist
```

## 权限管理

### 必需权限

1. **辅助功能权限**
   - 用于模拟鼠标和键盘事件
   - 系统偏好设置中手动授权

2. **HID设备访问权限**
   - 需要root权限访问USB HID设备
   - 使用sudo运行或配置适当的权限

### 权限配置脚本

```bash
#!/bin/bash
# setup-permissions.sh

# 检查辅助功能权限
osascript -e 'tell application "System Preferences"
    reveal anchor "Privacy_Accessibility" of pane id "com.apple.preference.security"
end tell'

echo "请在系统偏好设置中添加 MacinTouch 到辅助功能"
echo "路径: /usr/local/bin/macintouch"
```

## 故障排查

### 常见问题

1. **设备未识别**
```bash
# 检查USB设备
system_profiler SPUSBDataType | grep ILITEK

# 使用调试工具
swift tools/core/device-check-simple.swift
```

2. **权限错误**
```bash
# 检查权限状态
sudo dmesg | grep MacinTouch

# 重置权限
tccutil reset Accessibility com.ilitek.touchdriver
```

3. **启动失败**
```bash
# 查看日志
tail -f /tmp/ilitek-driver.log
tail -f /tmp/ilitek-driver.error.log

# 手动测试
sudo /usr/local/bin/macintouch
```

## 卸载指南

### 完全卸载

```bash
#!/bin/bash
# uninstall.sh

# 停止服务
launchctl unload ~/Library/LaunchAgents/com.ilitek.touchdriver.plist

# 删除文件
sudo rm -f /usr/local/bin/macintouch
rm -f ~/Library/LaunchAgents/com.ilitek.touchdriver.plist

# 清理权限
tccutil reset Accessibility com.ilitek.touchdriver

echo "卸载完成"
```

## 分发准备

### 创建安装包

1. **准备文件结构**
```
ilitek-touch-driver-installer/
├── MacinTouch         # 编译好的驱动
├── install.sh         # 安装脚本
├── uninstall.sh       # 卸载脚本
├── README.md          # 使用说明
└── tools/             # 调试工具
    └── core/          # 核心工具集
```

2. **创建安装脚本**
```bash
#!/bin/bash
# install.sh

echo "MacinTouch 安装程序"
echo "=============================="

# 检查权限
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 sudo 运行此安装程序"
    exit 1
fi

# 复制文件
cp MacinTouch /usr/local/bin/macintouch
chmod +x /usr/local/bin/macintouch

# 创建 LaunchAgent
cp com.ilitek.touchdriver.plist ~/Library/LaunchAgents/

echo "安装完成！"
echo "请在系统偏好设置中授予辅助功能权限"
```

3. **创建压缩包**
```bash
tar -czf ilitek-touch-driver-v1.0.tar.gz ilitek-touch-driver-installer/
```

## 版本管理

### 版本号规范
- 格式：`major.minor.patch`
- 示例：`1.0.0`

### 更新检查
可以在驱动中添加版本检查功能：

```swift
let currentVersion = "1.0.0"
let updateURL = "https://github.com/your-repo/releases"
```

## GUI 应用部署

### 编译安装

```bash
# 编译
make gui

# 安装到 /Applications
make gui-install
# 等同于：sudo cp -R build/MacinTouchApp.app /Applications/
```

### 开机自启（GUI 方式）

GUI 应用的 Startup 标签页提供开机自启开关，无需手动创建 LaunchAgent plist。

### GUI 权限

GUI 应用首次启动时会自动弹出辅助功能权限请求。输入监控权限在 Permissions 标签页显示状态，如未授权可在系统设置中手动添加。

GUI 不需要 `sudo`。

### 卸载 GUI

```bash
sudo rm -rf /Applications/MacinTouchApp.app
# 可选：清理配置
rm -rf ~/Library/Application\ Support/MacinTouch/
```
