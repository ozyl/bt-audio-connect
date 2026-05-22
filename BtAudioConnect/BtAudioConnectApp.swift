import ServiceManagement
import SwiftUI

@main
struct BtAudioConnectApp: App {
    @StateObject private var configManager: ConfigManager
    @StateObject private var monitorService: MonitorService

    init() {
        let configManager = ConfigManager()
        _configManager = StateObject(wrappedValue: configManager)
        _monitorService = StateObject(wrappedValue: MonitorService(configManager: configManager))
    }

    var body: some Scene {
        MenuBarExtra("BtAudioConnect", systemImage: menuBarSymbol) {
            MenuBarView()
                .environmentObject(configManager)
                .environmentObject(monitorService)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(configManager)
                .environmentObject(monitorService)
        }
    }

    private var menuBarSymbol: String {
        configManager.config.enabled ? "headphones.circle.fill" : "headphones.circle"
    }
}

struct MenuBarView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var monitorService: MonitorService
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BtAudioConnect")
                .font(.headline)

            LabeledContent("目标设备") {
                Text(configManager.config.deviceName)
            }

            LabeledContent("状态") {
                Text(monitorService.statusText)
                    .multilineTextAlignment(.trailing)
            }

            Text(monitorService.lastAction)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Toggle("启用监听", isOn: Binding(
                get: { configManager.config.enabled },
                set: { enabled in
                    configManager.update { $0.enabled = enabled }
                    if enabled {
                        monitorService.start()
                    } else {
                        monitorService.stop()
                    }
                }
            ))

            Button("立即连接蓝牙") {
                monitorService.connectNow()
            }

            Button("打开设置…") {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("打开配置文件") {
                NSWorkspace.shared.open(URL(fileURLWithPath: configManager.configFilePath))
            }

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            monitorService.start()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var monitorService: MonitorService

    @State private var deviceName = ""
    @State private var fallbackInterval = 30.0
    @State private var connectCooldown = 10.0
    @State private var launchAtLogin = false

    private let bluetoothManager = BluetoothManager()

    var body: some View {
        Form {
            Section("蓝牙设备") {
                TextField("设备名称（与系统蓝牙列表一致）", text: $deviceName)

                if !pairedDevices.isEmpty {
                    Picker("已配对设备", selection: $deviceName) {
                        ForEach(pairedDevices, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }

                Text("当前状态：\(bluetoothManager.deviceConnectionSummary(for: deviceName))")
                    .foregroundStyle(.secondary)
            }

            Section("监听参数") {
                Stepper(value: $fallbackInterval, in: 15...300, step: 5) {
                    Text("兜底检查：\(Int(fallbackInterval)) 秒")
                }

                Text("音频播放与蓝牙状态变化会立即触发检查，此项仅作备用。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Stepper(value: $connectCooldown, in: 3...120, step: 1) {
                    Text("重连冷却：\(Int(connectCooldown)) 秒")
                }
            }

            Section("启动") {
                Toggle("登录时启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
            }

            Section {
                Button("保存") {
                    saveSettings()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 360)
        .onAppear {
            loadSettings()
        }
    }

    private var pairedDevices: [String] {
        bluetoothManager.pairedDeviceNames()
    }

    private func loadSettings() {
        let config = configManager.config
        deviceName = config.deviceName
        fallbackInterval = config.fallbackCheckIntervalSeconds
        connectCooldown = config.connectCooldownSeconds
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    private func saveSettings() {
        configManager.update { config in
            config.deviceName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
            config.fallbackCheckIntervalSeconds = fallbackInterval
            config.connectCooldownSeconds = connectCooldown
        }
        monitorService.start()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
        }
    }
}
