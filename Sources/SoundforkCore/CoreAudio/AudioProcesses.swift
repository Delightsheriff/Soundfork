import CoreAudio

public enum AudioProcesses {
    /// Every process Core Audio currently knows about (anything that has opened an audio client).
    public static func all() throws -> [AudioProcess] {
        try AudioObjectID.system.readArray(kAudioHardwarePropertyProcessObjectList, of: AudioObjectID.self).map { id in
            AudioProcess(
                objectID: id,
                pid: try id.read(kAudioProcessPropertyPID, initial: pid_t(-1)),
                bundleID: (try? id.readString(kAudioProcessPropertyBundleID)) ?? "",
                isRunningOutput: try id.read(kAudioProcessPropertyIsRunningOutput, initial: UInt32(0)) != 0
            )
        }
    }
}
