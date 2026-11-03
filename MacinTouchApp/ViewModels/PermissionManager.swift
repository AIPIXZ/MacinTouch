//
//  PermissionManager.swift
//  MacinTouch GUI
//
//  Manages system permissions required for touch driver functionality
//

import SwiftUI
import AppKit
import ServiceManagement
import IOKit.hid

class PermissionManager: ObservableObject {
    @Published var hasAccessibilityPermission = false

    private static let bundleID = Bundle.main.bundleIdentifier ?? "com.ilitek.touchdriver.gui"

    func checkPermissions() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    // MARK: - Accessibility Permission

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Reset TCC entry for this app, then re-request.
    /// Fixes the issue where a rebuilt binary keeps a stale permission.
    func resetAndRequestPermission() {
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments = ["reset", "Accessibility", Self.bundleID]
        try? task.run()
        task.waitUntilExit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.requestAccessibilityPermission()
            self?.checkPermissions()
        }
    }

    /// Open System Settings at the Accessibility pane.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func restartApplication() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", bundlePath]

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            do {
                try task.run()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApplication.shared.terminate(nil)
                }
            } catch {
                print("Failed to restart: \(error)")
            }
        }
    }

    var allPermissionsGranted: Bool {
        return hasAccessibilityPermission
    }
}
