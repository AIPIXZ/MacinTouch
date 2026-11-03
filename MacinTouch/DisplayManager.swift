//
//  DisplayManager.swift
//  MacinTouch
//
//  Dynamic display configuration management
//

import AppKit
import Foundation

class DisplayManager {
  static let shared = DisplayManager()

  // 当前目标显示器信息
  private(set) var targetScreen: NSScreen?
  private(set) var screenResolution: CGSize = CGSize.zero
  private(set) var screenOffset: CGPoint = CGPoint.zero
  private(set) var scaleFactor: CGFloat = 1.0

  // 手动选择模式
  private var isManualMode: Bool = false
  private var manualDisplayID: CGDirectDisplayID = 0
  
  // 显示器选择模式枚举
  enum DisplaySelectionMode {
    case automatic    // 自动选择（原有逻辑）
    case manual(CGDirectDisplayID)  // 手动选择特定显示器
  }
  
  private var selectionMode: DisplaySelectionMode = .automatic

  // 回调函数，当显示器配置改变时调用
  var onDisplayConfigChanged: (() -> Void)?

  private init() {
    // 不再在初始化时固定主显示器，改为每次坐标转换时动态获取
    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("🖥️ DisplayManager 初始化 - 使用动态主显示器获取")
    }

    updateDisplayConfiguration()
    setupDisplayChangeNotification()
  }

  // 更新显示器配置
  func updateDisplayConfiguration() {
    let oldResolution = screenResolution
    let oldOffset = screenOffset

    // 根据选择模式查找目标显示器
    switch selectionMode {
    case .automatic:
      targetScreen = findTargetDisplayAutomatic()
      if DEBUG_ENABLED && DEBUG_COORDINATES {
        print("🖥️  Using automatic display selection")
      }
    case .manual(let displayID):
      targetScreen = findTargetDisplayByID(displayID)
      if DEBUG_ENABLED && DEBUG_COORDINATES {
        print("🖥️  Using manual display selection: \(displayID)")
      }
      // 如果手动选择的显示器不存在，回退到自动模式
      if targetScreen == nil {
        print("⚠️  手动选择的显示器 \(displayID) 不存在，回退到自动模式")
        selectionMode = .automatic
        targetScreen = findTargetDisplayAutomatic()
      }
    }

    if let screen = targetScreen {
      let frame = screen.frame
      scaleFactor = screen.backingScaleFactor

      // 获取实际像素分辨率
      screenResolution = CGSize(
        width: frame.width * scaleFactor,
        height: frame.height * scaleFactor
      )

      // 获取显示器偏移
      screenOffset = frame.origin

      if DEBUG_ENABLED && DEBUG_COORDINATES {
        print("🖥️  Target Display Updated:")
        print("   Resolution: \(Int(screenResolution.width)) x \(Int(screenResolution.height))")
        print("   Offset: (\(Int(screenOffset.x)), \(Int(screenOffset.y)))")
        print("   Scale Factor: \(scaleFactor)x")
        print("   Selection Mode: \(selectionMode)")
      }

    } else {
      print("❌ 未找到合适的目标显示器")
      // 使用主显示器作为备选
      if let mainScreen = NSScreen.main {
        targetScreen = mainScreen
        let frame = mainScreen.frame
        scaleFactor = mainScreen.backingScaleFactor
        screenResolution = CGSize(
          width: frame.width * scaleFactor,
          height: frame.height * scaleFactor
        )
        screenOffset = frame.origin

        print("⚠️  使用主显示器作为备选")
      }
    }

    // 检查配置是否发生变化
    if oldResolution != screenResolution || oldOffset != screenOffset {
      onDisplayConfigChanged?()
    }
  }

  // 查找目标显示器 - 自动模式 (触摸屏驱动模式)
  private func findTargetDisplayAutomatic() -> NSScreen? {
    let screens = NSScreen.screens

    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("🔍 扫描 \(screens.count) 个显示器，寻找触摸屏目标:")
    }

    // 显示所有可用显示器信息
    for (index, screen) in screens.enumerated() {
      let frame = screen.frame
      let scale = screen.backingScaleFactor
      let actualPixels = CGSize(width: frame.width * scale, height: frame.height * scale)
      let isExternal = frame.origin.x != 0 || frame.origin.y != 0

      if DEBUG_ENABLED && DEBUG_COORDINATES {
        let displayType = isExternal ? "外接" : "内置"
        print(
          "   Display[\(index)]: \(Int(actualPixels.width))x\(Int(actualPixels.height)) @ (\(Int(frame.origin.x)), \(Int(frame.origin.y))) [\(displayType)]"
        )
      }
    }

    // 触摸屏驱动策略：
    // 1. 优先选择外接显示器（触摸屏通常是外接设备）
    // 2. 如果没有外接显示器，选择第一个显示器（固定引用）

    // 查找第一个外接显示器
    for (index, screen) in screens.enumerated() {
      let frame = screen.frame
      if frame.origin.x != 0 || frame.origin.y != 0 {
        if DEBUG_ENABLED && DEBUG_COORDINATES {
          print("   ✅ 选择外接显示器 [\(index)] 作为触摸屏目标")
        }
        return screen
      }
    }

    // 如果没有外接显示器，使用第一个显示器（避免使用NSScreen.main）
    if let firstScreen = screens.first {
      if DEBUG_ENABLED && DEBUG_COORDINATES {
        print("   ⚠️  没有外接显示器，使用第一个显示器作为目标")
      }
      return firstScreen
    }

    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("   ❌ 未找到任何显示器")
    }

    return nil
  }
  
  // 根据显示器 ID 查找目标显示器 - 手动模式
  private func findTargetDisplayByID(_ displayID: CGDirectDisplayID) -> NSScreen? {
    let screens = NSScreen.screens
    
    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("🔍 查找指定显示器 ID: \(displayID)")
    }
    
    for (index, screen) in screens.enumerated() {
      // 通过显示器属性匹配 displayID
      if let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
        let screenID = CGDirectDisplayID(screenNumber.uint32Value)
        if screenID == displayID {
          if DEBUG_ENABLED && DEBUG_COORDINATES {
            let frame = screen.frame
            let scale = screen.backingScaleFactor
            let actualPixels = CGSize(width: frame.width * scale, height: frame.height * scale)
            print("   ✅ 找到指定显示器[\(index)]: \(Int(actualPixels.width))x\(Int(actualPixels.height)) @ (\(Int(frame.origin.x)), \(Int(frame.origin.y)))")
          }
          return screen
        }
      }
    }
    
    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("   ❌ 未找到指定的显示器 ID: \(displayID)")
    }
    
    return nil
  }
  
  // MARK: - 公共接口
  
  /// 手动选择显示器
  func selectDisplay(byID displayID: CGDirectDisplayID) {
    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("🖥️  手动选择显示器: \(displayID)")
    }
    
    selectionMode = .manual(displayID)
    updateDisplayConfiguration()
  }
  
  /// 设置为自动选择模式
  func setAutomaticDisplaySelection() {
    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("🖥️  切换到自动选择模式")
    }
    
    selectionMode = .automatic
    updateDisplayConfiguration()
  }
  
  /// 获取当前选择的显示器 ID（如果是手动模式）
  func getCurrentDisplayID() -> CGDirectDisplayID? {
    if let screen = targetScreen,
       let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
      return CGDirectDisplayID(screenNumber.uint32Value)
    }
    return nil
  }
  
  /// 检查当前是否是手动选择模式
  var isManualSelectionMode: Bool {
    switch selectionMode {
    case .manual(_):
      return true
    case .automatic:
      return false
    }
  }

  // 设置显示器变化通知
  private func setupDisplayChangeNotification() {
    NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification,
      object: NSApplication.shared,
      queue: OperationQueue.main
    ) { [weak self] _ in
      if DEBUG_ENABLED && DEBUG_COORDINATES {
        print("📱 Display configuration changed, updating...")
      }
      self?.updateDisplayConfiguration()
    }
  }


  // MARK: - 坐标系统转换方法 (Hardware ↔ AppKit Screen)
  
  /// 将硬件触摸坐标转换为AppKit屏幕坐标
  /// 
  /// 硬件坐标系统：
  /// - 范围: X: 1-16383, Y: 1-9599
  /// - 原点: 左下角，Y轴向上递增
  /// 
  /// AppKit屏幕坐标系统：
  /// - 范围: 根据实际屏幕分辨率
  /// - 原点: 左下角，Y轴向上递增
  /// - 用于: NSEvent.mouseLocation, NSScreen.frame
  ///
  /// - Parameters:
  ///   - hardwareX: 硬件X坐标 (1-16383)
  ///   - hardwareY: 硬件Y坐标 (1-9599)
  /// - Returns: AppKit屏幕坐标 (原点在左下角，Y轴向上)
  func convertHardwareToAppKitScreen(hardwareX: Int, hardwareY: Int) -> CGPoint {
    // 使用配置文件中定义的硬件坐标范围
    let HARDWARE_MIN_X = 1.0
    let HARDWARE_MAX_X = HARDWARE_MIN_X + TOUCH_RESX  // 1 + 16382 = 16383
    let HARDWARE_MIN_Y = 1.0
    let HARDWARE_MAX_Y = HARDWARE_MIN_Y + TOUCH_RESY  // 1 + 9598 = 9599

    // 获取目标显示器信息
    guard let screen = targetScreen else {
      if DEBUG_ENABLED {
        print("❌ DisplayManager: 无法获取目标显示器")
      }
      return CGPoint.zero
    }

    let screenFrame = screen.frame
    let screenOffsetX = screenFrame.origin.x
    let screenOffsetY = screenFrame.origin.y
    let screenWidth = screenFrame.width
    let screenHeight = screenFrame.height

    // 计算坐标范围
    let touchRangeX = HARDWARE_MAX_X - HARDWARE_MIN_X  // 16382
    let touchRangeY = HARDWARE_MAX_Y - HARDWARE_MIN_Y  // 9598

    // 标准化坐标 (0.0 到 1.0)
    let normalizedX = max(0.0, min(1.0, (Double(hardwareX) - HARDWARE_MIN_X) / touchRangeX))
    // Y轴反转：硬件Y=1对应屏幕底部，硬件Y=9599对应屏幕顶部
    let normalizedY = max(0.0, min(1.0, 1.0 - (Double(hardwareY) - HARDWARE_MIN_Y) / touchRangeY))

    // 映射到AppKit屏幕坐标系
    let screenX = screenOffsetX + (normalizedX * screenWidth)
    let screenY = screenOffsetY + (normalizedY * screenHeight)

    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("🖥️ DisplayManager硬件→AppKit转换:")
      print("   硬件坐标: (\(hardwareX), \(hardwareY))")
      print("   硬件范围: X=\(HARDWARE_MIN_X)-\(HARDWARE_MAX_X), Y=\(HARDWARE_MIN_Y)-\(HARDWARE_MAX_Y)")
      print(
        "   标准化坐标: (\(String(format: "%.3f", normalizedX)), \(String(format: "%.3f", normalizedY)))"
      )
      print(
        "   屏幕Frame: origin=(\(Int(screenOffsetX)), \(Int(screenOffsetY))), size=(\(Int(screenWidth))x\(Int(screenHeight)))"
      )
      print("   AppKit屏幕坐标: (\(Int(screenX)), \(Int(screenY)))")
    }

    return CGPoint(x: screenX, y: screenY)
  }
  
  /// 将AppKit屏幕坐标转换为硬件触摸坐标
  /// 
  /// AppKit屏幕坐标系统：
  /// - 范围: 根据实际屏幕分辨率
  /// - 原点: 左下角，Y轴向上递增
  /// - 来源: NSEvent.mouseLocation
  /// 
  /// 硬件坐标系统：
  /// - 范围: X: 1-16383, Y: 1-9599  
  /// - 原点: 左下角，Y轴向上递增
  /// - 用于: Touch对象坐标
  ///
  /// - Parameter screenPoint: AppKit屏幕坐标点
  /// - Returns: 硬件坐标 (x: 1-16383, y: 1-9599)
  func convertAppKitScreenToHardware(screenPoint: CGPoint) -> (x: Int, y: Int) {
    // 获取目标显示器信息
    guard let screen = targetScreen else {
      if DEBUG_ENABLED {
        print("❌ DisplayManager: 无法获取目标显示器")
      }
      return (x: 1, y: 1)  // 返回最小硬件坐标
    }
    
    let screenFrame = screen.frame
    let screenOffsetX = screenFrame.origin.x
    let screenOffsetY = screenFrame.origin.y
    let screenWidth = screenFrame.width
    let screenHeight = screenFrame.height
    
    // AppKit屏幕坐标 → 标准化坐标 (0.0-1.0)
    let normalizedX = max(0.0, min(1.0, (screenPoint.x - screenOffsetX) / screenWidth))
    let normalizedY = max(0.0, min(1.0, (screenPoint.y - screenOffsetY) / screenHeight))
    
    // 标准化坐标 → 硬件坐标 (注意Y轴反转)
    let HARDWARE_MIN_X = 1.0
    let HARDWARE_MAX_X = HARDWARE_MIN_X + TOUCH_RESX  // 16383
    let HARDWARE_MIN_Y = 1.0
    let HARDWARE_MAX_Y = HARDWARE_MIN_Y + TOUCH_RESY  // 9599
    
    let touchRangeX = HARDWARE_MAX_X - HARDWARE_MIN_X
    let touchRangeY = HARDWARE_MAX_Y - HARDWARE_MIN_Y
    
    let hardwareX = Int(HARDWARE_MIN_X + (normalizedX * touchRangeX))
    // Y轴反转：AppKit屏幕底部对应硬件Y=1，屏幕顶部对应硬件Y=9599
    let hardwareY = Int(HARDWARE_MIN_Y + ((1.0 - normalizedY) * touchRangeY))
    
    // 确保坐标在有效范围内
    let clampedX = max(1, min(Int(HARDWARE_MAX_X), hardwareX))
    let clampedY = max(1, min(Int(HARDWARE_MAX_Y), hardwareY))
    
    if DEBUG_ENABLED && DEBUG_COORDINATES {
      print("🖥️ DisplayManager AppKit→硬件转换:")
      print("   AppKit屏幕坐标: (\(Int(screenPoint.x)), \(Int(screenPoint.y)))")
      print("   标准化坐标: (\(String(format: "%.3f", normalizedX)), \(String(format: "%.3f", normalizedY)))")
      print("   硬件坐标: (\(clampedX), \(clampedY))")
      print("   硬件范围: X=\(Int(HARDWARE_MIN_X))-\(Int(HARDWARE_MAX_X)), Y=\(Int(HARDWARE_MIN_Y))-\(Int(HARDWARE_MAX_Y))")
    }
    
    return (x: clampedX, y: clampedY)
  }
  
  // 保持向后兼容，标记为deprecated
  @available(*, deprecated, message: "使用 convertHardwareToAppKitScreen 替代")
  func convertTouchToScreenCoordinates(touchX: Int, touchY: Int) -> CGPoint {
    return convertHardwareToAppKitScreen(hardwareX: touchX, hardwareY: touchY)
  }

  // 获取当前显示器配置信息
  func getDisplayInfo() -> String {
    guard let screen = targetScreen else {
      return "No target display found"
    }

    // 确定显示器类型 - 优先检查分辨率和位置
    let displayType: String
    let frame = screen.frame

    // 检查是否是4K显示器
    if Int(screenResolution.width) == 3840 && Int(screenResolution.height) == 2160 {
      // 进一步检查是否是外接显示器（通过偏移位置判断）
      if frame.origin.x != 0 || frame.origin.y != 0 {
        displayType = " (4K外接显示器)"
      } else {
        displayType = " (4K主显示器)"
      }
    } else {
      // 非4K显示器，检查是否是主显示器
      if screen == NSScreen.main {
        displayType = " (主显示器)"
      } else {
        displayType = " (外接显示器)"
      }
    }

    return """
      Target Display\(displayType):
        Resolution: \(Int(screenResolution.width)) x \(Int(screenResolution.height))
        Offset: (\(Int(screenOffset.x)), \(Int(screenOffset.y)))
        Scale: \(scaleFactor)x
        Touch Resolution: \(Int(TOUCH_RESX)) x \(Int(TOUCH_RESY))
      """
  }

  // 检查配置是否有效
  func isConfigurationValid() -> Bool {
    return targetScreen != nil && screenResolution.width > 0 && screenResolution.height > 0
  }

  // MARK: - AppKit Screen <-> CGEvent Coordinate Conversion

  /// Convert AppKit screen coordinates (origin bottom-left, Y up)
  /// to CGEvent coordinates (origin top-left, Y down).
  func convertAppKitScreenToCGEvent(_ point: CGPoint) -> CGPoint {
    guard let primary = NSScreen.screens.first else { return point }
    return CGPoint(x: point.x, y: primary.frame.height - point.y)
  }

  /// Convert CGEvent coordinates (origin top-left, Y down)
  /// to AppKit screen coordinates (origin bottom-left, Y up).
  func convertCGEventToAppKitScreen(_ point: CGPoint) -> CGPoint {
    guard let primary = NSScreen.screens.first else { return point }
    return CGPoint(x: point.x, y: primary.frame.height - point.y)
  }

  // MARK: - Convenience: Hardware <-> CGEvent

  /// Hardware coordinates directly to CGEvent coordinates.
  func convertHardwareToCGEvent(hardwareX: Int, hardwareY: Int) -> CGPoint {
    let appKit = convertHardwareToAppKitScreen(hardwareX: hardwareX, hardwareY: hardwareY)
    return convertAppKitScreenToCGEvent(appKit)
  }
}
