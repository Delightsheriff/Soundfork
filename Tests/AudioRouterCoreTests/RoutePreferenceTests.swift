import Foundation
import Testing
@testable import AudioRouterCore

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
