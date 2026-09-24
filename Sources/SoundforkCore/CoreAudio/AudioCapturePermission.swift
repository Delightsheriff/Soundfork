import CoreAudio
import Foundation

/// Triggers macOS's audio-capture permission prompt without changing what anyone hears:
/// an unmuted, private global tap is read for a moment and then torn down.
public enum AudioCapturePermission {
    /// Runs off the main thread: tap creation blocks until the user answers the prompt.
    public static func request() async {
        await Task.detached(priority: .userInitiated) { probe() }.value
    }

    private static func probe() {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "Soundfork permission check"
        description.muteBehavior = .unmuted
        description.isPrivate = true

        var tapID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(description, &tapID) == noErr else { return }
        defer { AudioHardwareDestroyProcessTap(tapID) }

        guard let output = try? OutputDevices.defaultOutput() else { return }
        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Soundfork permission check",
            kAudioAggregateDeviceUIDKey: "com.delightsheriff.Soundfork.probe.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: output.uid,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: output.uid]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapUIDKey: description.uuid.uuidString]],
        ]
        var aggregateID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID) == noErr else { return }
        defer { AudioHardwareDestroyAggregateDevice(aggregateID) }

        var ioProcID: AudioDeviceIOProcID?
        guard AudioDeviceCreateIOProcID(aggregateID, silentIOProc, nil, &ioProcID) == noErr, let ioProcID else { return }
        defer { AudioDeviceDestroyIOProcID(aggregateID, ioProcID) }
        if AudioDeviceStart(aggregateID, ioProcID) == noErr {
            Thread.sleep(forTimeInterval: 0.5)
            AudioDeviceStop(aggregateID, ioProcID)
        }
    }
}

/// Writes silence; the probe only needs the tap to be read.
private func silentIOProc(_: AudioObjectID,
                          _: UnsafePointer<AudioTimeStamp>,
                          _: UnsafePointer<AudioBufferList>,
                          _: UnsafePointer<AudioTimeStamp>,
                          _ output: UnsafeMutablePointer<AudioBufferList>,
                          _: UnsafePointer<AudioTimeStamp>,
                          _: UnsafeMutableRawPointer?) -> OSStatus {
    for buffer in UnsafeMutableAudioBufferListPointer(output) {
        if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
    }
    return noErr
}
