#!/usr/bin/swift

//
//  device-check.swift
//  MacinTouch 核心工具
//
//  ILITEK设备检测工具 - 检查设备连接状态和基本信息
//

import Foundation
import IOKit
import IOKit.hid

/// ILITEK设备检测器
class DeviceChecker {
    private let ILITEK_VID: Int32 = 0x222a
    private let ILITEK_PID: Int32 = 0x0001
    
    /// 检测ILITEK设备是否连接
    func checkDevice() -> Bool {
        print("🔍 ILITEK 设备检测")
        print("=" * 40)
        
        // 创建HID管理器
        guard let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone)) else {
            print("❌ 无法创建HID管理器")
            return false
        }
        
        // 设置设备过滤条件
        let deviceMatchingDict = [
            kIOHIDVendorIDKey: ILITEK_VID,
            kIOHIDProductIDKey: ILITEK_PID
        ] as CFDictionary
        
        IOHIDManagerSetDeviceMatching(hidManager, deviceMatchingDict)
        
        // 打开HID管理器
        let ioReturn = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard ioReturn == kIOReturnSuccess else {
            print("❌ 无法打开HID管理器: \(ioReturn)")
            return false
        }
        
        // 获取匹配的设备
        guard let deviceSet = IOHIDManagerCopyDevices(hidManager) else {
            print("❌ 未找到ILITEK设备")
            print("   Vendor ID: 0x\(String(ILITEK_VID, radix: 16, uppercase: true))")
            print("   Product ID: 0x\(String(ILITEK_PID, radix: 16, uppercase: true))")
            IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }
        
        let devices = deviceSet as! Set<IOHIDDevice>
        
        if devices.isEmpty {
            print("❌ 未找到ILITEK设备")
            print("💡 请检查：")
            print("   1. 设备是否正确连接")
            print("   2. USB线缆是否正常")
            print("   3. 设备是否已被系统识别")
            IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }
        
        // 显示找到的设备信息
        print("✅ 找到 \(devices.count) 个ILITEK设备")
        
        for (index, device) in devices.enumerated() {
            print("\n📱 设备 \(index + 1):")
            displayDeviceInfo(device)
        }
        
        IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        return true
    }
    
    /// 显示设备详细信息
    private func displayDeviceInfo(_ device: IOHIDDevice) {
        // 获取厂商ID
        if let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey) as? Int32 {
            print("   厂商ID: 0x\(String(vendorID, radix: 16, uppercase: true))")
        }
        
        // 获取产品ID
        if let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey) as? Int32 {
            print("   产品ID: 0x\(String(productID, radix: 16, uppercase: true))")
        }
        
        // 获取产品名称
        if let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey) as? String {
            print("   产品名称: \(productName)")
        }
        
        // 获取制造商
        if let manufacturer = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey) as? String {
            print("   制造商: \(manufacturer)")
        }
        
        // 获取版本号
        if let versionNumber = IOHIDDeviceGetProperty(device, kIOHIDVersionNumberKey) as? Int32 {
            print("   版本号: \(versionNumber)")
        }
        
        // 获取序列号
        if let serialNumber = IOHIDDeviceGetProperty(device, kIOHIDSerialNumberKey) as? String {
            print("   序列号: \(serialNumber)")
        }
        
        // 获取使用页
        if let usagePage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsagePageKey) as? Int32 {
            print("   使用页: 0x\(String(usagePage, radix: 16, uppercase: true))")
        }
        
        // 获取使用ID
        if let usage = IOHIDDeviceGetProperty(device, kIOHIDPrimaryUsageKey) as? Int32 {
            print("   使用ID: 0x\(String(usage, radix: 16, uppercase: true))")
        }
    }
    
    /// 检查系统权限
    func checkPermissions() {
        print("\n🔐 权限检查")
        print("=" * 20)
        
        // 检查HID访问权限
        let hidAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        switch hidAccess {
        case kIOHIDAccessTypeGranted:
            print("✅ HID设备访问权限：已授权")
        case kIOHIDAccessTypeDenied:
            print("❌ HID设备访问权限：被拒绝")
            print("💡 请在系统偏好设置 > 安全性与隐私 > 输入监控 中添加此应用")
        default:
            print("⚠️  HID设备访问权限：未确定")
        }
        
        // 检查辅助功能权限
        if AXIsProcessTrusted() {
            print("✅ 辅助功能权限：已授权")
        } else {
            print("❌ 辅助功能权限：未授权")
            print("💡 请在系统偏好设置 > 安全性与隐私 > 辅助功能 中添加此应用")
        }
    }
}

// MARK: - 主程序
let checker = DeviceChecker()

// 执行设备检测
let deviceFound = checker.checkDevice()

// 检查权限
checker.checkPermissions()

// 显示总结
print("\n📋 检测总结")
print("=" * 20)
if deviceFound {
    print("✅ ILITEK设备检测成功")
    print("🚀 可以尝试启动驱动：sudo make run-debug")
} else {
    print("❌ 未检测到ILITEK设备")
    print("🔧 故障排查建议：")
    print("   1. 确认设备已正确连接")
    print("   2. 检查USB接口和线缆")
    print("   3. 重新插拔设备")
    print("   4. 查看系统信息中的USB设备列表")
}

print("\n💡 更多帮助：请查看 README.md 文档")