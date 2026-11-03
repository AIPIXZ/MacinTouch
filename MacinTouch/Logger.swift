//
//  Logger.swift
//  MacinTouch
//
//  Structured logging system replacing scattered debug print statements
//

import Foundation

// MARK: - Log Level

enum LogLevel: Int, Comparable, Codable, CaseIterable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var prefix: String {
        switch self {
        case .debug:   return "[DEBUG]"
        case .info:    return "[INFO]"
        case .warning: return "[WARN]"
        case .error:   return "[ERROR]"
        }
    }
}

// MARK: - Log Category

enum LogCategory: String, Codable, CaseIterable {
    case hid            // HID device and parsing
    case gesture        // General gesture state
    case singleTouch    // Single-finger: tap, drag, right-click
    case scroll         // Two-finger scroll
    case pinch          // Two-finger pinch zoom
    case fourFinger     // Four-finger gestures
    case coordinates    // Coordinate system conversions
    case mouse          // Mouse event simulation and tracking
    case display        // Display configuration
    case system         // Startup, permissions, signals
}

// MARK: - Logger

struct Log {
    /// Current minimum log level. Messages below this level are discarded.
    static var level: LogLevel = .info

    /// Only messages in enabled categories are printed.
    /// Empty set means ALL categories are enabled.
    static var enabledCategories: Set<LogCategory> = []

    /// Quick check: is a given level+category enabled?
    @inline(__always)
    static func isEnabled(_ lvl: LogLevel, _ cat: LogCategory) -> Bool {
        guard lvl >= level else { return false }
        if !enabledCategories.isEmpty && !enabledCategories.contains(cat) {
            return false
        }
        return true
    }

    /// Primary logging entry point.
    /// The message is an @autoclosure so it's not evaluated when logging is off.
    static func log(_ lvl: LogLevel, _ cat: LogCategory, _ message: @autoclosure () -> String) {
        guard isEnabled(lvl, cat) else { return }
        let timestamp = String(format: "%.3f",
            Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 10000))
        print("\(timestamp) \(lvl.prefix) [\(cat.rawValue)] \(message())")
        // Keep diagnostics visible immediately when stdout is piped through tee.
        fflush(stdout)
    }

    // MARK: Convenience

    static func debug(_ cat: LogCategory, _ message: @autoclosure () -> String) {
        log(.debug, cat, message())
    }

    static func info(_ cat: LogCategory, _ message: @autoclosure () -> String) {
        log(.info, cat, message())
    }

    static func warn(_ cat: LogCategory, _ message: @autoclosure () -> String) {
        log(.warning, cat, message())
    }

    static func error(_ cat: LogCategory, _ message: @autoclosure () -> String) {
        log(.error, cat, message())
    }

    // MARK: Configuration

    /// Configure logging from a LogConfig struct (typically loaded from DriverConfig).
    static func configure(with config: LogConfig) {
        level = config.level
        enabledCategories = config.enabledCategories
    }

    /// Configure from the legacy debug flags (used during migration).
    static func configureFromLegacy() {
        level = DEBUG_ENABLED ? .debug : .info

        var cats: Set<LogCategory> = []
        if DEBUG_TOUCH_EVENTS { cats.insert(.singleTouch) }
        if DEBUG_COORDINATES { cats.insert(.coordinates) }
        if DEBUG_GESTURES { cats.insert(.gesture) }
        if DEBUG_HID_PARSING { cats.insert(.hid) }
        if DEBUG_SCROLL { cats.insert(.scroll) }
        if DEBUG_FOUR_FINGER || DEBUG_FOUR_FINGER_VERBOSE { cats.insert(.fourFinger) }
        if DEBUG_PINCH { cats.insert(.pinch) }
        if DEBUG_MOUSE_TRACKING { cats.insert(.mouse) }
        if DEBUG_DOUBLE_CLICK || DEBUG_RIGHT_CLICK_DETAIL { cats.insert(.singleTouch) }
        if DEBUG_FINGER_COUNT { cats.insert(.gesture) }

        // If no specific categories selected, enable all (legacy behavior with DEBUG_ENABLED)
        enabledCategories = cats
    }
}

// MARK: - Log Config (Codable, for persistence)

struct LogConfig: Codable, Equatable {
    var level: LogLevel = .info
    var enabledCategories: Set<LogCategory> = []

    static let `default` = LogConfig()

    static let debug = LogConfig(
        level: .debug,
        enabledCategories: []  // empty = all categories
    )
}
