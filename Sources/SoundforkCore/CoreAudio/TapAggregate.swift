import CoreAudio
import Foundation

/// A process tap, a private aggregate device pairing it with one output device, and an IOProc running on
/// that aggregate. Owns all three and destroys them in the only safe order: IOProc, aggregate, tap.
final class TapAggregate {
    private(set) var tapID = AudioObjectID(kAudioObjectUnknown)
    private(set) var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    /// `destinationInputStreams`: how many input streams the output device itself has (a headset's microphone).
    /// They come before the tap in the aggregate's inputs and are switched off for our IOProc.
    init(tap description: CATapDescription, outputUID: String, name: String, destinationInputStreams: Int = 0,
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
            if destinationInputStreams > 0, let ioProcID { useOnlyTapInput(for: ioProcID, skipping: destinationInputStreams) }
            try check(AudioDeviceStart(aggregateID, ioProcID), "AudioDeviceStart")
        } catch {
            stop()
            throw error
        }
    }

    deinit { stop() }

    /// Tells Core Audio our IOProc reads only the tap, not the output device's own microphone. Opening a
    /// headset's mic switches Bluetooth headsets (AirPods etc.) into low-quality call mode for everything.
    /// Best effort: if it fails the route still works, so the error is not fatal.
    private func useOnlyTapInput(for ioProcID: AudioDeviceIOProcID, skipping skipped: Int) {
        guard let streams = try? aggregateID.readArray(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput,
                                                        of: AudioObjectID.self).count, streams > skipped else { return }
        typealias Usage = AudioHardwareIOProcStreamUsage
        let flagsOffset = MemoryLayout<Usage>.offset(of: \Usage.mStreamIsOn)!
        let size = flagsOffset + streams * MemoryLayout<UInt32>.stride
        let usage = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<Usage>.alignment)
        defer { usage.deallocate() }
        usage.storeBytes(of: unsafeBitCast(ioProcID, to: UnsafeMutableRawPointer.self),
                         toByteOffset: MemoryLayout<Usage>.offset(of: \Usage.mIOProc)!, as: UnsafeMutableRawPointer.self)
        usage.storeBytes(of: UInt32(streams), toByteOffset: MemoryLayout<Usage>.offset(of: \Usage.mNumberStreams)!, as: UInt32.self)
        for stream in 0..<streams {
            usage.storeBytes(of: UInt32(stream >= skipped ? 1 : 0), toByteOffset: flagsOffset + stream * MemoryLayout<UInt32>.stride, as: UInt32.self)
        }
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyIOProcStreamUsage,
                                                 mScope: kAudioObjectPropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
        _ = AudioObjectSetPropertyData(aggregateID, &address, 0, nil, UInt32(size), usage)
    }

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
