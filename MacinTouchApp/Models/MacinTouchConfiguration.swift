//
//  MacinTouchConfiguration.swift
//  MacinTouch GUI
//
//  Legacy configuration manager for display selection.
//  Configuration data is now managed by DriverConfig.
//

import Foundation
import CoreGraphics

/// Backward-compatible shim. New code should use DriverConfig directly.
class ConfigurationManager {
    static let shared = ConfigurationManager()
    private init() {}

    // MARK: - Display Configuration (delegates to DriverConfig.display)

    func saveDisplaySelection(displayID: CGDirectDisplayID, isManual: Bool) {
        var cfg = MacinTouchCore.shared.config
        cfg.display.selectedDisplayID = displayID
        cfg.display.isManualSelection = isManual
        MacinTouchCore.shared.config = cfg
    }

    func loadAndApplyDisplayConfiguration() {
        let dc = MacinTouchCore.shared.config.display
        if dc.isManualSelection && dc.selectedDisplayID != 0 {
            DisplayManager.shared.selectDisplay(byID: dc.selectedDisplayID)
        } else {
            DisplayManager.shared.setAutomaticDisplaySelection()
        }
    }
}
