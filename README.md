# BtAudioConnect

macOS 菜单栏小工具：当系统开始播放音频时，自动检查目标蓝牙设备是否已连接；若未连接，则尝试连接。

适用于「电脑扬声器在播，但蓝牙耳机/音箱没连上」的场景。

## 功能

- 监听系统音频播放状态（Core Audio 回调）
- 监听蓝牙连接/断开（IOBluetooth 通知）
- 播放音频且目标设备未连接时，自动发起连接
- 菜单栏查看状态、手动连接、开关监听
- 支持登录时启动

## 系统要求

- macOS 14.0 或更高版本
- Xcode Command Line Tools（含 `swiftc`）
- 目标蓝牙设备需已在「系统设置 → 蓝牙」中完成配对

## 构建与运行

```bash
git clone https://github.com/ozyl/bt-audio-connect.git
cd bt-audio-connect
./build.sh
open build/BtAudioConnect.app
```

首次运行可能需要在「系统设置 → 隐私与安全性 → 蓝牙」中授予权限。

## 配置

点击菜单栏耳机图标 → **打开设置**，或编辑配置文件：

```
~/Library/Application Support/BtAudioConnect/config.json
```

示例：

```json
{
  "deviceName": "AirPods Pro",
  "enabled": true,
  "fallbackCheckIntervalSeconds": 30,
  "connectCooldownSeconds": 10.0
}
```

| 字段 | 说明 |
| --- | --- |
| `deviceName` | 蓝牙设备名称，需与系统蓝牙列表中显示的名称完全一致 |
| `enabled` | 是否启用自动监听 |
| `fallbackCheckIntervalSeconds` | 兜底检查间隔（秒）。正常由事件触发，此项仅作备用 |
| `connectCooldownSeconds` | 连接失败后的重试冷却时间（秒） |

## 工作原理

```
音频开始播放 ──→ 检查蓝牙是否连接 ──→ 未连接则 openConnection()
蓝牙断开       ──→ 若正在播放音频   ──→ 尝试重连
```

- **音频**：注册 Core Audio 属性监听（`DeviceIsRunningSomewhere`、默认输出设备切换）
- **蓝牙**：注册 IOBluetooth 连接/断开通知
- **兜底**：每 30 秒（可配置）额外检查一次，防止回调遗漏

## 项目结构

```
BtAudioConnect/
  AudioMonitor.swift      # Core Audio 播放状态监听
  BluetoothManager.swift  # 蓝牙连接与通知
  MonitorService.swift    # 业务逻辑编排
  BtAudioConnectApp.swift # 菜单栏 UI 与设置
build.sh                  # 构建脚本
```

## 许可证

MIT
