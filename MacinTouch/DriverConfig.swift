//
//  DriverConfig.swift
//  MacinTouch
//
//  Runtime-configurable driver settings.
//  Replaces the compile-time constants in Config.swift.
//  This struct is Codable for persistence and serves as the
//  communication contract between the driver and the GUI.
//

import Foundation

// MARK: - Driver Status

struct DriverStatus: Equatable {
    var isRunning: Bool = false
    var deviceConnected: Bool = false
    var hasAccessibilityPermission: Bool = false
    var hasInputMonitoringPermission: Bool = false
    var errorMessage: String? = nil

    var isFullyOperational: Bool {
        isRunning && deviceConnected && hasAccessibilityPermission && hasInputMonitoringPermission
    }
}

// MARK: - Touch Mode

enum TouchMode: String, Codable, CaseIterable, Equatable {
    case twoFingerScroll    // Default: single finger = mouse cursor, two finger = scroll
    case singleFingerScroll // Single finger = scroll, long press = drag/select, two finger tap = right click
}

// MARK: - Top-level Config

struct DriverConfig: Codable, Equatable {
    var device = DeviceConfig()
    var gestures = GestureConfig()
    var scroll = ScrollConfig()
    var pinch = PinchConfig()
    var fourFinger = FourFingerConfig()
    var logging = LogConfig()
    var display = DisplayConfig()

    static let `default` = DriverConfig()

    // MARK: Persistence

    static let configURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacinTouch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }()

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: DriverConfig.configURL, options: .atomic)
    }

    static func load() throws -> DriverConfig {
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(DriverConfig.self, from: data)
    }

    /// Load from disk, or return default if file doesn't exist.
    static func loadOrDefault() -> DriverConfig {
        (try? load()) ?? .default
    }
}

// MARK: - HID Cookie Mapping
//
// Describes how a specific device maps multi-touch data onto HID cookies.
// Each vendor uses a different cookie layout in their HID reports.
// Add a new HIDCookieMapping entry to DeviceProfile.knownDevices to support a new device.

struct HIDCookieMapping: Codable, Equatable {
    // Cookie for finger 0's X axis; finger N = xBase + N * fingerStride
    var xBase: Int32 = 43
    // Cookie for finger 0's Y axis; finger N = yBase + N * fingerStride
    var yBase: Int32 = 44
    // Stride between consecutive fingers' cookies (X and Y)
    var fingerStride: Int32 = 3
    // Cookie for finger 0's press button; finger N = pressBase + N
    var pressBase: Int32 = 27
    // Contact ID finger index = (cookie - contactIDBase) / contactIDStride
    var contactIDBase: Int32 = 17
    var contactIDStride: Int32 = 9
    // Cookie value to skip during coordinate processing
    var excludedCookie: Int32 = 0x73
}

// MARK: - Device Config

struct DeviceConfig: Codable, Equatable {
    var name: String = "ILITEK ILITEK-TP"
    var vendorID: Int32 = 0x222a
    var productID: Int32 = 0x0001
    var touchResolutionX: Double = 16382.0
    var touchResolutionY: Double = 9598.0
    var maxTouchPoints: Int = 10
    var reportSize: Int = 256
    var pressureThreshold: Int = 10
    var maxPressure: Int = 255
    var hidMapping: HIDCookieMapping = HIDCookieMapping()

    // Built-in device profiles. To add support for a new device:
    // 1. Determine its VID, PID, resolution, and HID cookie layout
    // 2. Add a new DeviceConfig entry here
    // 3. Rebuild — no other code changes needed
    static let knownDevices: [DeviceConfig] = [
        DeviceConfig()  // ILITEK ILITEK-TP (VID: 0x222a, PID: 0x0001)
    ]
}

// MARK: - Gesture Config

struct GestureConfig: Codable, Equatable {
    // Touch mode
    var touchMode: TouchMode = .twoFingerScroll

    // Timing
    var doubleClickDelay: TimeInterval = 0.25
    var contextMenuDelay: TimeInterval = 0.6
    var tapTimeout: TimeInterval = 0.1

    // Distance thresholds (pixels)
    var movementThreshold: Double = 15.0
    var dragThreshold: Double = 8.0

    // Delayed mouse-down
    var mouseDownDelay: TimeInterval = 0.05

    // Event filtering
    var eventFilterDuration: TimeInterval = 0.1
    var fourFingerProtectionDuration: TimeInterval = 0.3
    var rightClickProtectionDuration: TimeInterval = 0.5
}

// MARK: - Scroll Config

struct ScrollConfig: Codable, Equatable {
    var scrollThreshold: Double = 1.0
    var minFingerDistance: Double = 50.0
    var maxFingerDistance: Double = 500.0

    // Direct mapping
    var directMappingEnabled: Bool = true
    var invertY: Bool = true

    // Smoothing
    var smoothingEnabled: Bool = false
    var smoothingFactor: Double = 0.4
    var historySize: Int = 3
    var minDelta: Double = 0.5

    // Inertial scrolling
    var inertialEnabled: Bool = true
    var inertialMinVelocity: Double = 200.0
    var inertialDecayFactor: Double = 0.96
    var inertialMinSpeed: Double = 20.0
    var inertialFrameRate: Double = 60.0
    var inertialVelocityTimeWindow: Double = 0.06
    var inertialMinTimeInterval: Double = 0.016
    // Output distance gain only; does not alter velocity decay or stop time.
    // Optional so older saved configurations remain decodable; nil means 2x.
    var inertialDistanceMultiplier: Double?

    // Acceleration
    var accelerationEnabled: Bool = true
    var accelerationBoost: Double = 2.4
    var accelerationWindow: Double = 0.15
    var maxBoostFactor: Double = 2.6
    var minBoostFactor: Double = 0.5
}

// MARK: - Pinch Config

struct PinchConfig: Codable, Equatable {
    var enabled: Bool = true
    var threshold: Double = 3.0
    var scaleFactor: Double = 0.8
    var minDistance: Double = 30.0
    var maxDistance: Double = 600.0
}

// MARK: - Display Config

struct DisplayConfig: Codable, Equatable {
    var selectedDisplayID: UInt32 = 0
    var isManualSelection: Bool = false
    var autoStartEnabled: Bool = false
}

// MARK: - Four-Finger Config

struct FourFingerConfig: Codable, Equatable {
    // Optional for compatibility with existing config.json files.
    // nil enables native horizontal swipes on macOS 27; false uses shortcuts.
    var nativeHorizontalSwipe: Bool?
    // Four-contact contraction/expansion: Apps / Show Desktop on macOS 27.
    var nativePinchGesture: Bool?
    // Change in average finger spacing relative to its starting value for full progress.
    var dockPinchTravelRatio: Double?
    // Spread gets a longer animation travel than pinch-in (default 100% spacing change).
    var dockSpreadTravelRatio: Double?
    // nil enables native vertical gestures on macOS 27; false selects shortcuts.
    var nativeVerticalSwipe: Bool?
    // Fraction of the touch surface width for progress 1.0 (default 30%).
    var dockSwipeTravelFraction: Double?

    var enabled: Bool = true
    var minDistance: Double = 60.0
    var maxDistance: Double = 700.0
    var swipeThreshold: Double = 60.0
    var swipeMinVelocity: Double = 100.0
    var longPressDuration: TimeInterval = 0.6
    var longPressMaxMovement: Double = 40.0
    var detectionBuffer: TimeInterval = 0.15
    var swipeEarlyDetection: Double = 30.0
}
