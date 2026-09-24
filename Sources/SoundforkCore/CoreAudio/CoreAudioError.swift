import CoreAudio

public struct CoreAudioError: Error, CustomStringConvertible, Sendable {
    public let call: String
    public let status: OSStatus

    public var description: String { "\(call) failed: \(fourCC(UInt32(bitPattern: status))) (\(status))" }
}

func check(_ status: OSStatus, _ call: @autoclosure () -> String) throws {
    if status != noErr { throw CoreAudioError(call: call(), status: status) }
}

/// Renders a Core Audio four-char code ('prs#', 'who?') or falls back to the number.
public func fourCC(_ code: UInt32) -> String {
    let bytes = [24, 16, 8, 0].map { UInt8((code >> $0) & 0xFF) }
    guard bytes.allSatisfy({ $0 >= 0x20 && $0 < 0x7F }) else { return String(code) }
    return "'" + String(decoding: bytes, as: UTF8.self) + "'"
}
