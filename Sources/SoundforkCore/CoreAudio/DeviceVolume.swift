import CoreAudio

/// A device's own output volume (what the keyboard volume keys change). Per-app volumes scale within it.
public enum DeviceVolume {
    private static let output = kAudioObjectPropertyScopeOutput

    /// Volume 0...1, or nil if the device has no software volume (e.g. some HDMI outputs).
    public static func get(_ device: AudioObjectID) -> Float? {
        volumeElements(device)
            .compactMap { try? device.read(kAudioDevicePropertyVolumeScalar, scope: output, element: $0, initial: Float32(0)) }
            .max()
    }

    public static func set(_ volume: Float, on device: AudioObjectID) throws {
        for element in volumeElements(device) {
            try device.write(kAudioDevicePropertyVolumeScalar, scope: output, element: element, value: Float32(max(0, min(volume, 1))))
        }
    }

    public static func isMuted(_ device: AudioObjectID) -> Bool {
        guard device.hasProperty(kAudioDevicePropertyMute, scope: output) else { return false }
        return (try? device.read(kAudioDevicePropertyMute, scope: output, initial: UInt32(0))) ?? 0 != 0
    }

    public static func setMuted(_ muted: Bool, on device: AudioObjectID) throws {
        guard device.hasProperty(kAudioDevicePropertyMute, scope: output) else { return }
        try device.write(kAudioDevicePropertyMute, scope: output, value: UInt32(muted ? 1 : 0))
    }

    /// The main element if it has a settable volume, otherwise the individual channels (common on built-in speakers).
    private static func volumeElements(_ device: AudioObjectID) -> [AudioObjectPropertyElement] {
        if device.isSettable(kAudioDevicePropertyVolumeScalar, scope: output) { return [kAudioObjectPropertyElementMain] }
        return [1, 2].filter { device.isSettable(kAudioDevicePropertyVolumeScalar, scope: output, element: $0) }
    }
}
