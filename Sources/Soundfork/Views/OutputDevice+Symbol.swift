import SoundforkCore

/// Symbols for route states that aren't a specific device.
enum DeviceSymbol {
    static let systemDefault = "arrow.triangle.branch"
    static let missing = "speaker.slash"
}

extension OutputDevice {
    var symbolName: String {
        let lowered = name.lowercased()
        if lowered.contains("airpods") { return "airpods" }
        if ["headphone", "buds", "earphone", "headset"].contains(where: lowered.contains) { return "headphones" }
        switch kind {
        case .builtIn: return "laptopcomputer"
        case .bluetooth: return "hifispeaker.fill"
        case .usb: return "cable.connector"
        case .hdmi: return "tv"
        case .airPlay: return "airplayaudio"
        case .virtual: return "waveform"
        case .other: return "speaker.wave.2.fill"
        }
    }
}
