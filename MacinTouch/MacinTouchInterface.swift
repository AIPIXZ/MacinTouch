//
//  MacinTouchInterface.swift
//  MacinTouch
//
//  Protocol defining the contract between driver and GUI.
//  For v1 the GUI embeds the driver in-process;
//  the protocol allows future IPC separation.
//

import Foundation

protocol MacinTouchInterface: AnyObject {
    /// Current driver status (running, permissions, device state).
    var status: DriverStatus { get }

    /// Current driver configuration. Setting applies changes immediately.
    var config: DriverConfig { get set }

    /// Start the driver (HID manager, touch handler).
    func start()

    /// Stop the driver and release resources.
    func stop()

    /// Stop then start again.
    func restart()

    /// Register a callback for status changes.
    func onStatusChange(_ handler: @escaping (DriverStatus) -> Void)
}
