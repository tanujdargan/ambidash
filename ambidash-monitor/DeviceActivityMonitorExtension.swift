// ambidash-monitor/DeviceActivityMonitorExtension.swift
import DeviceActivity
import ManagedSettings
import Foundation

class AmbidashDeviceActivityMonitor: DeviceActivityMonitor {
    let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
    }

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
    }
}
