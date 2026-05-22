#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$ROOT_DIR/BtAudioConnect"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="BtAudioConnect"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

swiftc \
  "$SRC_DIR/AppConfig.swift" \
  "$SRC_DIR/ConfigManager.swift" \
  "$SRC_DIR/AudioMonitor.swift" \
  "$SRC_DIR/BluetoothManager.swift" \
  "$SRC_DIR/MonitorService.swift" \
  "$SRC_DIR/BtAudioConnectApp.swift" \
  -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
  -O \
  -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework CoreAudio \
  -framework IOBluetooth \
  -framework ServiceManagement \
  -framework Combine

cp "$SRC_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$SRC_DIR/Resources/default-config.json" "$APP_BUNDLE/Contents/Resources/default-config.json"

if [ -f "$SRC_DIR/BtAudioConnect.entitlements" ]; then
  codesign --force --sign - --entitlements "$SRC_DIR/BtAudioConnect.entitlements" "$APP_BUNDLE"
else
  codesign --force --sign - "$APP_BUNDLE"
fi

echo "Built: $APP_BUNDLE"
