import Foundation

/// Tracks when each output device appeared, so routes only move onto devices that have had time to settle
/// (Bluetooth devices often report themselves before they can actually play).
struct DeviceSettling {
    static let delay: TimeInterval = 1.5

    /// UID → when it was first seen. Devices present at launch are marked `.distantPast` (already settled).
    private(set) var firstSeen: [String: Date] = [:]

    init(alreadyPresent: some Sequence<String> = []) {
        for uid in alreadyPresent { firstSeen[uid] = .distantPast }
    }

    /// Records the devices present now and returns the settled ones, plus how long until the next one settles.
    mutating func update(present: Set<String>, now: Date) -> (settled: Set<String>, nextCheckIn: TimeInterval?) {
        firstSeen = firstSeen.filter { present.contains($0.key) }
        for uid in present where firstSeen[uid] == nil { firstSeen[uid] = now }
        let remaining = firstSeen.values.map { Self.delay - now.timeIntervalSince($0) }.filter { $0 > 0 }
        let settled = Set(firstSeen.filter { now.timeIntervalSince($0.value) >= Self.delay }.keys)
        return (settled, remaining.min())
    }
}

/// The pure part of reconciling: given preferences, devices and the routes that are live, decide where each app
/// should play and which routes to keep, start and stop. `RouteManager` carries it out.
struct RoutePlan: Equatable {
    /// What a live route currently does.
    struct Live: Equatable {
        let destinationUID: String
        let tapBundleIDs: [String]
    }

    /// App bundle ID → device UID it should play through right now.
    var targets: [String: String] = [:]
    /// Live routes that already match their target; only their gain may need updating.
    var keep: Set<String> = []
    /// Routes to create: app bundle ID → device UID.
    var start: [String: String] = [:]
    /// Live routes to stop, after the replacements in `start` are running.
    var stop: Set<String> = []
    /// Apps with a preference but no device to play on (chosen device missing and no usable default output).
    var unroutable: Set<String> = []

    static func make(preferences: [String: RoutePreference], settled: Set<String>,
                     defaultUID: String?, live: [String: Live]) -> RoutePlan {
        var plan = RoutePlan()
        for (bundleID, preference) in preferences {
            if let chosen = preference.deviceUID, settled.contains(chosen) {
                plan.targets[bundleID] = chosen
            } else if let defaultUID {
                plan.targets[bundleID] = defaultUID
            } else {
                plan.unroutable.insert(bundleID)
            }
        }
        for (bundleID, route) in live {
            if let target = plan.targets[bundleID], target == route.destinationUID,
               route.tapBundleIDs == preferences[bundleID]?.tapBundleIDs {
                plan.keep.insert(bundleID)
            } else {
                plan.stop.insert(bundleID)
            }
        }
        for (bundleID, target) in plan.targets where !plan.keep.contains(bundleID) {
            plan.start[bundleID] = target
        }
        return plan
    }
}
