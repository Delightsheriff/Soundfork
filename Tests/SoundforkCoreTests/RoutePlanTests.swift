import Foundation
import Testing
@testable import SoundforkCore

private func preference(_ device: String?, taps: [String] = ["app"], volume: Float = 1) -> RoutePreference {
    RoutePreference(deviceUID: device, tapBundleIDs: taps, volume: volume)
}

private func live(_ device: String, taps: [String] = ["app"]) -> RoutePlan.Live {
    RoutePlan.Live(destinationUID: device, tapBundleIDs: taps)
}

@Test func settledChosenDeviceIsTheTarget() {
    let plan = RoutePlan.make(preferences: ["app": preference("speaker")], settled: ["speaker", "laptop"],
                              defaultUID: "laptop", live: [:])
    #expect(plan.targets == ["app": "speaker"])
    #expect(plan.start == ["app": "speaker"])
}

@Test func unsettledOrMissingChosenDeviceFallsBackToTheDefault() {
    let plan = RoutePlan.make(preferences: ["app": preference("speaker")], settled: ["laptop"],
                              defaultUID: "laptop", live: [:])
    #expect(plan.targets == ["app": "laptop"])
}

@Test func volumeOnlyPreferenceFollowsTheDefault() {
    let plan = RoutePlan.make(preferences: ["app": preference(nil, volume: 0.4)], settled: ["laptop"],
                              defaultUID: "laptop", live: [:])
    #expect(plan.targets == ["app": "laptop"])
}

@Test func noDefaultAndNoChosenDeviceIsUnroutableAndStopsTheLiveRoute() {
    let plan = RoutePlan.make(preferences: ["app": preference("speaker")], settled: [],
                              defaultUID: nil, live: ["app": live("speaker")])
    #expect(plan.unroutable == ["app"])
    #expect(plan.stop == ["app"])
    #expect(plan.start.isEmpty)
}

@Test func matchingLiveRouteIsKept() {
    let plan = RoutePlan.make(preferences: ["app": preference("speaker", volume: 0.3)], settled: ["speaker"],
                              defaultUID: "laptop", live: ["app": live("speaker")])
    #expect(plan.keep == ["app"])
    #expect(plan.start.isEmpty)
    #expect(plan.stop.isEmpty)
}

@Test func newTapBundleIDsReplaceTheRoute() {
    let plan = RoutePlan.make(preferences: ["app": preference("speaker", taps: ["app", "app.helper"])],
                              settled: ["speaker"], defaultUID: nil, live: ["app": live("speaker")])
    #expect(plan.start == ["app": "speaker"])
    #expect(plan.stop == ["app"])
}

@Test func routeWithoutAPreferenceIsStopped() {
    let plan = RoutePlan.make(preferences: [:], settled: ["speaker"], defaultUID: "speaker",
                              live: ["app": live("speaker")])
    #expect(plan.stop == ["app"])
    #expect(plan.start.isEmpty)
}

@Test func devicesPresentAtLaunchAreSettledAndNewOnesWait() {
    let now = Date(timeIntervalSinceReferenceDate: 1000)
    var settling = DeviceSettling(alreadyPresent: ["laptop"])

    let first = settling.update(present: ["laptop", "speaker"], now: now)
    #expect(first.settled == ["laptop"])
    #expect(first.nextCheckIn == DeviceSettling.delay)

    let later = settling.update(present: ["laptop", "speaker"], now: now.addingTimeInterval(DeviceSettling.delay))
    #expect(later.settled == ["laptop", "speaker"])
    #expect(later.nextCheckIn == nil)
}

@Test func aDeviceThatReconnectsSettlesAgain() {
    let now = Date(timeIntervalSinceReferenceDate: 1000)
    var settling = DeviceSettling(alreadyPresent: ["speaker"])
    _ = settling.update(present: [], now: now)
    let back = settling.update(present: ["speaker"], now: now.addingTimeInterval(10))
    #expect(back.settled.isEmpty)
}
