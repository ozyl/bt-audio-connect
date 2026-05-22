import Foundation

@MainActor
final class MonitorService: ObservableObject {
    @Published private(set) var statusText = "等待音频播放"
    @Published private(set) var lastAction = "尚未执行操作"

    private let configManager: ConfigManager
    private let audioMonitor = AudioMonitor()
    private let bluetoothManager = BluetoothManager()

    private var fallbackTimer: Timer?
    private var isAudioPlaying = false
    private var lastConnectAttempt: Date?

    init(configManager: ConfigManager) {
        self.configManager = configManager
    }

    func start() {
        stop()
        configManager.reload()

        guard configManager.config.enabled else {
            statusText = "已暂停"
            return
        }

        audioMonitor.start { [weak self] playing in
            Task { @MainActor in
                self?.handleAudioPlayingChanged(playing)
            }
        }

        bluetoothManager.startObserving(targetDeviceName: configManager.config.deviceName) { [weak self] deviceName, connected in
            Task { @MainActor in
                self?.handleBluetoothConnectionChanged(deviceName: deviceName, connected: connected)
            }
        }

        scheduleFallbackTimer()
        isAudioPlaying = audioMonitor.currentIsPlaying()
        updateStatusText()
        evaluateConnectionIfNeeded(trigger: "启动检查")
    }

    func stop() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        audioMonitor.stop()
        bluetoothManager.stopObserving()
    }

    private func scheduleFallbackTimer() {
        let interval = max(configManager.config.fallbackCheckIntervalSeconds, 15)
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performFallbackCheck()
            }
        }
        if let fallbackTimer {
            RunLoop.main.add(fallbackTimer, forMode: .common)
        }
    }

    private func performFallbackCheck() {
        configManager.reload()
        guard configManager.config.enabled else {
            statusText = "已暂停"
            return
        }

        isAudioPlaying = audioMonitor.currentIsPlaying()
        updateStatusText()
        evaluateConnectionIfNeeded(trigger: "兜底检查")
    }

    private func handleAudioPlayingChanged(_ playing: Bool) {
        configManager.reload()
        guard configManager.config.enabled else { return }

        isAudioPlaying = playing
        updateStatusText()

        if playing {
            evaluateConnectionIfNeeded(trigger: "音频开始播放")
        }
    }

    private func handleBluetoothConnectionChanged(deviceName: String, connected: Bool) {
        configManager.reload()
        guard configManager.config.enabled else { return }
        guard BluetoothManager.namesMatch(deviceName, configManager.config.deviceName) else { return }

        updateStatusText()

        if !connected, isAudioPlaying {
            evaluateConnectionIfNeeded(trigger: "蓝牙断开")
        } else if connected {
            lastAction = "设备已连接"
        }
    }

    private func evaluateConnectionIfNeeded(trigger: String) {
        guard configManager.config.enabled else { return }
        guard isAudioPlaying else { return }

        let deviceName = configManager.config.deviceName

        if bluetoothManager.isConnected(deviceName: deviceName) {
            lastAction = "设备已连接，无需操作"
            return
        }

        let now = Date()
        if let lastConnectAttempt,
           now.timeIntervalSince(lastConnectAttempt) < configManager.config.connectCooldownSeconds {
            return
        }

        lastConnectAttempt = now
        let message = bluetoothManager.connect(deviceName: deviceName)
        lastAction = "[\(trigger)] \(message)"
        updateStatusText()
    }

    private func updateStatusText() {
        let deviceName = configManager.config.deviceName
        let connectionState = bluetoothManager.deviceConnectionSummary(for: deviceName)

        if !configManager.config.enabled {
            statusText = "已暂停 · \(deviceName) \(connectionState)"
        } else if isAudioPlaying {
            statusText = "检测到音频播放 · \(deviceName) \(connectionState)"
        } else {
            statusText = "等待音频播放 · \(deviceName) \(connectionState)"
        }
    }

    func connectNow() {
        let deviceName = configManager.config.deviceName
        lastConnectAttempt = Date()
        lastAction = bluetoothManager.connect(deviceName: deviceName)
        updateStatusText()
    }
}
