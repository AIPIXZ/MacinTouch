//
//  MenuBarView.swift
//  MacinTouch GUI
//
//  Menu bar dropdown view with quick controls and status
//

import SwiftUI
import AppKit

struct MenuBarView: View {
    @StateObject private var touchDriverModel = MacinTouchModel()
    @Binding var settingsWindow: NSWindow?
    @State private var isSettingsHovered = false
    @State private var isCloseHovered = false
    @State private var isQuitHovered = false
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 14) {
            // Header
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.tap.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)

                            Text("MacinTouch")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.primary, .secondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }

                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(touchDriverModel.isDriverActive ? .green.opacity(0.3) : .red.opacity(0.3))
                                    .frame(width: 16, height: 16)
                                    .scaleEffect(touchDriverModel.isDriverActive && pulseAnimation ? 1.3 : 1.0)
                                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)

                                Circle()
                                    .fill(touchDriverModel.isDriverActive ? .green : .red)
                                    .frame(width: 8, height: 8)
                            }

                            if touchDriverModel.isDriverActive {
                                Text("Active & Running")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            } else {
                                Text("Inactive")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)

                                if !touchDriverModel.status.hasAccessibilityPermission {
                                    Button(action: {
                                        openSettingsWindow()
                                        closeMenuBarWindow()
                                    }) {
                                        Text("Grant Permission →")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.blue)
                                } else if !touchDriverModel.status.isRunning {
                                    Button(action: {
                                        touchDriverModel.restartApplication()
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.caption2)
                                            Text("Restart")
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                        }
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.orange)
                                }
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: {
                            openSettingsWindow()
                            closeMenuBarWindow()
                        }) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(isSettingsHovered ? .blue : .secondary)
                                .scaleEffect(isSettingsHovered ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .help("Settings")
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSettingsHovered = hovering
                            }
                        }

                        Button(action: {
                            closeMenuBarWindow()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(isCloseHovered ? .primary : .secondary)
                                .scaleEffect(isCloseHovered ? 1.1 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .help("Close")
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isCloseHovered = hovering
                            }
                        }
                    }
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .blue.opacity(0.3), .purple.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }

            // Device Status
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "touchid")
                        .font(.title3)
                        .foregroundColor(.blue)

                    Text("Device Status")
                        .font(.headline)
                        .fontWeight(.semibold)
                }

                VStack(spacing: 8) {
                    EnhancedDeviceStatusCard(
                        icon: "touchid",
                        title: touchDriverModel.config.device.name,
                        status: touchDriverModel.deviceConnected ? "Connected" : "Not Found",
                        isConnected: touchDriverModel.deviceConnected,
                        details: touchDriverModel.deviceConnected ? String(format: "VID: 0x%04x, PID: 0x%04x", touchDriverModel.config.device.vendorID, touchDriverModel.config.device.productID) : "Please connect device"
                    )

                    if let displayInfo = touchDriverModel.displayInfo {
                        EnhancedDeviceStatusCard(
                            icon: "display",
                            title: "Target Display",
                            status: "\(displayInfo.width) x \(displayInfo.height)",
                            isConnected: true,
                            details: displayInfo.name
                        )
                    }
                }
            }

            // Touch Mode Quick Toggle
            Divider()

            // Spacer()
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                ZStack {
                    // Circle()
                    //     .fill(Color.purple.opacity(0.12))
                    //     .frame(width: 32, height: 32)
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                        .offset(x: 1)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Single-Finger Scroll")
                        .font(.headline)
                        .fontWeight(.medium)
                    Text(touchDriverModel.touchMode == .singleFingerScroll
                         ? "Swipe=scroll · Long Press=select\nTwo Finger Tap=menu"
                         : "Two ingers to scroll\n")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)                // 允许无限行数
                        .fixedSize(horizontal: false, vertical: true) // 强制垂直展开，不压缩成省略号
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { touchDriverModel.touchMode == .singleFingerScroll },
                    set: { enabled in
                        touchDriverModel.touchMode = enabled ? .singleFingerScroll : .twoFingerScroll
                        touchDriverModel.saveConfiguration()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            // Spacer()

            // Bottom quit button
            Divider()
                .padding(.horizontal, -18)

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.caption)
                    Text("Quit MacinTouch")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(isQuitHovered ? .red : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isQuitHovered = hovering
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            touchDriverModel.checkDeviceStatus()
            withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
                pulseAnimation = true
            }
        }
    }

    private func openSettingsWindow() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "MacinTouch Settings"
            window.contentView = NSHostingView(rootView: SettingsWindowView())
            window.minSize = NSSize(width: 500, height: 420)
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeMenuBarWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApp.windows {
                if window.level == NSWindow.Level.popUpMenu ||
                   window.className.contains("MenuBarExtra") ||
                   window.className.contains("StatusItem") {
                    window.orderOut(nil)
                    break
                }
            }
        }
    }
}

// MARK: - Components

struct EnhancedDeviceStatusCard: View {
    let icon: String
    let title: String
    let status: String
    let isConnected: Bool
    let details: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isConnected ? .green.opacity(0.15) : .orange.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isConnected ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(details)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(isConnected ? .green : .orange)
                    .frame(width: 6, height: 6)

                Text(status)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isConnected ? .green : .orange)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isConnected ? .green.opacity(0.4) : .orange.opacity(0.4), lineWidth: 1)
                )
        )
    }
}


#Preview {
    MenuBarView(settingsWindow: .constant(nil))
        .frame(width: 320, height: 310)
}
