import CoreAudio

public enum OutputDevices {
    /// Visible devices that can play audio. The user's own aggregate and Multi-Output devices are included;
    /// Soundfork's private route devices are not. Throws only if the device list itself can't be read: a device
    /// that is mid-connect (Bluetooth often is) and can't answer is skipped, not allowed to fail the whole list.
    public static func all() throws -> [OutputDevice] {
        try AudioObjectID.system.readArray(kAudioHardwarePropertyDevices, of: AudioObjectID.self).compactMap { try? device($0) }
    }

    private static func device(_ id: AudioObjectID) throws -> OutputDevice? {
        let outputs = try id.channelCount(scope: kAudioObjectPropertyScopeOutput)
        guard outputs.channels > 0 else { return nil }
        let uid = try id.readString(kAudioDevicePropertyDeviceUID)
        guard !uid.hasPrefix(AppIdentity.bundleID) else { return nil }
        let transport = try id.read(kAudioDevicePropertyTransportType, initial: UInt32(0))
        if id.hasProperty(kAudioDevicePropertyIsHidden),
           try id.read(kAudioDevicePropertyIsHidden, initial: UInt32(0)) != 0 { return nil }
        return OutputDevice(
            uid: uid,
            objectID: id,
            name: try id.readString(kAudioObjectPropertyName),
            kind: kind(for: transport),
            channels: outputs.channels,
            sampleRate: try id.read(kAudioDevicePropertyNominalSampleRate, initial: Float64(0))
        )
    }

    /// The Mac's default output. Pass `devices` when you already have the list, to avoid enumerating again.
    public static func defaultOutput(in devices: [OutputDevice]? = nil) throws -> OutputDevice? {
        let id = try AudioObjectID.system.read(kAudioHardwarePropertyDefaultOutputDevice, initial: AudioObjectID(kAudioObjectUnknown))
        return try (devices ?? all()).first { $0.objectID == id }
    }

    /// Changes the Mac's default output, same as picking it in Control Center.
    public static func setDefault(_ device: OutputDevice) throws {
        try AudioObjectID.system.write(kAudioHardwarePropertyDefaultOutputDevice, value: device.objectID)
    }

    static func kind(for transport: UInt32) -> OutputDevice.Kind {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: .bluetooth
        case kAudioDeviceTransportTypeUSB: .usb
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: .hdmi
        case kAudioDeviceTransportTypeAirPlay: .airPlay
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate: .virtual
        default: .other
        }
    }
}
