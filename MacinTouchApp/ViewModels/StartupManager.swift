//
//  StartupManager.swift
//  MacinTouch GUI
//
//  Manages auto-startup functionality using LaunchAgent
//

import SwiftUI
import ServiceManagement

class StartupManager: ObservableObject {
    @Published var isAutoStartEnabled = false
    
    private let launchAgentIdentifier = "com.ilitek.touchdriver.gui"
    private let launchAgentPlistName = "com.ilitek.touchdriver.gui.plist"
    
    func checkAutoStartStatus() {
        isAutoStartEnabled = isLaunchAgentInstalled()
    }
    
    func enableAutoStart() {
        guard !isAutoStartEnabled else { return }
        
        do {
            try installLaunchAgent()
            isAutoStartEnabled = true
        } catch {
            print("Failed to enable auto-start: \(error)")
            showAutoStartError(error)
        }
    }
    
    func disableAutoStart() {
        guard isAutoStartEnabled else { return }
        
        do {
            try removeLaunchAgent()
            isAutoStartEnabled = false
        } catch {
            print("Failed to disable auto-start: \(error)")
            showAutoStartError(error)
        }
    }
    
    // MARK: - LaunchAgent Management
    
    private func installLaunchAgent() throws {
        let plistContent = createLaunchAgentPlist()
        let launchAgentURL = getLaunchAgentURL()
        
        // Create LaunchAgents directory if it doesn't exist
        let launchAgentsDir = launchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        
        // Write plist file
        try plistContent.write(to: launchAgentURL, atomically: true, encoding: .utf8)
        
        // Load the launch agent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", launchAgentURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw StartupError.launchCtlFailed("Failed to load launch agent")
        }
    }
    
    private func removeLaunchAgent() throws {
        let launchAgentURL = getLaunchAgentURL()
        
        // Unload the launch agent if it's loaded
        let unloadProcess = Process()
        unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        unloadProcess.arguments = ["unload", launchAgentURL.path]
        
        try? unloadProcess.run()
        unloadProcess.waitUntilExit()
        
        // Remove the plist file
        try FileManager.default.removeItem(at: launchAgentURL)
    }
    
    private func isLaunchAgentInstalled() -> Bool {
        let launchAgentURL = getLaunchAgentURL()
        return FileManager.default.fileExists(atPath: launchAgentURL.path)
    }
    
    private func getLaunchAgentURL() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
            .appendingPathComponent(launchAgentPlistName)
    }
    
    private func createLaunchAgentPlist() -> String {
        guard let executablePath = Bundle.main.executableURL?.path else {
            return ""
        }
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(launchAgentIdentifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
            <key>LaunchOnlyOnce</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/ilitek-touchdriver-gui.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/ilitek-touchdriver-gui-error.log</string>
        </dict>
        </plist>
        """
    }
    
    private func showAutoStartError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Auto-Start Configuration Failed"
        alert.informativeText = """
        Failed to configure auto-start: \(error.localizedDescription)
        
        You may need to manually configure the application to start at login.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

enum StartupError: LocalizedError {
    case launchCtlFailed(String)
    case plistCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .launchCtlFailed(let message):
            return "Launch control failed: \(message)"
        case .plistCreationFailed(let message):
            return "Plist creation failed: \(message)"
        }
    }
}