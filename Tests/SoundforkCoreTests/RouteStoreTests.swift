import Foundation
import Testing
@testable import SoundforkCore

private func freshDefaults() -> UserDefaults {
    let suite = "RouteStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

@Test func routesRoundTrip() {
    let store = RouteStore(defaults: freshDefaults())
    let saved = ["com.spotify.client": RoutePreference(deviceUID: "speaker", deviceName: "Speaker", tapBundleIDs: ["com.spotify.client"], volume: 0.4)]
    store.save(saved)
    #expect(store.load() == saved)
}

@Test func oneUnreadableEntryDoesNotDropTheOthers() {
    let defaults = freshDefaults()
    let json = #"""
    {"com.good.app": {"deviceUID": "speaker", "tapBundleIDs": ["com.good.app"], "volume": 0.5},
     "com.bad.app":  {"deviceUID": "speaker"}}
    """#
    defaults.set(Data(json.utf8), forKey: "routes.v1")
    let loaded = RouteStore(defaults: defaults).load()
    #expect(loaded.keys.sorted() == ["com.good.app"])
    #expect(loaded["com.good.app"]?.volume == 0.5)
}

@Test func unreadableBlobIsBackedUpNotLost() {
    let defaults = freshDefaults()
    let garbage = Data("not json".utf8)
    defaults.set(garbage, forKey: "routes.v1")
    #expect(RouteStore(defaults: defaults).load().isEmpty)
    #expect(defaults.data(forKey: RouteStore.backupKey) == garbage)
}
