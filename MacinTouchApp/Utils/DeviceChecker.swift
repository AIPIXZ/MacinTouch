//
//  DeviceChecker.swift
//  MacinTouch GUI
//
//  Utility for checking ILITEK device connection status
//

import Foundation
import IOKit
import IOKit.hid

class DeviceChecker {
    private let targetVendorID: Int
    private let targetProductID: Int

    init(config: DeviceConfig = DriverConfig.loadOrDefault().device) {
        self.targetVendorID = Int(config.vendorID)
        self.targetProductID = Int(config.productID)
    }

    /// Check device presence via IOKit service matching (no HID permissions needed).
    func isDeviceConnected() -> Bool {
        guard let matchingDict = IOServiceMatching(kIOHIDDeviceKey) as NSMutableDictionary? else {
            return false
        }
        matchingDict[kIOHIDVendorIDKey] = targetVendorID
        matchingDict[kIOHIDProductIDKey] = targetProductID

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard result == KERN_SUCCESS else { return false }

        let service = IOIteratorNext(iterator)
        IOObjectRelease(iterator)

        if service != 0 {
            IOObjectRelease(service)
            return true
        }
        return false
    }

    func findConnectedDevices() -> [HIDDeviceInfo] {
        var devices: [HIDDeviceInfo] = []

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matchingDict: [String: Any] = [
            kIOHIDVendorIDKey: targetVendorID,
            kIOHIDProductIDKey: targetProductID
        ]

        IOHIDManagerSetDeviceMatching(manager, matchingDict as CFDictionary)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            return devices
        }

        if let deviceArray = IOHIDManagerCopyDevices(manager) as? [IOHIDDevice] {
            for device in deviceArray {
                if let deviceInfo = createDeviceInfo(from: device) {
                    devices.append(deviceInfo)
                }
            }
        }

        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        return devices
    }

    private func createDeviceInfo(from device: IOHIDDevice) -> HIDDeviceInfo? {
        guard let vendorID = IOHIDDeviceGetProperty(device, kIOHIDVendorIDKey as CFString) as? Int,
              let productID = IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int else {
            return nil
        }

        let productName = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String ?? "Unknown Device"
        let manufacturerName = IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String ?? "Unknown Manufacturer"

        return HIDDeviceInfo(
            vendorID: vendorID,
            productID: productID,
            productName: productName,
            manufacturerName: manufacturerName
        )
    }
}

struct HIDDeviceInfo {
    let vendorID: Int
    let productID: Int
    let productName: String
    let manufacturerName: String

    var displayName: String {
        return "\(manufacturerName) \(productName)"
    }

    var idString: String {
        return "VID: 0x\(String(vendorID, radix: 16)), PID: 0x\(String(productID, radix: 16))"
    }
}
