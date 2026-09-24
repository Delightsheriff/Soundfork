import CoreAudio
import Dispatch

/// Watches the audio system on the main thread: devices added/removed, default output changed,
/// and coreaudiod restarting (which invalidates every object ID we hold).
public final class HardwareObserver {
    public enum Change: Sendable { case devices, serviceRestarted }

    private var addresses = [
        kAudioHardwarePropertyDevices,
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioHardwarePropertyServiceRestarted,
    ].map {
        AudioObjectPropertyAddress(mSelector: $0, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private let listener: AudioObjectPropertyListenerBlock

    public init(onChange: @escaping @MainActor (Change) -> Void) throws {
        listener = { count, changed in
            let restarted = (0..<Int(count)).contains { changed[$0].mSelector == kAudioHardwarePropertyServiceRestarted }
            MainActor.assumeIsolated { onChange(restarted ? .serviceRestarted : .devices) }
        }
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
