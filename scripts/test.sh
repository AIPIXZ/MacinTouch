#!/bin/bash

# MacinTouch 综合测试脚本
# 整合了build、validate、touch测试功能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 显示帮助信息
show_help() {
    echo "MacinTouch 测试脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  build       - 测试项目构建"
    echo "  validate    - 验证项目完整性"
    echo "  touch       - 运行触摸测试"
    echo "  coordinate  - 运行坐标测试"
    echo "  all         - 运行所有测试"
    echo "  help        - 显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 build      # 只测试构建"
    echo "  $0 all        # 运行所有测试"
    echo "  sudo $0 touch # 以root权限运行触摸测试"
}

# 构建测试
test_build() {
    echo -e "${BLUE}🔨 构建测试${NC}"
    echo "=================================="
    
    # 检查必需文件
    echo "📁 检查项目文件..."
    required_files=(
        "MacinTouch/main.swift"
        "MacinTouch/Config.swift"
        "MacinTouch/Structs.swift"
        "MacinTouch/TouchHandler.swift"
        "MacinTouch/InputSimulator.swift"
        "MacinTouch/DisplayManager.swift"
        "MacinTouch/HIDSetup.h"
        "MacinTouch/HIDSetup.c"
        "Makefile"
    )
    
    missing=0
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "   ${RED}❌ 缺少: $file${NC}"
            missing=1
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        echo -e "   ${GREEN}✅ 所有必需文件都存在${NC}"
    else
        return 1
    fi
    
    # 检查构建工具
    echo ""
    echo "🔧 检查构建工具..."
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "   ${RED}❌ xcodebuild 未找到${NC}"
        echo "   💡 请安装: xcode-select --install"
        return 1
    fi
    echo -e "   ${GREEN}✅ 构建工具就绪${NC}"
    
    # 尝试构建
    echo ""
    echo "🔨 开始构建..."
    make clean > /dev/null 2>&1 || true
    
    if make debug > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ 构建成功${NC}"
        
        if [[ -f "build/Build/Products/Release/MacinTouch" ]] || [[ -f "build/Build/Products/Debug/MacinTouch" ]]; then
            echo -e "   ${GREEN}✅ 二进制文件生成成功${NC}"
            return 0
        fi
    fi
    
    echo -e "   ${RED}❌ 构建失败${NC}"
    return 1
}

# 项目验证
test_validate() {
    echo -e "${BLUE}🔍 项目验证${NC}"
    echo "=================================="
    
    total=0
    passed=0
    
    # 检查函数
    check() {
        local desc="$1"
        local cmd="$2"
        total=$((total + 1))
        echo -n "   $desc... "
        if eval "$cmd" > /dev/null 2>&1; then
            echo -e "${GREEN}✅${NC}"
            passed=$((passed + 1))
        else
            echo -e "${RED}❌${NC}"
        fi
    }
    
    # 系统检查
    echo "🖥️ 系统环境:"
    check "macOS系统" "[[ \$(uname) == 'Darwin' ]]"
    check "Swift编译器" "command -v swift"
    check "Make工具" "command -v make"
    
    # 工具检查
    echo ""
    echo "🛠️ 工具文件:"
    check "设备检测工具" "[[ -f 'tools/core/device-check-simple.swift' ]]"
    check "配置验证工具" "[[ -f 'tools/core/config-validate.swift' ]]"
    check "系统检查工具" "[[ -f 'tools/core/system-check.swift' ]]"
    
    # 文档检查
    echo ""
    echo "📚 文档:"
    check "README" "[[ -f 'README.md' ]]"
    check "文档目录" "[[ -d 'docs' ]]"
    
    # 结果
    echo ""
    echo "📊 结果: $passed/$total 通过"
    
    if [[ $passed -eq $total ]]; then
        echo -e "${GREEN}✅ 验证通过${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️ 部分检查未通过${NC}"
        return 1
    fi
}

# 触摸测试
test_touch() {
    echo -e "${BLUE}🎯 触摸测试${NC}"
    echo "=================================="
    
    # 检查权限
    if [[ $EUID -ne 0 ]]; then
        echo -e "${YELLOW}⚠️ 需要root权限运行触摸测试${NC}"
        echo "💡 请使用: sudo $0 touch"
        return 1
    fi
    
    # 检查驱动
    DRIVER=""
    if [[ -f "build/Build/Products/Release/MacinTouch" ]]; then
        DRIVER="build/Build/Products/Release/MacinTouch"
    elif [[ -f "build/Build/Products/Debug/MacinTouch" ]]; then
        DRIVER="build/Build/Products/Debug/MacinTouch"
    else
        echo -e "${RED}❌ 驱动程序未找到，请先构建${NC}"
        echo "💡 运行: $0 build"
        return 1
    fi
    
    echo "请选择测试模式:"
    echo "1) 快速测试 (10秒自动退出)"
    echo "2) 坐标监控测试"
    echo "3) 手势测试"
    echo "4) 交互式测试 (手动退出)"
    read -p "选择 (1-4): " choice
    
    case $choice in
        1)
            echo "🚀 启动10秒快速测试..."
            timeout 10s $DRIVER || true
            echo -e "${GREEN}✅ 测试完成${NC}"
            ;;
        2)
            echo "🚀 启动坐标监控..."
            echo "💡 在另一个终端运行: swift tools/core/coordinate-test.swift"
            echo "⌨️ 按 Ctrl+C 退出"
            $DRIVER
            ;;
        3)
            echo "🚀 启动手势测试..."
            echo "💡 测试4指手势、双指滚动等"
            echo "⌨️ 按 Ctrl+C 退出"
            $DRIVER
            ;;
        4)
            echo "🚀 启动交互式测试..."
            echo "⌨️ 按 Ctrl+C 退出"
            $DRIVER
            ;;
        *)
            echo -e "${RED}❌ 无效选择${NC}"
            return 1
            ;;
    esac
}

# 坐标测试
test_coordinate() {
    echo -e "${BLUE}📍 坐标测试${NC}"
    echo "=================================="
    
    if [[ ! -f "tools/core/coordinate-test.swift" ]]; then
        echo -e "${RED}❌ 坐标测试工具未找到${NC}"
        return 1
    fi
    
    echo "🚀 启动坐标监控工具..."
    echo "💡 请在另一个终端运行驱动程序"
    echo "⌨️ 按 Ctrl+C 退出"
    swift tools/core/coordinate-test.swift
}

# 运行所有测试
test_all() {
    echo -e "${BLUE}🧪 运行所有测试${NC}"
    echo "=================================="
    echo ""
    
    # 构建测试
    test_build || true
    echo ""
    
    # 项目验证
    test_validate || true
    echo ""
    
    # 设备检测
    echo -e "${BLUE}📱 设备检测${NC}"
    echo "=================================="
    if [[ -f "tools/core/device-check-simple.swift" ]]; then
        swift tools/core/device-check-simple.swift || true
    fi
    echo ""
    
    # 总结
    echo -e "${BLUE}📊 测试完成${NC}"
    echo "=================================="
    echo "✅ 基础测试已完成"
    echo "💡 触摸测试需要root权限和连接的设备"
    echo "💡 运行: sudo $0 touch"
}

# 主程序
case "${1:-help}" in
    build)
        test_build
        ;;
    validate)
        test_validate
        ;;
    touch)
        test_touch
        ;;
    coordinate)
        test_coordinate
        ;;
    all)
        test_all
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ 未知选项: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac