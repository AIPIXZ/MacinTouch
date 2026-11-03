#!/usr/bin/swift

//
//  touch-test.swift  
//  MacinTouch 核心工具
//
//  基础触控功能测试工具 - 验证触控基本功能是否正常
//

import Foundation
import AppKit
import CoreGraphics

/// 触控功能测试器
class TouchFunctionTester {
    
    /// 执行完整的触控功能测试
    func runFullTest() {
        print("🎯 ILITEK 触控功能测试")
        print("=" * 50)
        
        testSystemInfo()
        testMouseCapabilities()
        testCoordinateSystem()
        testAccessibilityPermissions()
        
        print("\n🎮 手动测试指南")
        print("=" * 30)
        printManualTestGuide()
    }
    
    /// 测试系统信息
    private func testSystemInfo() {
        print("\n📱 系统信息检测")
        print("-" * 20)
        
        // 获取主屏幕信息
        guard let mainScreen = NSScreen.main else {
            print("❌ 无法获取主屏幕信息")
            return
        }
        
        let frame = mainScreen.frame
        let backingScaleFactor = mainScreen.backingScaleFactor
        
        print("✅ 主屏幕分辨率: \(Int(frame.width)) x \(Int(frame.height))")
        print("✅ 屏幕缩放因子: \(backingScaleFactor)x")
        print("✅ 实际像素分辨率: \(Int(frame.width * backingScaleFactor)) x \(Int(frame.height * backingScaleFactor))")
        
        // 多显示器检测
        let screenCount = NSScreen.screens.count
        print("✅ 显示器数量: \(screenCount)")
        
        if screenCount > 1 {
            print("💡 检测到多显示器环境，驱动将使用主显示器进行坐标映射")
        }
    }
    
    /// 测试鼠标功能
    private func testMouseCapabilities() {
        print("\n🖱️  鼠标功能测试")
        print("-" * 20)
        
        // 获取当前鼠标位置
        let currentLocation = NSEvent.mouseLocation
        print("✅ 当前鼠标位置: (\(Int(currentLocation.x)), \(Int(currentLocation.y)))")
        
        // 测试鼠标移动（模拟）
        let testPoint = CGPoint(x: currentLocation.x + 10, y: currentLocation.y + 10)
        print("✅ 测试坐标: (\(Int(testPoint.x)), \(Int(testPoint.y)))")
        print("💡 如果触控驱动工作正常，触摸应该能控制鼠标位置")
    }
    
    /// 测试坐标系统
    private func testCoordinateSystem() {
        print("\n📐 坐标系统测试")
        print("-" * 20)
        
        guard let mainScreen = NSScreen.main else { return }
        
        let screenFrame = mainScreen.frame
        let backingScaleFactor = mainScreen.backingScaleFactor
        
        // 计算关键坐标点
        let topLeft = CGPoint(x: 0, y: screenFrame.height)
        let topRight = CGPoint(x: screenFrame.width, y: screenFrame.height)
        let bottomLeft = CGPoint(x: 0, y: 0)
        let bottomRight = CGPoint(x: screenFrame.width, y: 0)
        let center = CGPoint(x: screenFrame.width / 2, y: screenFrame.height / 2)
        
        print("✅ 屏幕坐标系 (AppKit坐标系，左下角为原点):")
        print("   左上角: (\(Int(topLeft.x)), \(Int(topLeft.y)))")
        print("   右上角: (\(Int(topRight.x)), \(Int(topRight.y)))")
        print("   左下角: (\(Int(bottomLeft.x)), \(Int(bottomLeft.y)))")
        print("   右下角: (\(Int(bottomRight.x)), \(Int(bottomRight.y)))")
        print("   中心点: (\(Int(center.x)), \(Int(center.y)))")
        
        // 计算触摸坐标范围（基于配置）
        let touchResX = 16382.0  // 来自Config.swift
        let touchResY = 9598.0
        
        print("\n✅ 触摸坐标范围:")
        print("   X轴: 1 - \(Int(touchResX))")
        print("   Y轴: 1 - \(Int(touchResY))")
        
        // 计算缩放比例
        let scaleX = screenFrame.width / touchResX
        let scaleY = screenFrame.height / touchResY
        
        print("\n✅ 坐标缩放比例:")
        print("   X轴缩放: \(String(format: "%.4f", scaleX))")
        print("   Y轴缩放: \(String(format: "%.4f", scaleY))")
        
        if abs(scaleX - scaleY) > 0.01 {
            print("⚠️  X和Y轴缩放比例不一致，可能导致触摸变形")
        } else {
            print("✅ X和Y轴缩放比例一致，触摸映射正常")
        }
    }
    
    /// 测试辅助功能权限
    private func testAccessibilityPermissions() {
        print("\n🔐 权限状态检查")
        print("-" * 20)
        
        // 检查辅助功能权限
        let hasAccessibility = AXIsProcessTrusted()
        if hasAccessibility {
            print("✅ 辅助功能权限：已授权")
        } else {
            print("❌ 辅助功能权限：未授权")
            print("💡 请在系统偏好设置中授权辅助功能权限")
        }
        
        // 检查输入监控权限
        let inputAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        switch inputAccess {
        case kIOHIDAccessTypeGranted:
            print("✅ 输入监控权限：已授权")
        case kIOHIDAccessTypeDenied:
            print("❌ 输入监控权限：被拒绝")
        default:
            print("⚠️  输入监控权限：未确定")
        }
    }
    
    /// 显示手动测试指南
    private func printManualTestGuide() {
        print("请按以下步骤手动测试触控功能：")
        print("")
        print("1️⃣ 基础触控测试:")
        print("   • 用手指轻触屏幕，观察鼠标指针是否移动到触摸位置")
        print("   • 触摸屏幕不同区域，验证坐标映射是否准确")
        print("")
        print("2️⃣ 点击测试:")
        print("   • 短按触摸屏，验证是否触发鼠标左键点击")
        print("   • 长按触摸屏(0.6秒)，验证是否触发右键菜单")
        print("")
        print("3️⃣ 拖动测试:")
        print("   • 按住并拖动文件，验证拖拽功能")
        print("   • 在文本编辑器中拖动选择文本")
        print("")
        print("4️⃣ 双指滚动测试:")
        print("   • 用两个手指在屏幕上滑动，验证页面滚动")
        print("   • 测试惯性滚动：快速滑动后松手，页面应继续滚动")
        print("")
        print("5️⃣ 四指手势测试:")
        print("   • 四指横向滑动：切换桌面空间")
        print("   • 四指轻拍：打开Launchpad")
        print("")
        print("6️⃣ 双指缩放测试:")
        print("   • 两指张开：放大内容")
        print("   • 两指合拢：缩小内容")
        print("")
        print("🔧 故障排查:")
        print("   • 如果触控无响应：检查设备连接和权限")
        print("   • 如果坐标不准确：检查配置文件中的坐标范围")
        print("   • 如果手势失效：检查相关手势是否已启用")
        print("")
        print("📋 测试结果:")
        print("   请将测试结果记录下来，有助于后续调试和优化")
    }
}

// MARK: - 主程序
let tester = TouchFunctionTester()
tester.runFullTest()

print("\n" + "=" * 50)
print("✅ 触控功能测试完成")
print("💡 如有问题，请查看故障排查指南或联系开发者")
print("=" * 50)