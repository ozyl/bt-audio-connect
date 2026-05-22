import CoreAudio
import Foundation

final class AudioMonitor {
    typealias PlayingChangeHandler = (Bool) -> Void

    private var outputDeviceID: AudioDeviceID = kAudioObjectUnknown
    private var isRunningListenerAdded = false
    private var defaultDeviceListenerAdded = false
    private var onPlayingChange: PlayingChangeHandler?

    private static let propertyListener: AudioObjectPropertyListenerProc = { _, numAddresses, addresses, clientData in
        guard let clientData, numAddresses > 0 else { return noErr }
        let monitor = Unmanaged<AudioMonitor>.fromOpaque(clientData).takeUnretainedValue()
        if addresses[0].mSelector == kAudioHardwarePropertyDefaultOutputDevice {
            monitor.handleDefaultOutputDeviceChange()
        } else {
            monitor.handlePropertyChange()
        }
        return noErr
    }

    func start(onPlayingChange: @escaping PlayingChangeHandler) {
        self.onPlayingChange = onPlayingChange
        refreshOutputDevice()
        installListeners()
        emitCurrentState()
    }

    func stop() {
        removeListeners()
        onPlayingChange = nil
    }

    func currentIsPlaying() -> Bool {
        readIsRunning()
    }

    private func handlePropertyChange() {
        let playing = readIsRunning()
        DispatchQueue.main.async { [weak self] in
            self?.onPlayingChange?(playing)
        }
    }

    private func handleDefaultOutputDeviceChange() {
        removeOutputDeviceListener()
        refreshOutputDevice()
        installOutputDeviceListener()
        emitCurrentState()
    }

    private func emitCurrentState() {
        let playing = readIsRunning()
        DispatchQueue.main.async { [weak self] in
            self?.onPlayingChange?(playing)
        }
    }

    private func installListeners() {
        installDefaultOutputDeviceListener()
        installOutputDeviceListener()
    }

    private func removeListeners() {
        removeDefaultOutputDeviceListener()
        removeOutputDeviceListener()
    }

    private func installDefaultOutputDeviceListener() {
        guard !defaultDeviceListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectAddPropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            Self.propertyListener,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status == noErr {
            defaultDeviceListenerAdded = true
        }
    }

    private func removeDefaultOutputDeviceListener() {
        guard defaultDeviceListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListener(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            Self.propertyListener,
            Unmanaged.passUnretained(self).toOpaque()
        )
        defaultDeviceListenerAdded = false
    }

    private func installOutputDeviceListener() {
        guard outputDeviceID != kAudioObjectUnknown, !isRunningListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectAddPropertyListener(
            outputDeviceID,
            &address,
            Self.propertyListener,
            Unmanaged.passUnretained(self).toOpaque()
        )

        if status == noErr {
            isRunningListenerAdded = true
        }
    }

    private func removeOutputDeviceListener() {
        guard outputDeviceID != kAudioObjectUnknown, isRunningListenerAdded else { return }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListener(
            outputDeviceID,
            &address,
            Self.propertyListener,
            Unmanaged.passUnretained(self).toOpaque()
        )
        isRunningListenerAdded = false
    }

    private func refreshOutputDevice() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr else { return }

        if deviceID != outputDeviceID {
            removeOutputDeviceListener()
            outputDeviceID = deviceID
        }
    }

    private func readIsRunning() -> Bool {
        refreshOutputDevice()
        guard outputDeviceID != kAudioObjectUnknown else { return false }

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var isRunning: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(
            outputDeviceID,
            &address,
            0,
            nil,
            &size,
            &isRunning
        )

        guard status == noErr else { return false }
        return isRunning != 0
    }
}
