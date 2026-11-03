//
//  SettingsView.swift
//  MacinTouch GUI
//
//  Main settings interface with tabs for different configuration areas
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var touchDriverModel = MacinTouchModel()
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some View {
        TabView {
            // Permissions Tab
            PermissionsTabView(permissionManager: permissionManager)
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
            
            // Devices Tab
            DevicesTabView(touchDriverModel: touchDriverModel)
                .tabItem {
                    Label("Devices", systemImage: "display")
                }
            
            // Gestures Tab
            GesturesTabView(touchDriverModel: touchDriverModel)
                .tabItem {
                    Label("Gestures", systemImage: "hand.tap")
                }
            
            // Startup Tab
            StartupTabView()
                .tabItem {
                    Label("Startup", systemImage: "gear")
                }
            
            // About Tab
            AboutTabView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 500, minHeight: 420)
        .onAppear {
            permissionManager.checkPermissions()
            touchDriverModel.loadConfiguration()
        }
    }
}

struct PermissionsTabView: View {
    @ObservedObject var permissionManager: PermissionManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Enhanced Header Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Permissions")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("System access required for full functionality")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("MacinTouch requires specific system permissions to access hardware and simulate touch events. Grant these permissions to ensure optimal performance.")
                        .foregroundColor(.secondary)
                        .font(.callout)
                        .padding()
                        .background(.blue.opacity(0.05))
                        .cornerRadius(12)
                }
                
                VStack(spacing: 16) {
                    EnhancedPermissionCard(
                        icon: "accessibility",
                        title: "Accessibility Permission",
                        description: "Required to simulate mouse clicks, gestures, and keyboard shortcuts",
                        status: permissionManager.hasAccessibilityPermission,
                        action: permissionManager.resetAndRequestPermission
                    )

                    // Hint: restart required after granting
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Restart the app after granting permission for it to take effect.")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(.orange.opacity(0.08))
                    .cornerRadius(10)

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            permissionManager.checkPermissions()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            permissionManager.restartApplication()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "restart")
                                Text("Restart")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
        }
    }
}

struct DevicesTabView: View {
    @ObservedObject var touchDriverModel: MacinTouchModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Devices")
                .font(.title)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Connected Displays")
                    .font(.headline)
                
                ForEach(touchDriverModel.availableDisplays, id: \.id) { display in
                    DisplayRow(
                        display: display,
                        isSelected: display.id == touchDriverModel.selectedDisplay?.id,
                        onSelect: { touchDriverModel.selectDisplay(display) }
                    )
                }
                
                Divider()
                
                Text("Touch Devices")
                    .font(.headline)
                
                if touchDriverModel.deviceConnected {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "touchid")
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text(touchDriverModel.config.device.name)
                                    .fontWeight(.medium)
                                Text(String(format: "VID: 0x%04x, PID: 0x%04x", touchDriverModel.config.device.vendorID, touchDriverModel.config.device.productID))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("Connected")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("No compatible device detected")
                            .fontWeight(.medium)
                        Text("Please connect your touchscreen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Refresh") {
                            touchDriverModel.checkDeviceStatus()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct GesturesTabView: View {
    @ObservedObject var touchDriverModel: MacinTouchModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Enhanced Header Section with Save/Reset buttons
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gesture Configuration")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Customize touch gestures and sensitivity")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Save and Reset buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                touchDriverModel.resetToDefaults()
                            }) {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: {
                                touchDriverModel.saveConfiguration()
                            }) {
                                Label("Save", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!touchDriverModel.hasUnsavedChanges)
                        }
                    }
                    
                    // Unsaved changes indicator
                    if touchDriverModel.hasUnsavedChanges {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                            Text("You have unsaved changes")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    // Touch Mode section
                    EnhancedGroupBox(
                        title: "Touch Mode",
                        icon: "hand.draw.fill",
                        iconColor: .purple
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Mode", selection: $touchDriverModel.touchMode) {
                                Text("Two-Finger Scroll").tag(TouchMode.twoFingerScroll)
                                Text("Single-Finger Scroll").tag(TouchMode.singleFingerScroll)
                            }
                            .pickerStyle(.segmented)

                            if touchDriverModel.touchMode == .twoFingerScroll {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Default mode")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Single finger moves cursor, two fingers scroll, long press for right-click")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Single-finger scroll mode")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Single finger scrolls, long press to drag/select, two-finger tap for right-click")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // Enhanced Four-finger gestures section
                    EnhancedGroupBox(
                        title: "Four & Five-Finger Gestures",
                        icon: "hand.tap.fill",
                        iconColor: .blue
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            ModernToggleRow(
                                title: "Enable multi-finger gestures",
                                description: "Mission Control, desktop switching, Apps, and Show Desktop",
                                isOn: $touchDriverModel.fourFingerGesturesEnabled
                            )
                            
                            if touchDriverModel.fourFingerGesturesEnabled {
                                VStack(alignment: .leading, spacing: 12) {
                                    if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27 {
                                        ModernToggleRow(
                                            title: "Follow-finger swipes up and down",
                                            description: "Swipe up for Mission Control; down for App Exposé",
                                            isOn: $touchDriverModel.fourFingerNativeVerticalEnabled
                                        )
                                        ModernToggleRow(
                                            title: "Pinch for Apps & Show Desktop",
                                            description: "Pinch thumb and three or four fingers to open Apps; spread to show desktop",
                                            isOn: $touchDriverModel.fourFingerPinchEnabled
                                        )
                                        if touchDriverModel.fourFingerPinchEnabled {
                                            EnhancedSliderRow(
                                                title: "Pinch travel",
                                                description: "Required change in finger spacing; lower is more sensitive",
                                                value: $touchDriverModel.fourFingerPinchTravelRatio,
                                                range: 0.2...1.0,
                                                unit: "×"
                                            )
                                            EnhancedSliderRow(
                                                title: "Spread travel",
                                                description: "Animation travel for Show Desktop; higher takes more movement",
                                                value: $touchDriverModel.fourFingerSpreadTravelRatio,
                                                range: 0.4...2.0,
                                                unit: "×"
                                            )
                                        }
                                    }
                                    EnhancedSliderRow(
                                        title: "Minimum finger spacing",
                                        description: "Distance between fingers to detect gesture",
                                        value: $touchDriverModel.fourFingerMinDistance,
                                        range: 40...200,
                                        unit: "px"
                                    )
                                    
                                    EnhancedSliderRow(
                                        title: "Swipe threshold",
                                        description: "Minimum distance to trigger swipe",
                                        value: $touchDriverModel.fourFingerSwipeThreshold,
                                        range: 30...150,
                                        unit: "px"
                                    )
                                    
                                    EnhancedSliderRow(
                                        title: "Swipe velocity",
                                        description: "Minimum speed to detect swipe",
                                        value: $touchDriverModel.fourFingerSwipeVelocity,
                                        range: 50...500,
                                        unit: "px/s"
                                    )
                                }
                                .padding(.leading, 16)
                                .animation(.easeInOut(duration: 0.3), value: touchDriverModel.fourFingerGesturesEnabled)
                            }
                        }
                    }
                    
                    // Enhanced Pinch zoom section
                    EnhancedGroupBox(
                        title: "Pinch & Zoom",
                        icon: "magnifyingglass.circle.fill",
                        iconColor: .purple
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            ModernToggleRow(
                                title: "Enable pinch to zoom",
                                description: "Two-finger pinch to zoom in and out",
                                isOn: $touchDriverModel.pinchZoomEnabled
                            )
                            
                            if touchDriverModel.pinchZoomEnabled {
                                VStack(alignment: .leading, spacing: 12) {
                                    EnhancedSliderRow(
                                        title: "Pinch threshold",
                                        description: "Minimum distance change to trigger zoom",
                                        value: $touchDriverModel.pinchThreshold,
                                        range: 10...50,
                                        unit: "px"
                                    )
                                    
                                    EnhancedSliderRow(
                                        title: "Scale factor",
                                        description: "Zoom sensitivity multiplier",
                                        value: $touchDriverModel.pinchScaleFactor,
                                        range: 0.1...1.0,
                                        unit: "×"
                                    )
                                }
                                .padding(.leading, 16)
                                .animation(.easeInOut(duration: 0.3), value: touchDriverModel.pinchZoomEnabled)
                            }
                        }
                    }
                    
                    // Enhanced Scrolling section
                    EnhancedGroupBox(
                        title: "Scrolling",
                        icon: "scroll.fill",
                        iconColor: .green
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            ModernToggleRow(
                                title: "Enable smooth scrolling",
                                description: "Fluid scrolling with momentum",
                                isOn: $touchDriverModel.smoothScrollingEnabled
                            )
                            
                            ModernToggleRow(
                                title: "Natural scroll direction",
                                description: "Scroll content in direction of finger movement",
                                isOn: $touchDriverModel.scrollInvertY
                            )
                            
                            if touchDriverModel.smoothScrollingEnabled {
                                EnhancedSliderRow(
                                    title: "Smoothing factor",
                                    description: "Higher values create more fluid scrolling",
                                    value: $touchDriverModel.scrollSmoothingFactor,
                                    range: 0.1...1.0,
                                    unit: ""
                                )
                                .padding(.leading, 16)
                                .animation(.easeInOut(duration: 0.3), value: touchDriverModel.smoothScrollingEnabled)
                            }
                        }
                    }
                    
                    // Enhanced Right-click section
                    EnhancedGroupBox(
                        title: "Right-Click",
                        icon: "cursorarrow.click.2",
                        iconColor: .orange
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            EnhancedSliderRow(
                                title: "Long press duration",
                                description: "Time required to trigger right-click",
                                value: $touchDriverModel.rightClickDelay,
                                range: 0.3...1.5,
                                unit: "s"
                            )
                            
                            EnhancedSliderRow(
                                title: "Movement threshold",
                                description: "Maximum movement allowed during long press",
                                value: $touchDriverModel.movementThreshold,
                                range: 5...30,
                                unit: "px"
                            )
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct StartupTabView: View {
    @StateObject private var startupManager = StartupManager()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "power")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Startup")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                Toggle("Launch at Login", isOn: $startupManager.isAutoStartEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: startupManager.isAutoStartEnabled) { newValue in
                        if newValue {
                            startupManager.enableAutoStart()
                        } else {
                            startupManager.disableAutoStart()
                        }
                    }

                if startupManager.isAutoStartEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The touch driver will start automatically when you log in.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Note: Accessibility and Input Monitoring permissions are required.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.08))
                    .cornerRadius(10)
                }
            }
            .frame(maxWidth: 320)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .onAppear {
            startupManager.checkAutoStartStatus()
        }
    }
}

struct AboutTabView: View {
    @State private var logoAnimation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Enhanced Logo Section
                VStack(spacing: 20) {
                    ZStack {
                        // Background gradient circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.2), .purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .scaleEffect(logoAnimation ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: logoAnimation)
                        
                        // Main icon
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(logoAnimation ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: logoAnimation)
                    }
                    
                    VStack(spacing: 8) {
                        Text("MacinTouch")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.primary, .secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        HStack(spacing: 12) {
                            Text("Version 1.0.0")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("•")
                                .foregroundColor(.secondary)
                            
                            Text("macOS Native")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Enhanced Features Section
                VStack(alignment: .leading, spacing: 20) {
                    Text("A powerful native macOS driver for USB touchscreen devices, bringing intuitive multi-touch gestures to your workflow.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("✨ Supported Features")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 12) {
                            FeatureCard(icon: "hand.tap.fill", title: "Four & Five-Finger Gestures", description: "Mission Control & Spaces")
                            FeatureCard(icon: "magnifyingglass.circle.fill", title: "Pinch to Zoom", description: "Natural zoom controls")
                            FeatureCard(icon: "scroll.fill", title: "Smooth Scrolling", description: "Fluid scrolling experience")
                            FeatureCard(icon: "cursorarrow.click.2", title: "Right-Click Support", description: "Long-press gestures")
                        }
                    }
                }
                
                // System Requirements & Device Info
                VStack(spacing: 16) {
                    Divider()
                    
                    VStack(spacing: 12) {
                        Text("System Requirements")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            InfoRow(label: "Supported Device:", value: DeviceConfig.knownDevices.map(\.name).joined(separator: ", "))
                            InfoRow(label: "Protocol:", value: "USB HID Digitizer")
                            InfoRow(label: "macOS Version:", value: "10.15+ (Catalina or later)")
                            InfoRow(label: "Architecture:", value: "Apple Silicon & Intel")
                        }
                    }
                }
                
                // Footer
                VStack(spacing: 8) {
                    Text("© 2024 MacinTouch Project")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Built with ❤️ for the macOS community")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 24)
            }
            .padding()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).delay(0.2)) {
                logoAnimation = true
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(height: 24)
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// Helper Views
struct PermissionRow: View {
    let title: String
    let description: String
    let status: Bool
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if status {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Granted")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct DisplayRow: View {
    let display: DisplayInfo
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            // Display icon
            Image(systemName: display.isPrimary ? "display" : "externaldrive.connected.to.line.below")
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(display.name)
                        .fontWeight(.medium)
                    if display.isPrimary {
                        Text("Primary")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 8) {
                    Text("\(display.width) × \(display.height)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("ID: \(display.id)")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Touch Target")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                } else {
                    Button("Select") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? .blue.opacity(0.3) : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Enhanced UI Components

struct EnhancedPermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let status: Bool
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon Section
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(status ? .green.opacity(0.15) : .orange.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(status ? .green : .orange)
            }
            
            // Content Section
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Status/Action Section
            if status {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("Granted")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            } else {
                Button(action: action) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                            .font(.caption)
                        Text("Grant")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(status ? .green.opacity(0.3) : .orange.opacity(0.3), lineWidth: 1.5)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: status)
    }
}

struct EnhancedGroupBox<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content
    
    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.separator.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ModernToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isOn ? .primary : .secondary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .scaleEffect(0.9)
        }
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

struct EnhancedSliderRow: View {
    let title: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(formatValue(value))\(unit)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Slider(value: $value, in: range) {
                Text(title)
            } minimumValueLabel: {
                Text("\(formatValue(range.lowerBound))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } maximumValueLabel: {
                Text("\(formatValue(range.upperBound))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .tint(.blue)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
    
    private func formatValue(_ val: Double) -> String {
        if unit == "s" || unit == "×" || unit == "" {
            return String(format: "%.1f", val)
        } else {
            return "\(Int(val))"
        }
    }
}

struct SliderSettingRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                Spacer()
                Text("\(Int(value))\(unit)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: range)
                .accentColor(.blue)
        }
    }
}

#Preview {
    SettingsView()
}