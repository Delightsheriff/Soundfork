import CoreAudio
import Foundation

/// Triggers macOS's audio-capture permission prompt without changing what anyone hears:
/// an unmuted global tap is read for a moment and then torn down.
public enum AudioCapturePermission {
    /// Runs off the main thread: tap creation blocks until the user answers the prompt.
    public static func request() async {
        await Task.detached(priority: .userInitiated) { probe() }.value
    }

    private static func probe() {
        guard let output = try? OutputDevices.defaultOutput() else { return }
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.name = "Soundfork permission check"
        description.muteBehavior = .unmuted
        guard let probe = try? TapAggregate(tap: description, outputUID: output.uid, name: "Soundfork permission check",
                                            ioProc: silentIOProc, clientData: nil) else { return }
        Thread.sleep(forTimeInterval: 0.1)
        probe.stop()
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
