import CoreAudio
import Foundation

/// A process tap, a private aggregate device pairing it with one output device, and an IOProc running on
/// that aggregate. Owns all three and destroys them in the only safe order: IOProc, aggregate, tap.
final class TapAggregate {
    private(set) var tapID = AudioObjectID(kAudioObjectUnknown)
    private(set) var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    init(tap description: CATapDescription, outputUID: String, name: String,
         ioProc: AudioDeviceIOProc, clientData: UnsafeMutableRawPointer?) throws {
        description.isPrivate = true
        do {
            try check(AudioHardwareCreateProcessTap(description, &tapID), "AudioHardwareCreateProcessTap")
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: name,
                kAudioAggregateDeviceUIDKey: "\(AppIdentity.bundleID).aggregate.\(UUID().uuidString)",
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                    kAudioSubTapDriftCompensationKey: true,
                ]],
            ]
            try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "AudioHardwareCreateAggregateDevice")
            try check(AudioDeviceCreateIOProcID(aggregateID, ioProc, clientData, &ioProcID), "AudioDeviceCreateIOProcID")
            try check(AudioDeviceStart(aggregateID, ioProcID), "AudioDeviceStart")
        } catch {
            stop()
            throw error
        }
    }

    deinit { stop() }

    /// Idempotent. Returns any failures; they can't be recovered from, only reported.
    @discardableResult
    func stop() -> [CoreAudioError] {
        var errors: [CoreAudioError] = []
        func attempt(_ status: OSStatus, _ call: String) {
            if status != noErr { errors.append(CoreAudioError(call: call, status: status)) }
        }
        if let ioProcID {
            attempt(AudioDeviceStop(aggregateID, ioProcID), "AudioDeviceStop")
            attempt(AudioDeviceDestroyIOProcID(aggregateID, ioProcID), "AudioDeviceDestroyIOProcID")
            self.ioProcID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            attempt(AudioHardwareDestroyAggregateDevice(aggregateID), "AudioHardwareDestroyAggregateDevice")
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            attempt(AudioHardwareDestroyProcessTap(tapID), "AudioHardwareDestroyProcessTap")
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        return errors
    }
}
