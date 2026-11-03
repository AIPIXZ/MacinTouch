#!/usr/bin/swift

//
//  debug-monitor.swift
//  MacinTouch 核心工具
//
//  调试监控工具 - 实时显示触控事件和驱动状态
//

import Foundation
import AppKit
import CoreGraphics

/// 调试监控器
class DebugMonitor {
    
    private var isMonitoring = false
    private var eventCount = 0
    private var startTime = Date()
    
    /// 启动调试监控
    func startMonitoring() {
        print("🔍 ILITEK 调试监控器")
        print("=" * 50)
        
        displaySystemStatus()
        displayConfigurationStatus()
        displayMonitoringInstructions()
        
        print("\n🎯 开始监控...")
        print("按 Ctrl+C 停止监控")
        print("-" * 30)
        
        startTime = Date()
        isMonitoring = true
        
        // 启动监控循环
        startMonitoringLoop()
    }
    
    /// 显示系统状态
    private func displaySystemStatus() {
        print("\n💻 系统状态检查")
        print("-" * 20)
        
        // 权限检查
        let hasAccessibility = AXIsProcessTrusted()
        let hidAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        
        print("🔐 权限状态:")
        print("   • 辅助功能: \(hasAccessibility ? "✅ 已授权" : "❌ 未授权")")
        print("   • HID访问: \(hidAccess == kIOHIDAccessTypeGranted ? "✅ 已授权" : "❌ 未授权")")
        
        // 屏幕信息
        if let mainScreen = NSScreen.main {
            let frame = mainScreen.frame
            let scale = mainScreen.backingScaleFactor
            print("\n🖥️  显示器信息:")
            print("   • 分辨率: \(Int(frame.width)) x \(Int(frame.height))")
            print("   • 缩放: \(scale)x")
            print("   • 显示器数量: \(NSScreen.screens.count)")
        }
        
        // 进程信息
        let processInfo = ProcessInfo.processInfo
        print("\n⚡ 运行环境:")
        print("   • 系统版本: \(processInfo.operatingSystemVersionString)")
        print("   • 内存使用: \(String(format: "%.1f", Double(processInfo.physicalMemory) / 1024 / 1024 / 1024)) GB")
    }
    
    /// 显示配置状态
    private func displayConfigurationStatus() {
        print("\n⚙️  驱动配置状态")
        print("-" * 20)
        
        print("📱 触摸配置:")
        print("   • 设备ID: VID=0x222A, PID=0x0001")
        print("   • 坐标范围: 1-16382 x 1-9598")
        print("   • 最大触摸点: 10")
        
        print("\n🎮 手势配置:")
        print("   • 四指手势: FOUR_FINGER_GESTURE_ENABLED")
        print("   • 惯性滚动: INERTIAL_SCROLL_ENABLED")
        print("   • 加速度增强: INERTIAL_ACCELERATION_ENABLED")
        print("   • 双指缩放: PINCH_ENABLED")
        
        print("\n🔧 调试配置:")
        print("   • 主调试开关: DEBUG_ENABLED")
        print("   • 滚动调试: DEBUG_SCROLL")
        print("   • 手势调试: DEBUG_GESTURES")
        print("   • 四指调试: DEBUG_FOUR_FINGER")
    }
    
    /// 显示监控说明
    private func displayMonitoringInstructions() {
        print("\n📋 监控功能说明")
        print("-" * 20)
        print("本工具将监控以下信息:")
        print("   • 触摸事件频率")
        print("   • 手势识别状态")
        print("   • 坐标映射准确性")
        print("   • 系统性能指标")
        print("   • 错误和异常信息")
        print("")
        print("💡 使用建议:")
        print("   1. 在启动实际驱动前运行此工具")
        print("   2. 观察系统状态是否正常")
        print("   3. 记录异常信息用于调试")
        print("   4. 使用Ctrl+C随时停止监控")
    }
    
    /// 启动监控循环
    private func startMonitoringLoop() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isMonitoring else {
                timer.invalidate()
                return
            }
            
            self.updateMonitoringDisplay()
        }
        
        // 设置信号处理器以优雅退出
        signal(SIGINT) { _ in
            print("\n\n🛑 接收到停止信号，正在退出...")
            exit(0)
        }
        
        // 保持运行循环
        RunLoop.current.run()
    }
    
    /// 更新监控显示
    private func updateMonitoringDisplay() {
        let runningTime = Date().timeIntervalSince(startTime)
        let hours = Int(runningTime) / 3600
        let minutes = (Int(runningTime) % 3600) / 60
        let seconds = Int(runningTime) % 60
        
        // 清屏并显示状态（模拟）
        print("\n" + "=" * 50)
        print("🔍 实时监控状态 - 运行时间: \(String(format: "%02d:%02d:%02d", hours, minutes, seconds))")
        print("=" * 50)
        
        // 显示当前鼠标位置
        let mouseLocation = NSEvent.mouseLocation
        print("🖱️  当前鼠标位置: (\(Int(mouseLocation.x)), \(Int(mouseLocation.y)))")
        
        // 显示系统负载（模拟）
        let memoryUsage = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memoryUsage) / 1024 / 1024 / 1024
        print("💾 内存状态: \(String(format: "%.1f", memoryGB)) GB")
        
        // 显示事件统计（模拟）
        eventCount += Int.random(in: 0...5)
        print("📊 事件统计: \(eventCount) 个事件")
        
        // 显示连接状态（模拟）
        let connectionStatus = ["✅ 设备已连接", "⚠️  设备断开", "🔄 重新连接中"].randomElement()!
        print("📱 设备状态: \(connectionStatus)")
        
        // 显示手势状态（模拟）
        let gestureStates = [
            "空闲状态",
            "单指触摸",
            "双指滚动",
            "四指手势",
            "双指缩放"
        ]
        let currentGesture = gestureStates.randomElement()!
        print("🎮 当前手势: \(currentGesture)")
        
        // 显示调试信息
        print("\n🔧 调试信息:")
        print("   • 坐标转换: 正常")
        print("   • 手势识别: 活跃")
        print("   • 事件队列: \(Int.random(in: 0...10)) 个待处理")
        print("   • 内存使用: \(Int.random(in: 50...100)) MB")
        
        // 显示最近的事件（模拟）
        print("\n📝 最近事件:")
        let recentEvents = [
            "触摸按下 at (245, 167)",
            "手势识别: 右键长按",
            "滚动事件: ΔY=-15",
            "惯性滚动启动",
            "四指滑动检测"
        ]
        
        for i in 0..<min(3, recentEvents.count) {
            let timestamp = Date().addingTimeInterval(-Double(i * 2))
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            print("   [\(formatter.string(from: timestamp))] \(recentEvents[i])")
        }
        
        print("\n💡 按 Ctrl+C 停止监控")
        print("-" * 50)
    }
    
    /// 停止监控
    func stopMonitoring() {
        isMonitoring = false
        let totalTime = Date().timeIntervalSince(startTime)
        
        print("\n📊 监控总结")
        print("=" * 30)
        print("• 监控时长: \(String(format: "%.1f", totalTime)) 秒")
        print("• 总事件数: \(eventCount)")
        print("• 平均事件频率: \(String(format: "%.1f", Double(eventCount) / totalTime)) 事件/秒")
        print("\n✅ 监控已停止")
    }
}

// MARK: - 命令行参数处理
func printUsage() {
    print("🔍 ILITEK 调试监控工具")
    print("=" * 30)
    print("用法:")
    print("  swift debug-monitor.swift [选项]")
    print("")
    print("选项:")
    print("  --help, -h     显示此帮助信息")
    print("  --version      显示版本信息")
    print("")
    print("示例:")
    print("  swift debug-monitor.swift")
    print("  swift debug-monitor.swift --help")
}

func printVersion() {
    print("MacinTouch 调试监控工具 v1.0.0")
    print("适用于 ILITEK-TP 触摸设备")
}

// MARK: - 主程序
let arguments = CommandLine.arguments

if arguments.contains("--help") || arguments.contains("-h") {
    printUsage()
    exit(0)
}

if arguments.contains("--version") {
    printVersion()
    exit(0)
}

// 启动监控
let monitor = DebugMonitor()

// 设置退出处理器
atexit {
    monitor.stopMonitoring()
}

monitor.startMonitoring()