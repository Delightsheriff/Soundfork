import Foundation
import Testing
@testable import SoundforkCore

@Test func preferencesSavedBeforeVolumeExistedDecodeAtFullVolume() throws {
    let json = #"{"deviceUID":"BuiltInSpeakerDevice","tapBundleIDs":["com.google.Chrome.helper"]}"#
    let preference = try JSONDecoder().decode(RoutePreference.self, from: Data(json.utf8))
    #expect(preference.volume == 1)
    #expect(preference.deviceUID == "BuiltInSpeakerDevice")
}

@Test func defaultDeviceAtFullVolumeNeedsNoRoute() {
    #expect(RoutePreference(deviceUID: nil, tapBundleIDs: []).isNeutral)
    #expect(!RoutePreference(deviceUID: nil, tapBundleIDs: [], volume: 0.5).isNeutral)
    #expect(!RoutePreference(deviceUID: "x", tapBundleIDs: []).isNeutral)
}

@Test func mutedAppNeedsARouteAndPlaysSilence() {
    let muted = RoutePreference(deviceUID: nil, tapBundleIDs: [], volume: 0.8, muted: true)
    #expect(!muted.isNeutral)
    #expect(muted.gain == 0)
    #expect(RoutePreference(deviceUID: nil, tapBundleIDs: [], volume: 0.8).gain == 0.8)
}

@Test func preferencesSavedBeforeMuteExistedDecodeUnmuted() throws {
    let json = #"{"tapBundleIDs":["com.spotify.client"],"volume":0.5}"#
    let preference = try JSONDecoder().decode(RoutePreference.self, from: Data(json.utf8))
    #expect(!preference.muted)
    #expect(preference.deviceUID == nil)
}
