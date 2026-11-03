//
//  DisplayInfo.swift
//  MacinTouch GUI
//
//  Model for display information and management
//

import Foundation
import CoreGraphics

struct DisplayInfo: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    let width: Int
    let height: Int
    let isPrimary: Bool
    let bounds: CGRect
    
    init(displayID: CGDirectDisplayID) {
        self.id = displayID
        self.isPrimary = CGDisplayIsMain(displayID) != 0
        
        let bounds = CGDisplayBounds(displayID)
        self.bounds = bounds
        self.width = Int(bounds.width)
        self.height = Int(bounds.height)
        
        // Get display name
        if CGDisplayCopyDisplayMode(displayID) != nil {
            self.name = DisplayInfo.getDisplayName(for: displayID) ?? "Display \(displayID)"
        } else {
            self.name = "Display \(displayID)"
        }
    }
    
    private static func getDisplayName(for displayID: CGDirectDisplayID) -> String? {
        var iterator: io_iterator_t = 0
        
        let matching = IOServiceMatching("IODisplayConnect")
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) != KERN_SUCCESS {
            return nil
        }
        
        defer { IOObjectRelease(iterator) }
        
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            
            let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue()
            
            if let displayNames = CFDictionaryGetValue(info, kDisplayProductName) {
                if let nameDict = unsafeBitCast(displayNames, to: CFDictionary.self) as? [String: Any] {
                    // Try to get English name first, then fall back to any available name
                    if let englishName = nameDict["en_US"] as? String {
                        return englishName
                    } else if let anyName = nameDict.values.first as? String {
                        return anyName
                    }
                }
            }
            
            service = IOIteratorNext(iterator)
        }
        
        return nil
    }
    
    static func == (lhs: DisplayInfo, rhs: DisplayInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

extension DisplayManager {
    func getAvailableDisplays() -> [DisplayInfo] {
        var displayIDs: [CGDirectDisplayID] = []
        var displayCount: UInt32 = 0
        
        // Get the number of active displays
        if CGGetActiveDisplayList(0, nil, &displayCount) != .success {
            return []
        }
        
        // Get the display IDs
        displayIDs = Array(repeating: 0, count: Int(displayCount))
        if CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount) != .success {
            return []
        }
        
        // Convert to DisplayInfo objects
        return displayIDs.map { DisplayInfo(displayID: $0) }
    }
    
    func selectDisplay(_ display: DisplayInfo) {
        print("🖥️  GUI选择显示器: \(display.name) (\(display.width)×\(display.height)) ID: \(display.id)")
        
        // 使用 DisplayManager 的新接口进行手动选择
        selectDisplay(byID: display.id)
        
        if DEBUG_ENABLED && DEBUG_COORDINATES {
            print("✅ 显示器选择已应用到坐标映射系统")
        }
    }
    
    /// 获取当前选择的显示器信息
    func getCurrentSelectedDisplay() -> DisplayInfo? {
        guard let currentID = getCurrentDisplayID() else {
            return nil
        }
        
        let availableDisplays = getAvailableDisplays()
        return availableDisplays.first { $0.id == currentID }
    }
    
    /// 检查指定显示器是否是当前选择的显示器
    func isDisplaySelected(_ display: DisplayInfo) -> Bool {
        return getCurrentDisplayID() == display.id
    }
}