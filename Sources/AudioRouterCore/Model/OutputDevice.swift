import CoreAudio

public struct OutputDevice: Sendable, Hashable, Identifiable {
    public enum Kind: Sendable, Hashable {
        case builtIn, bluetooth, usb, hdmi, airPlay, virtual, other
    }

    public var id: String { uid }
    public let uid: String
    public let objectID: AudioObjectID
    public let name: String
    public let kind: Kind
    public let channels: Int
    public let sampleRate: Double
}
