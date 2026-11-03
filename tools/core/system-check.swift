#!/usr/bin/swift

//
//  system-check.swift
//  MacinTouch Tools
//
//  系统兼容性检查工具
//

import Foundation
import AppKit

print("🖥️  系统兼容性检查")
print("==================")

// 获取系统信息
let processInfo = ProcessInfo.processInfo
let osVersion = processInfo.operatingSystemVersion

print("📱 系统信息:")
print("   操作系统: \(processInfo.operatingSystemVersionString)")
print("   版本: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")

// 检查macOS版本兼容性
let minMajorVersion = 10
let minMinorVersion = 15

var isCompatible = true

if osVersion.majorVersion < minMajorVersion || 
   (osVersion.majorVersion == minMajorVersion && osVersion.minorVersion < minMinorVersion) {
    print("   ❌ 系统版本过低，需要 macOS 10.15 或更高版本")
    isCompatible = false
} else {
    print("   ✅ 系统版本兼容")
}

// 检查架构
#if arch(arm64)
    print("   架构: Apple Silicon (arm64) ✅")
#elseif arch(x86_64)
    print("   架构: Intel (x86_64) ⚠️")
    print("   💡 项目针对Apple Silicon优化，Intel架构可能性能略低")
#else
    print("   架构: 未知 ❌")
    isCompatible = false
#endif

// 检查内存
let physicalMemory = processInfo.physicalMemory
let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)

print("   物理内存: \(String(format: "%.1f", memoryGB)) GB")

if memoryGB < 4.0 {
    print("   ⚠️  内存较少，可能影响性能")
} else {
    print("   ✅ 内存充足")
}

// 检查处理器信息
print("")
print("🔧 处理器信息:")

let hostInfo = ProcessInfo.processInfo.hostName
print("   主机名: \(hostInfo)")

// 检查CPU核心数
let coreCount = ProcessInfo.processInfo.processorCount
print("   CPU核心数: \(coreCount)")

if coreCount < 2 {
    print("   ⚠️  CPU核心数较少")
} else {
    print("   ✅ CPU核心数充足")
}

// 检查屏幕信息
print("")
print("🖥️  显示器信息:")

if let mainScreen = NSScreen.main {
    let frame = mainScreen.frame
    let scale = mainScreen.backingScaleFactor
    
    print("   主屏幕分辨率: \(Int(frame.width)) x \(Int(frame.height))")
    print("   缩放因子: \(scale)x")
    print("   实际像素: \(Int(frame.width * scale)) x \(Int(frame.height * scale))")
    
    // 检查多显示器
    let screenCount = NSScreen.screens.count
    print("   显示器数量: \(screenCount)")
    
    if screenCount > 1 {
        print("   💡 检测到多显示器，驱动将使用主显示器")
    }
} else {
    print("   ❌ 无法获取显示器信息")
    isCompatible = false
}

// 检查权限
print("")
print("🔐 权限检查:")

// 检查是否以管理员权限运行
let isRoot = getuid() == 0
if isRoot {
    print("   ✅ 以管理员权限运行")
} else {
    print("   ⚠️  未以管理员权限运行")
    print("   💡 驱动程序需要root权限访问HID设备")
}

// 检查辅助功能权限
let trusted = AXIsProcessTrusted()
if trusted {
    print("   ✅ 已获得辅助功能权限")
} else {
    print("   ⚠️  未获得辅助功能权限")
    print("   💡 请在 系统偏好设置 > 安全性与隐私 > 辅助功能 中添加权限")
}

// 检查开发工具
print("")
print("🛠️  开发工具检查:")

// 检查Xcode
let xcodebuildPath = "/usr/bin/xcodebuild"
if FileManager.default.fileExists(atPath: xcodebuildPath) {
    print("   ✅ Xcode命令行工具已安装")
} else {
    print("   ❌ Xcode命令行工具未安装")
    print("   💡 运行: xcode-select --install")
    isCompatible = false
}

// 检查Swift
let swiftPath = "/usr/bin/swift"
if FileManager.default.fileExists(atPath: swiftPath) {
    print("   ✅ Swift编译器可用")
} else {
    print("   ❌ Swift编译器不可用")
    isCompatible = false
}

// 检查IOKit框架
print("")
print("📚 系统框架检查:")

let frameworks = [
    "/System/Library/Frameworks/IOKit.framework",
    "/System/Library/Frameworks/AppKit.framework",
    "/System/Library/Frameworks/CoreGraphics.framework",
    "/System/Library/Frameworks/Foundation.framework"
]

var allFrameworksAvailable = true

for framework in frameworks {
    let frameworkName = URL(fileURLWithPath: framework).lastPathComponent
    if FileManager.default.fileExists(atPath: framework) {
        print("   ✅ \(frameworkName)")
    } else {
        print("   ❌ \(frameworkName)")
        allFrameworksAvailable = false
    }
}

if !allFrameworksAvailable {
    isCompatible = false
}

// 总结
print("")
print("📋 兼容性总结:")
print("================")

if isCompatible {
    print("✅ 系统完全兼容 MacinTouch")
    print("")
    print("🚀 可以开始使用:")
    print("   1. 连接ILITEK触摸设备")
    print("   2. 运行: make debug")
    print("   3. 测试: sudo make run-debug")
} else {
    print("❌ 系统存在兼容性问题")
    print("")
    print("🔧 请解决以上问题后重新检查")
}

print("")
print("💡 更多信息请查看 README.md 和 DEVELOPMENT.md")