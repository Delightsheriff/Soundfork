public enum AudioApps {
    /// Audio processes whose bundle ID doesn't reveal the owning app.
    static let knownOwners = [
        "com.apple.WebKit.GPU": "com.apple.Safari",
    ]

    /// Maps a process bundle ID to the bundle ID of the app it belongs to ("com.google.Chrome.helper" → "com.google.Chrome").
    public static func owner(ofProcess bundleID: String) -> String? {
        guard !bundleID.isEmpty else { return nil }
        if let known = knownOwners[bundleID] { return known }
        if let helper = bundleID.range(of: ".helper", options: .caseInsensitive) {
            return String(bundleID[..<helper.lowerBound])
        }
        return bundleID
    }

    public static func group(_ processes: [AudioProcess], excludingPrefix excluded: String) -> [AudioApp] {
        var tapIDs: [String: Set<String>] = [:]
        var playing: [String: Bool] = [:]
        for process in processes {
            guard let owner = owner(ofProcess: process.bundleID), !owner.hasPrefix(excluded) else { continue }
            tapIDs[owner, default: [owner]].insert(process.bundleID)
            playing[owner, default: false] = playing[owner, default: false] || process.isRunningOutput
        }
        return tapIDs.map { owner, ids in
            AudioApp(bundleID: owner, tapBundleIDs: ids.sorted(), isPlaying: playing[owner] ?? false)
        }
        .sorted { $0.bundleID < $1.bundleID }
    }

    public static func current(excludingPrefix excluded: String = AppIdentity.bundleID) throws -> [AudioApp] {
        group(try AudioProcesses.all(), excludingPrefix: excluded)
    }
}
