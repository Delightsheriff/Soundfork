/// A user-facing app, grouping every audio process that belongs to it (e.g. Chrome's helpers).
public struct AudioApp: Sendable, Hashable, Identifiable {
    public var id: String { bundleID }
    /// The app's own bundle ID (what the user recognizes and what we persist).
    public let bundleID: String
    /// Bundle IDs to hand to the tap: the app plus any helper processes seen producing its audio.
    public let tapBundleIDs: [String]
    public let isPlaying: Bool

    public init(bundleID: String, tapBundleIDs: [String], isPlaying: Bool) {
        self.bundleID = bundleID
        self.tapBundleIDs = tapBundleIDs
        self.isPlaying = isPlaying
    }
}
