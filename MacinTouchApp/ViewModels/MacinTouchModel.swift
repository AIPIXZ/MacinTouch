//
//  MacinTouchModel.swift
//  MacinTouch GUI
//
//  Observable model exposing driver state and configuration to SwiftUI.
//

import SwiftUI
import Combine

class MacinTouchModel: ObservableObject {
    // MARK: - Driver Status
    @Published var status = DriverStatus()

    // MARK: - Display
    @Published var availableDisplays: [DisplayInfo] = []
    @Published var selectedDisplay: DisplayInfo?

    // MARK: - Editable Config (two-way bound to UI controls)
    @Published var config: DriverConfig

    // MARK: - Change Tracking
    @Published var hasUnsavedChanges = false

    private var savedConfig: DriverConfig
    private let driver: MacinTouchCore
    private var cancellables = Set<AnyCancellable>()

    init(driver: MacinTouchCore = .shared) {
        self.driver = driver
        let loaded = driver.config
        self.config = loaded
        self.savedConfig = loaded

        driver.onStatusChange { [weak self] newStatus in
            DispatchQueue.main.async { self?.status = newStatus }
        }

        startStatusPolling()
        setupChangeTracking()
    }

    // MARK: - Convenience Properties (bridge for existing views)

    var isDriverActive: Bool { status.isRunning && status.deviceConnected }
    var deviceConnected: Bool { status.deviceConnected }
    var displayInfo: DisplayInfo? { selectedDisplay }

    // Four-finger
    var fourFingerGesturesEnabled: Bool {
        get { config.fourFinger.enabled }
        set { config.fourFinger.enabled = newValue }
    }
    var fourFingerPinchEnabled: Bool {
        get { config.fourFinger.nativePinchGesture != false }
        set { config.fourFinger.nativePinchGesture = newValue }
    }
    var fourFingerPinchTravelRatio: Double {
        get { config.fourFinger.dockPinchTravelRatio ?? 0.60 }
        set { config.fourFinger.dockPinchTravelRatio = newValue }
    }
    var fourFingerSpreadTravelRatio: Double {
        get { config.fourFinger.dockSpreadTravelRatio ?? 1.0 }
        set { config.fourFinger.dockSpreadTravelRatio = newValue }
    }
    var fourFingerNativeVerticalEnabled: Bool {
        get { config.fourFinger.nativeVerticalSwipe != false }
        set { config.fourFinger.nativeVerticalSwipe = newValue }
    }
    var fourFingerMinDistance: Double {
        get { config.fourFinger.minDistance }
        set { config.fourFinger.minDistance = newValue }
    }
    var fourFingerSwipeThreshold: Double {
        get { config.fourFinger.swipeThreshold }
        set { config.fourFinger.swipeThreshold = newValue }
    }
    var fourFingerSwipeVelocity: Double {
        get { config.fourFinger.swipeMinVelocity }
        set { config.fourFinger.swipeMinVelocity = newValue }
    }

    // Pinch
    var pinchZoomEnabled: Bool {
        get { config.pinch.enabled }
        set { config.pinch.enabled = newValue }
    }
    var pinchThreshold: Double {
        get { config.pinch.threshold }
        set { config.pinch.threshold = newValue }
    }
    var pinchScaleFactor: Double {
        get { config.pinch.scaleFactor }
        set { config.pinch.scaleFactor = newValue }
    }

    // Scroll
    var smoothScrollingEnabled: Bool {
        get { config.scroll.smoothingEnabled }
        set { config.scroll.smoothingEnabled = newValue }
    }
    var scrollSmoothingFactor: Double {
        get { config.scroll.smoothingFactor }
        set { config.scroll.smoothingFactor = newValue }
    }
    var scrollInvertY: Bool {
        get { config.scroll.invertY }
        set { config.scroll.invertY = newValue }
    }

    // Touch mode
    var touchMode: TouchMode {
        get { config.gestures.touchMode }
        set { config.gestures.touchMode = newValue }
    }

    // Single touch
    var rightClickDelay: Double {
        get { config.gestures.contextMenuDelay }
        set { config.gestures.contextMenuDelay = newValue }
    }
    var movementThreshold: Double {
        get { config.gestures.movementThreshold }
        set { config.gestures.movementThreshold = newValue }
    }

    // MARK: - Device

    func checkDeviceStatus() {
        driver.checkDeviceStatus()
        status = driver.status
        refreshDisplays()
    }

    func refreshDisplays() {
        let dm = DisplayManager.shared
        availableDisplays = dm.getAvailableDisplays()
        selectedDisplay = dm.getCurrentSelectedDisplay()
    }

    func selectDisplay(_ display: DisplayInfo) {
        selectedDisplay = display
        DisplayManager.shared.selectDisplay(display)
        config.display.selectedDisplayID = display.id
        config.display.isManualSelection = true
    }

    func restartDriver() {
        driver.restart()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkDeviceStatus()
        }
    }

    func restartApplication() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", bundlePath]
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            try? task.run()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    // MARK: - Configuration

    func saveConfiguration() {
        driver.config = config
        savedConfig = config
        hasUnsavedChanges = false
    }

    func loadConfiguration() {
        config = driver.config
        savedConfig = config
        hasUnsavedChanges = false
    }

    func discardChanges() {
        config = savedConfig
        hasUnsavedChanges = false
    }

    /// Called "resetConfiguration" by existing views — revert to last saved.
    func resetConfiguration() {
        discardChanges()
    }

    func resetToDefaults() {
        config = .default
        hasUnsavedChanges = true
    }

    /// No longer needed — change tracking is automatic. Kept for view compat.
    func manuallyTriggerChangeDetection() {
        hasUnsavedChanges = config != savedConfig
    }

    // MARK: - Private

    private func startStatusPolling() {
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.checkDeviceStatus() }
            .store(in: &cancellables)
    }

    private func setupChangeTracking() {
        $config
            .dropFirst()
            .sink { [weak self] newConfig in
                guard let self else { return }
                self.hasUnsavedChanges = newConfig != self.savedConfig
            }
            .store(in: &cancellables)
    }
}
