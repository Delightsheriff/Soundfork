import CoreAudio
import Dispatch

/// Watches the audio system on the main thread: devices added/removed or the default output changed,
/// the set of audio processes changed, and coreaudiod restarting (which invalidates every object ID we hold).
public final class HardwareObserver {
    public enum Change: Sendable { case devices, processes, serviceRestarted }

    private var addresses = [
        kAudioHardwarePropertyDevices,
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioHardwarePropertyProcessObjectList,
        kAudioHardwarePropertyServiceRestarted,
    ].map {
        AudioObjectPropertyAddress(mSelector: $0, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    }
    private let listener: AudioObjectPropertyListenerBlock

    public init(onChange: @escaping @MainActor (Change) -> Void) throws {
        listener = { count, changed in
            let selectors = (0..<Int(count)).map { changed[$0].mSelector }
            let change: Change =
                if selectors.contains(kAudioHardwarePropertyServiceRestarted) { .serviceRestarted }
                else if selectors.allSatisfy({ $0 == kAudioHardwarePropertyProcessObjectList }) { .processes }
                else { .devices }
            MainActor.assumeIsolated { onChange(change) }
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
