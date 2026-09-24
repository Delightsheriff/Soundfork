import CoreAudio

/// One process as Core Audio sees it. Not necessarily a user-facing app (e.g. com.apple.WebKit.GPU).
public struct AudioProcess: Sendable, Hashable {
    public let objectID: AudioObjectID
    public let pid: pid_t
    public let bundleID: String
    public let isRunningOutput: Bool
}
