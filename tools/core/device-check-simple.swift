#!/usr/bin/swift

//
//  device-check-simple.swift
//  MacinTouch 核心工具
//
//  简化版设备检测工具 - 检查设备连接状态和基本信息
//

import Foundation
import IOKit
import IOKit.hid

print("🔍 ILITEK 设备检测")
print(String(repeating: "=", count: 40))

let ILITEK_VID: Int32 = 0x222a
let ILITEK_PID: Int32 = 0x0001

// 创建HID管理器
let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

// 设置设备过滤条件
let deviceMatchingDict = [
    kIOHIDVendorIDKey: ILITEK_VID,
    kIOHIDProductIDKey: ILITEK_PID
] as CFDictionary

IOHIDManagerSetDeviceMatching(hidManager, deviceMatchingDict)

// 打开HID管理器
let ioReturn = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))

if ioReturn != kIOReturnSuccess {
    print("❌ 无法打开HID管理器，返回码: \(ioReturn)")
    print("💡 可能需要root权限，请尝试: sudo swift device-check-simple.swift")
    exit(1)
}

// 获取匹配的设备
let deviceSetOptional = IOHIDManagerCopyDevices(hidManager)

if let deviceSet = deviceSetOptional {
    let devices = deviceSet as! Set<IOHIDDevice>
    
    if devices.isEmpty {
        print("❌ 未找到ILITEK设备")
        print("   目标设备: VID=0x\(String(ILITEK_VID, radix: 16, uppercase: true)), PID=0x\(String(ILITEK_PID, radix: 16, uppercase: true))")
        print("💡 请检查：")
        print("   1. 设备是否正确连接")
        print("   2. USB线缆是否正常")
        print("   3. 设备是否已被系统识别")
    } else {
        print("✅ 找到 \(devices.count) 个ILITEK设备")
        
        for (index, device) in devices.enumerated() {
            print("\n📱 设备 \(index + 1):")
            
            // 获取基本属性
            if let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int32 {
                print("   厂商ID: 0x\(String(vendorID, radix: 16, uppercase: true))")
            }
            
            if let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int32 {
                print("   产品ID: 0x\(String(productID, radix: 16, uppercase: true))")
            }
            
            if let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String {
                print("   产品名称: \(productName)")
            }
            
            if let manufacturer = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String {
                print("   制造商: \(manufacturer)")
            }
        }
    }
} else {
    print("❌ 无法获取设备列表")
}

// 关闭HID管理器
IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))

// 权限检查
print("\n🔐 权限检查")
print(String(repeating: "=", count: 20))

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

print("\n📋 检测总结")
print(String(repeating: "=", count: 20))
print("✅ 设备检测完成")
print("💡 如有问题，请查看故障排查指南或联系开发者")