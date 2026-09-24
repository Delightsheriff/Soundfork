import CoreAudio

/// A device's own output volume (what the keyboard volume keys change). Per-app volumes scale within it.
public enum DeviceVolume {
    /// Volume 0...1, or nil if the device has no software volume (e.g. some HDMI outputs).
    public static func get(_ device: AudioObjectID) -> Float? {
        let elements = volumeElements(device)
        guard !elements.isEmpty else { return nil }
        let values = elements.compactMap { element -> Float? in
            var address = address(kAudioDevicePropertyVolumeScalar, element)
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
        }
        return values.max()
    }

    public static func set(_ volume: Float, on device: AudioObjectID) throws {
        var value = Float32(max(0, min(volume, 1)))
        for element in volumeElements(device) {
            var address = address(kAudioDevicePropertyVolumeScalar, element)
            try check(AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value),
                      "set volume on \(device) element \(element)")
        }
    }

    public static func isMuted(_ device: AudioObjectID) -> Bool {
        var address = address(kAudioDevicePropertyMute, kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr && value != 0
    }

    public static func setMuted(_ muted: Bool, on device: AudioObjectID) throws {
        var address = address(kAudioDevicePropertyMute, kAudioObjectPropertyElementMain)
        guard AudioObjectHasProperty(device, &address) else { return }
        var value: UInt32 = muted ? 1 : 0
        try check(AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value), "set mute on \(device)")
    }

    /// The main element if it has a settable volume, otherwise the individual channels (common on built-in speakers).
    private static func volumeElements(_ device: AudioObjectID) -> [AudioObjectPropertyElement] {
        if isSettable(device, kAudioObjectPropertyElementMain) { return [kAudioObjectPropertyElementMain] }
        return [1, 2].filter { isSettable(device, $0) }
    }

    private static func isSettable(_ device: AudioObjectID, _ element: AudioObjectPropertyElement) -> Bool {
        var address = address(kAudioDevicePropertyVolumeScalar, element)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    private static func address(_ selector: AudioObjectPropertySelector, _ element: AudioObjectPropertyElement) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeOutput, mElement: element)
    }
}
