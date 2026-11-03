#!/bin/bash

# MacinTouch 卸载脚本

set -e

SERVICE_NAME="com.ilitek.touchdriver"
PLIST_PATH="$HOME/Library/LaunchAgents/$SERVICE_NAME.plist"
BINARY_PATH="/usr/local/bin/MacinTouch"

echo "🗑️ MacinTouch 卸载脚本"
echo "=================================="

# 确认卸载
read -p "确定要卸载 MacinTouch 吗？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ 卸载已取消"
    exit 0
fi

echo ""
echo "🔧 开始卸载..."

# 停止服务
if [[ -f "$PLIST_PATH" ]]; then
    echo "   停止服务..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    echo "   ✅ 服务已停止并删除"
fi

# 删除二进制文件
if [[ -f "$BINARY_PATH" ]]; then
    echo "   删除驱动程序..."
    sudo rm -f "$BINARY_PATH"
    echo "   ✅ 驱动程序已删除"
fi

# 清理日志
echo "   清理日志文件..."
rm -f /tmp/ilitek-touchdriver.log
rm -f /tmp/ilitek-touchdriver.error.log
echo "   ✅ 日志已清理"

# 重置权限
echo "   重置辅助功能权限..."
tccutil reset Accessibility com.ilitek.touchdriver 2>/dev/null || true
echo "   ✅ 权限已重置"

echo ""
echo "✅ 卸载完成"
echo ""
echo "如需重新安装，请运行:"
echo "   make install        # CLI 驱动"
echo "   make gui-install    # GUI 应用"