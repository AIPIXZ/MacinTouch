//
//  MacinTouchCore.swift
//  MacinTouch GUI
//
//  In-process implementation of MacinTouchInterface.
//  Bridges the GUI to the HID driver layer.
//

import Foundation
import AppKit
import IOKit.hid

class MacinTouchCore: MacinTouchInterface {
    static let shared = MacinTouchCore()

    // MARK: - MacinTouchInterface

    private(set) var status = DriverStatus() {
        didSet {
            if status != oldValue {
                statusHandler?(status)
            }
        }
    }

    var config: DriverConfig {
        get { _config }
        set {
            _config = newValue
            applyConfig(newValue)
            try? newValue.save()
        }
    }

    // MARK: - Private State

    private var _config = DriverConfig.loadOrDefault()
    private var touchHandler: TouchHandler?
    private var statusHandler: ((DriverStatus) -> Void)?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        guard !status.isRunning else { return }

        // Check permissions
        let accessibility = AXIsProcessTrusted()
        let inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        status.hasAccessibilityPermission = accessibility
        status.hasInputMonitoringPermission = inputMonitoring

        guard accessibility else {
            status.errorMessage = "Accessibility permission required"
            Log.warn(.system, "Missing accessibility permission")
            return
        }

        guard inputMonitoring else {
            status.errorMessage = "Input monitoring permission required"
            Log.warn(.system, "Missing input monitoring permission")
            return
        }

        // Initialize display manager
        let dm = DisplayManager.shared
        dm.onDisplayConfigChanged = {
            Log.info(.display, "Display configuration updated")
        }
        loadDisplayConfig()

        // Configure logging
        Log.configure(with: _config.logging)

        // Create touch handler
        let ctx = MultiTouchContext()
        touchHandler = TouchHandler(context: ctx)
        touchHandler?.updateConfig(_config)
        MacinTouchCore.globalTouchHandler = touchHandler

        // Start HID
        InitHIDNotifications(TOUCH_VID, TOUCH_PID) { element in
            MacinTouchCore.hidElementCallback(element)
        }

        status.isRunning = true
        status.errorMessage = nil
        Log.info(.system, "Touch driver started")
    }

    func stop() {
        touchHandler?.cancelGestures()
        StopHIDNotifications()
        touchHandler = nil
        MacinTouchCore.globalTouchHandler = nil
        status.isRunning = false
        status.deviceConnected = false
        Log.info(.system, "Touch driver stopped")
    }

    func restart() {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.start()
        }
    }

    func onStatusChange(_ handler: @escaping (DriverStatus) -> Void) {
        statusHandler = handler
    }

    // MARK: - Device Status

    func checkDeviceStatus() {
        let checker = DeviceChecker(config: config.device)
        let connected = checker.isDeviceConnected()
        if status.deviceConnected && !connected { touchHandler?.cancelGestures() }
        if status.deviceConnected != connected {
            status.deviceConnected = connected
        }

        // Re-check permissions
        status.hasAccessibilityPermission = AXIsProcessTrusted()
        status.hasInputMonitoringPermission =
            IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    // MARK: - Config Application

    private func applyConfig(_ cfg: DriverConfig) {
        Log.configure(with: cfg.logging)

        // Propagate to gesture recognizers
        touchHandler?.updateConfig(cfg)

        // Apply display config
        if cfg.display.isManualSelection && cfg.display.selectedDisplayID != 0 {
            DisplayManager.shared.selectDisplay(byID: cfg.display.selectedDisplayID)
        } else {
            DisplayManager.shared.setAutomaticDisplaySelection()
        }
    }

    private func loadDisplayConfig() {
        let dc = _config.display
        if dc.isManualSelection && dc.selectedDisplayID != 0 {
            DisplayManager.shared.selectDisplay(byID: dc.selectedDisplayID)
        } else {
            DisplayManager.shared.setAutomaticDisplaySelection()
        }
    }

    // MARK: - HID Callback

    private static var globalTouchHandler: TouchHandler?

    private static func hidElementCallback(_ element: UnsafeMutablePointer<HIDElement>?) {
        guard let element = element,
              let handler = globalTouchHandler else { return }
        handler.processHIDElement(element: element.pointee)
    }
}
