//
//  TouchDriverGUIApp.swift
//  MacinTouch GUI
//
//  Main SwiftUI App entry point with menu bar integration
//

import SwiftUI
import AppKit
import ApplicationServices

@main
struct TouchDriverGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settingsWindow: NSWindow?

    var body: some Scene {
        MenuBarExtra("MacinTouch", systemImage: "hand.tap") {
            MenuBarView(settingsWindow: $settingsWindow)
                .frame(width: 340, height: 380)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityPermission()
        MacinTouchCore.shared.start()
    }

    /// Reset stale TCC entry (handles rebuilt binary), then request permission.
    /// Same logic as PermissionManager.resetAndRequestPermission().
    private func requestAccessibilityPermission() {
        guard !AXIsProcessTrusted() else { return }

        // Clear any stale TCC entry for this bundle ID
        let bundleID = Bundle.main.bundleIdentifier ?? "com.ilitek.touchdriver.gui"
        let task = Process()
        task.launchPath = "/usr/bin/tccutil"
        task.arguments = ["reset", "Accessibility", bundleID]
        try? task.run()
        task.waitUntilExit()

        // Show system permission dialog
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func applicationWillTerminate(_ notification: Notification) {
        MacinTouchCore.shared.stop()
    }
}
