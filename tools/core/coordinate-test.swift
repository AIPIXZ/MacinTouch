#!/usr/bin/swift

//
//  coordinate-test.swift
//  MacinTouch 核心工具
//
//  坐标映射测试工具 - 验证触摸坐标到屏幕坐标的映射是否准确
//

import Foundation
import AppKit
import CoreGraphics

/// 坐标映射测试器
class CoordinateMappingTester {
    
    // 触摸坐标范围（来自Config.swift）
    private let TOUCH_RESX = 16382.0
    private let TOUCH_RESY = 9598.0
    
    /// 执行完整的坐标测试
    func runCoordinateTests() {
        print("📐 ILITEK 坐标映射测试")
        print("=" * 50)
        
        testScreenInfo()
        testCoordinateMapping()
        testCornerPoints()
        testAspectRatio()
        testMouseLocationMapping()
        
        print("\n📋 坐标测试总结")
        print("=" * 30)
        printCoordinateTestSummary()
    }
    
    /// 测试屏幕信息
    private func testScreenInfo() {
        print("\n🖥️  屏幕信息检测")
        print("-" * 20)
        
        guard let mainScreen = NSScreen.main else {
            print("❌ 无法获取主屏幕信息")
            return
        }
        
        let frame = mainScreen.frame
        let backingScaleFactor = mainScreen.backingScaleFactor
        let visibleFrame = mainScreen.visibleFrame
        
        print("✅ 屏幕基本信息:")
        print("   • 逻辑分辨率: \(Int(frame.width)) x \(Int(frame.height))")
        print("   • 物理分辨率: \(Int(frame.width * backingScaleFactor)) x \(Int(frame.height * backingScaleFactor))")
        print("   • 缩放因子: \(backingScaleFactor)x")
        print("   • 可用区域: \(Int(visibleFrame.width)) x \(Int(visibleFrame.height))")
        
        // 检查多显示器
        let screenCount = NSScreen.screens.count
        print("   • 显示器数量: \(screenCount)")
        
        if screenCount > 1 {
            print("\n📺 多显示器配置:")
            for (index, screen) in NSScreen.screens.enumerated() {
                let screenFrame = screen.frame
                let deviceDescription = screen.deviceDescription
                print("   显示器 \(index + 1): \(Int(screenFrame.width))x\(Int(screenFrame.height)) at (\(Int(screenFrame.origin.x)), \(Int(screenFrame.origin.y)))")
                
                if let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                    print("     Display ID: \(screenNumber)")
                }
            }
        }
    }
    
    /// 测试坐标映射
    private func testCoordinateMapping() {
        print("\n🎯 坐标映射计算")
        print("-" * 20)
        
        guard let mainScreen = NSScreen.main else { return }
        
        let screenFrame = mainScreen.frame
        
        print("✅ 坐标系统对比:")
        print("   • 触摸坐标范围: 1-\(Int(TOUCH_RESX)) x 1-\(Int(TOUCH_RESY))")
        print("   • 屏幕坐标范围: 0-\(Int(screenFrame.width)) x 0-\(Int(screenFrame.height))")
        
        // 计算缩放比例
        let scaleX = screenFrame.width / TOUCH_RESX
        let scaleY = screenFrame.height / TOUCH_RESY
        
        print("\n✅ 缩放比例:")
        print("   • X轴缩放: \(String(format: "%.6f", scaleX))")
        print("   • Y轴缩放: \(String(format: "%.6f", scaleY))")
        
        // 检查比例一致性
        let scaleDifference = abs(scaleX - scaleY)
        let scaleRatio = scaleX / scaleY
        
        print("\n📊 比例分析:")
        print("   • 缩放差异: \(String(format: "%.6f", scaleDifference))")
        print("   • 缩放比率: \(String(format: "%.6f", scaleRatio))")
        
        if scaleDifference < 0.001 {
            print("   ✅ 缩放比例完美匹配，不会产生变形")
        } else if scaleDifference < 0.01 {
            print("   ⚠️  缩放比例略有差异，可能有轻微变形")
        } else {
            print("   ❌ 缩放比例差异较大，会产生明显变形")
            print("   💡 建议调整TOUCH_RESX或TOUCH_RESY以匹配屏幕比例")
        }
    }
    
    /// 测试角点坐标
    private func testCornerPoints() {
        print("\n🔄 角点坐标映射测试")
        print("-" * 20)
        
        guard let mainScreen = NSScreen.main else { return }
        
        let screenFrame = mainScreen.frame
        
        // 定义测试点（触摸坐标）
        let testPoints = [
            ("左上角", 1.0, TOUCH_RESY),
            ("右上角", TOUCH_RESX, TOUCH_RESY),
            ("左下角", 1.0, 1.0),
            ("右下角", TOUCH_RESX, 1.0),
            ("中心点", TOUCH_RESX/2, TOUCH_RESY/2)
        ]
        
        print("✅ 关键点坐标映射:")
        
        for (name, touchX, touchY) in testPoints {
            // 模拟坐标转换逻辑
            let screenX = (touchX - 1) / (TOUCH_RESX - 1) * screenFrame.width
            let screenY = (touchY - 1) / (TOUCH_RESY - 1) * screenFrame.height
            
            // AppKit坐标系（左下角为原点）
            let appKitY = screenFrame.height - screenY
            
            print("   • \(name):")
            print("     触摸坐标: (\(Int(touchX)), \(Int(touchY)))")
            print("     屏幕坐标: (\(Int(screenX)), \(Int(screenY)))")
            print("     AppKit坐标: (\(Int(screenX)), \(Int(appKitY)))")
        }
    }
    
    /// 测试宽高比
    private func testAspectRatio() {
        print("\n📏 宽高比分析")
        print("-" * 20)
        
        guard let mainScreen = NSScreen.main else { return }
        
        let screenFrame = mainScreen.frame
        
        // 计算宽高比
        let screenAspectRatio = screenFrame.width / screenFrame.height
        let touchAspectRatio = TOUCH_RESX / TOUCH_RESY
        
        print("✅ 宽高比对比:")
        print("   • 屏幕宽高比: \(String(format: "%.4f", screenAspectRatio)) (\(Int(screenFrame.width)):\(Int(screenFrame.height)))")
        print("   • 触摸宽高比: \(String(format: "%.4f", touchAspectRatio)) (\(Int(TOUCH_RESX)):\(Int(TOUCH_RESY)))")
        
        let aspectRatioDifference = abs(screenAspectRatio - touchAspectRatio)
        let aspectRatioRatio = screenAspectRatio / touchAspectRatio
        
        print("\n📊 宽高比分析:")
        print("   • 差异值: \(String(format: "%.4f", aspectRatioDifference))")
        print("   • 比率: \(String(format: "%.4f", aspectRatioRatio))")
        
        if aspectRatioDifference < 0.01 {
            print("   ✅ 宽高比匹配良好，触摸映射准确")
        } else if aspectRatioDifference < 0.1 {
            print("   ⚠️  宽高比略有差异，可能有轻微拉伸")
        } else {
            print("   ❌ 宽高比差异较大，会产生明显拉伸变形")
        }
        
        // 建议优化配置
        if aspectRatioDifference > 0.01 {
            let suggestedTouchResX = TOUCH_RESY * screenAspectRatio
            let suggestedTouchResY = TOUCH_RESX / screenAspectRatio
            
            print("\n💡 建议的配置优化:")
            print("   方案1: TOUCH_RESX = \(String(format: "%.0f", suggestedTouchResX))")
            print("   方案2: TOUCH_RESY = \(String(format: "%.0f", suggestedTouchResY))")
        }
    }
    
    /// 测试鼠标位置映射
    private func testMouseLocationMapping() {
        print("\n🖱️  当前鼠标位置分析")
        print("-" * 20)
        
        let mouseLocation = NSEvent.mouseLocation
        
        guard let mainScreen = NSScreen.main else { return }
        
        let screenFrame = mainScreen.frame
        
        print("✅ 当前鼠标位置:")
        print("   • AppKit坐标: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y)))")
        
        // 转换为屏幕坐标（左上角为原点）
        let screenY = screenFrame.height - mouseLocation.y
        print("   • 屏幕坐标: (\(Int(mouseLocation.x)), \(Int(screenY)))")
        
        // 计算对应的触摸坐标
        let normalizedX = mouseLocation.x / screenFrame.width
        let normalizedY = screenY / screenFrame.height
        
        let touchX = 1 + normalizedX * (TOUCH_RESX - 1)
        let touchY = 1 + normalizedY * (TOUCH_RESY - 1)
        
        print("   • 对应触摸坐标: (\(Int(touchX)), \(Int(touchY)))")
        
        // 计算相对位置
        let relativeX = (mouseLocation.x / screenFrame.width) * 100
        let relativeY = (screenY / screenFrame.height) * 100
        
        print("   • 相对位置: (\(String(format: "%.1f", relativeX))%, \(String(format: "%.1f", relativeY))%)")
    }
    
    /// 显示测试总结
    private func printCoordinateTestSummary() {
        print("请根据以上分析检查坐标映射是否正确")
        print("")
        print("🔧 手动验证步骤:")
        print("   1. 触摸屏幕左上角，鼠标指针应移动到屏幕左上角")
        print("   2. 触摸屏幕右下角，鼠标指针应移动到屏幕右下角")
        print("   3. 触摸屏幕中心，鼠标指针应移动到屏幕中心")
        print("   4. 在屏幕上画圆形，鼠标轨迹应该是圆形（不变形）")
        print("")
        print("✅ 正常表现:")
        print("   • 触摸位置与鼠标位置精确对应")
        print("   • 圆形轨迹不发生拉伸变形")
        print("   • 角落和边缘位置映射准确")
        print("")
        print("❌ 异常表现及解决方案:")
        print("   • 位置偏移: 检查坐标转换逻辑")
        print("   • 圆形变椭圆: 调整TOUCH_RESX/TOUCH_RESY比例")
        print("   • 角落无法触及: 检查坐标范围设置")
        print("   • 触摸无响应: 检查设备连接和权限")
        print("")
        print("📝 配置文件位置: MacinTouch/Config.swift")
        print("🔍 关键参数: TOUCH_RESX, TOUCH_RESY")
    }
}

// MARK: - 主程序
let tester = CoordinateMappingTester()
tester.runCoordinateTests()

print("\n" + "=" * 50)
print("✅ 坐标映射测试完成")
print("💡 请根据分析结果进行手动验证")
print("=" * 50)