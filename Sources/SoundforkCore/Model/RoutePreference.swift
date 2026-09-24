public struct RoutePreference: Codable, Sendable, Hashable {
    /// `nil` follows the system default output (used when only the volume was changed).
    public var deviceUID: String?
    /// Kept so the UI can name the device while it's disconnected.
    public var deviceName: String?
    /// Remembered so the route can be recreated before the app has played anything this session.
    public var tapBundleIDs: [String]
    /// 0...1, applied in the IOProc.
    public var volume: Float
    /// Silences the app without losing its volume.
    public var muted: Bool

    public init(deviceUID: String?, deviceName: String? = nil, tapBundleIDs: [String], volume: Float = 1, muted: Bool = false) {
        self.deviceUID = deviceUID
        self.deviceName = deviceName
        self.tapBundleIDs = tapBundleIDs
        self.volume = volume
        self.muted = muted
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceUID = try container.decodeIfPresent(String.self, forKey: .deviceUID)
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName)
        tapBundleIDs = try container.decode([String].self, forKey: .tapBundleIDs)
        volume = try container.decodeIfPresent(Float.self, forKey: .volume) ?? 1
        muted = try container.decodeIfPresent(Bool.self, forKey: .muted) ?? false
    }

    /// Volumes at or above this count as 100% (sliders rarely land on exactly 1).
    public static let fullVolume: Float = 0.995

    /// The gain the IOProc should apply.
    public var gain: Float { muted ? 0 : volume }

    /// Nothing to do for this app: default device, full volume, not muted. No route needed.
    var isNeutral: Bool { deviceUID == nil && volume >= Self.fullVolume && !muted }
}
