//
//  SettingsWindowView.swift
//  MacinTouch GUI
//
//  Wrapper view for settings window to prevent tab switching issues
//

import SwiftUI
import AppKit

struct SettingsWindowView: View {
    @StateObject private var touchDriverModel = MacinTouchModel()
    @StateObject private var permissionManager = PermissionManager()
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            HStack(spacing: 20) {
                TabButton(title: "Permissions", icon: "lock.shield", index: 0, selectedTab: $selectedTab)
                TabButton(title: "Devices", icon: "display", index: 1, selectedTab: $selectedTab)
                TabButton(title: "Gestures", icon: "hand.tap", index: 2, selectedTab: $selectedTab)
                TabButton(title: "Startup", icon: "gear", index: 3, selectedTab: $selectedTab)
                TabButton(title: "About", icon: "info.circle", index: 4, selectedTab: $selectedTab)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Tab content
            Group {
                switch selectedTab {
                case 0:
                    PermissionsTabView(permissionManager: permissionManager)
                case 1:
                    DevicesTabView(touchDriverModel: touchDriverModel)
                case 2:
                    GesturesTabView(touchDriverModel: touchDriverModel)
                case 3:
                    StartupTabView()
                case 4:
                    AboutTabView()
                default:
                    PermissionsTabView(permissionManager: permissionManager)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
        .frame(minWidth: 500, minHeight: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            permissionManager.checkPermissions()
            touchDriverModel.loadConfiguration()
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let index: Int
    @Binding var selectedTab: Int
    @State private var isHovered = false

    var body: some View {
        Button(action: { selectedTab = index }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selectedTab == index ? .blue : .secondary)
            .frame(minWidth: 70, minHeight: 50)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == index ? Color.blue.opacity(0.1) :
                          isHovered ? Color.secondary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in isHovered = hovering }
    }
}

#Preview {
    SettingsWindowView()
}