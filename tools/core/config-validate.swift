#!/usr/bin/swift

//
//  config-validator.swift
//  MacinTouch Tools
//
//  配置参数验证工具
//

import Foundation
import AppKit

print("⚙️  ILITEK 驱动配置验证")
print("======================")

// 从Config.swift读取配置 (模拟)
let TOUCH_VID: Int32 = 0x222a
let TOUCH_PID: Int32 = 0x0001
let TOUCH_RESX = 1920.0
let TOUCH_RESY = 1080.0
let NUM_TOUCHES = 10

// 获取当前屏幕信息
guard let screen = NSScreen.main else {
    print("❌ 无法获取主屏幕信息")
    exit(1)
}

let screenSize = screen.frame.size
let screenScale = screen.backingScaleFactor

print("📱 当前系统配置:")
print("   屏幕分辨率: \(Int(screenSize.width)) x \(Int(screenSize.height))")
print("   缩放因子: \(screenScale)x")
print("   实际像素: \(Int(screenSize.width * screenScale)) x \(Int(screenSize.height * screenScale))")

print("")
print("🎯 驱动配置:")
print("   目标设备: VID=0x\(String(TOUCH_VID, radix: 16, uppercase: true)), PID=0x\(String(TOUCH_PID, radix: 16, uppercase: true))")
print("   触摸分辨率: \(Int(TOUCH_RESX)) x \(Int(TOUCH_RESY))")
print("   最大触摸点: \(NUM_TOUCHES)")

print("")
print("🔍 配置分析:")

// 分析坐标映射比例
let scaleX = screenSize.width / TOUCH_RESX
let scaleY = screenSize.height / TOUCH_RESY

print("   X轴缩放比例: \(String(format: "%.4f", scaleX))")
print("   Y轴缩放比例: \(String(format: "%.4f", scaleY))")

if abs(scaleX - scaleY) > 0.1 {
    print("   ⚠️  X和Y轴缩放比例差异较大，可能导致触摸变形")
    print("   💡 建议调整TOUCH_RESX或TOUCH_RESY以保持比例一致")
} else {
    print("   ✅ X和Y轴缩放比例基本一致")
}

// 检查分辨率合理性
if TOUCH_RESX < 100 || TOUCH_RESY < 100 {
    print("   ❌ 触摸分辨率过低，可能不正确")
} else if TOUCH_RESX > 10000 || TOUCH_RESY > 10000 {
    print("   ❌ 触摸分辨率过高，可能不正确")
} else {
    print("   ✅ 触摸分辨率在合理范围内")
}

// 检查触摸点数量
if NUM_TOUCHES < 1 {
    print("   ❌ 触摸点数量不能小于1")
} else if NUM_TOUCHES > 20 {
    print("   ⚠️  触摸点数量过多，可能影响性能")
} else {
    print("   ✅ 触摸点数量设置合理")
}

print("")
print("🔧 建议的配置优化:")

// 建议最佳触摸分辨率
let idealTouchResX = screenSize.width * screenScale
let idealTouchResY = screenSize.height * screenScale

if abs(TOUCH_RESX - idealTouchResX) > 100 || abs(TOUCH_RESY - idealTouchResY) > 100 {
    print("   💡 建议的触摸分辨率:")
    print("      let TOUCH_RESX = \(idealTouchResX)")
    print("      let TOUCH_RESY = \(idealTouchResY)")
}

// 检查常见的触摸屏分辨率
let commonResolutions = [
    (1920.0, 1080.0, "Full HD"),
    (2560.0, 1440.0, "2K"),
    (3840.0, 2160.0, "4K"),
    (1366.0, 768.0, "HD"),
    (1280.0, 720.0, "HD Ready")
]

print("")
print("📏 常见触摸屏分辨率参考:")
for (width, height, name) in commonResolutions {
    let marker = (abs(TOUCH_RESX - width) < 10 && abs(TOUCH_RESY - height) < 10) ? "🎯" : "  "
    print("   \(marker) \(Int(width)) x \(Int(height)) (\(name))")
}

print("")
print("✅ 配置验证完成!")
print("")
print("💡 如需修改配置，请编辑 MacinTouch/Config.swift 文件")