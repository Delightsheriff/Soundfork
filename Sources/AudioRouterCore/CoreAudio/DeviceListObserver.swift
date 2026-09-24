import CoreAudio
import Dispatch

/// Calls `onChange` on the main thread when a device is added or removed, or the default output changes.
public final class DeviceListObserver {
    private var addresses = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice].map {
        AudioObjectPropertyAddress(mSelector: $0, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private let listener: AudioObjectPropertyListenerBlock

    public init(onChange: @escaping @MainActor () -> Void) throws {
        listener = { _, _ in MainActor.assumeIsolated { onChange() } }
        for index in addresses.indices {
            try check(AudioObjectAddPropertyListenerBlock(.system, &addresses[index], .main, listener),
                      "add listener \(fourCC(addresses[index].mSelector))")
        }
    }

    deinit {
        for index in addresses.indices {
            AudioObjectRemovePropertyListenerBlock(.system, &addresses[index], .main, listener)
        }
    }
}
