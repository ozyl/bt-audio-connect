import Foundation
import IOBluetooth

final class BluetoothManager: NSObject {
    typealias ConnectionChangeHandler = (_ deviceName: String, _ connected: Bool) -> Void

    private var onConnectionChange: ConnectionChangeHandler?
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotification: IOBluetoothUserNotification?
    private var targetDeviceName = ""

    func startObserving(targetDeviceName: String, onConnectionChange: @escaping ConnectionChangeHandler) {
        stopObserving()

        self.targetDeviceName = targetDeviceName
        self.onConnectionChange = onConnectionChange

        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
        registerDisconnectNotification(for: targetDeviceName)
    }

    func stopObserving() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotification?.unregister()
        disconnectNotification = nil
        onConnectionChange = nil
        targetDeviceName = ""
    }

    func refreshTargetDevice(_ deviceName: String) {
        targetDeviceName = deviceName
        registerDisconnectNotification(for: deviceName)
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let name = device.name else { return }
        onConnectionChange?(name, true)
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let name = device.name else { return }
        onConnectionChange?(name, false)
    }

    private func registerDisconnectNotification(for deviceName: String) {
        disconnectNotification?.unregister()
        disconnectNotification = nil

        guard let device = device(named: deviceName) else { return }
        disconnectNotification = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:device:))
        )
    }

    func device(named targetName: String) -> IOBluetoothDevice? {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return nil
        }

        let normalizedTarget = targetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTarget.isEmpty else { return nil }

        return paired.first { device in
            guard let name = device.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                return false
            }
            return name == normalizedTarget
        }
    }

    func isConnected(deviceName: String) -> Bool {
        guard let device = device(named: deviceName) else { return false }
        return device.isConnected()
    }

    func connect(deviceName: String) -> String {
        guard let device = device(named: deviceName) else {
            return "未找到已配对设备「\(deviceName)」"
        }

        if device.isConnected() {
            return "设备已连接"
        }

        let result = device.openConnection()
        switch result {
        case kIOReturnSuccess:
            return "正在连接 \(device.name ?? deviceName)…"
        case kIOReturnBusy:
            return "蓝牙连接进行中"
        default:
            return "连接失败（错误码 \(result)）"
        }
    }

    func pairedDeviceNames() -> [String] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        return paired.compactMap(\.name).sorted()
    }

    func deviceConnectionSummary(for deviceName: String) -> String {
        guard device(named: deviceName) != nil else {
            return "未配对"
        }
        return isConnected(deviceName: deviceName) ? "已连接" : "未连接"
    }

    static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == rhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
