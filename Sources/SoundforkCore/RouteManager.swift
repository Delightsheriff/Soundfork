import Foundation
import os

/// Owns every live `Route` and keeps them matching the user's preferences and the devices currently connected.
@MainActor
public final class RouteManager {
    public private(set) var preferences: [String: RoutePreference]
    /// Last failure per app bundle ID, shown in the UI.
    public private(set) var errors: [String: String] = [:]
    public var onChange: (() -> Void)?

    private var routes: [String: Route] = [:]
    private let store: RouteStore
    private var hardwareObserver: HardwareObserver?
    /// When each device UID was first seen. Newly connected devices (Bluetooth especially) get a moment
    /// to settle before routes move onto them.
    private var firstSeen: [String: Date] = [:]
    private var settleWork: DispatchWorkItem?
    private static let settleDelay: TimeInterval = 1.5
    private let log = Logger(subsystem: "com.delightsheriff.Soundfork", category: "routes")

    public init(store: RouteStore = RouteStore()) {
        self.store = store
        preferences = store.load()
        // Devices present at launch count as settled.
        let launch = Date.distantPast
        for device in (try? OutputDevices.all()) ?? [] { firstSeen[device.uid] = launch }
        hardwareObserver = try? HardwareObserver { [weak self] change in
            switch change {
            case .devices: self?.reconcile()
            case .serviceRestarted: self?.rebuildAll(reason: "audio service restarted")
            }
        }
        reconcile()
    }

    public var activeRouteCount: Int { routes.count }

    public func volume(for bundleID: String) -> Float { preferences[bundleID]?.volume ?? 1 }

    public func isRouted(_ bundleID: String) -> Bool { routes[bundleID] != nil }

    /// `nil` sends the app back to the system default output.
    public func setDestination(_ device: OutputDevice?, for app: AudioApp) {
        var preference = preference(for: app)
        preference.deviceUID = device?.uid
        preference.deviceName = device?.name
        update(app.bundleID, preference)
    }

    public func setVolume(_ volume: Float, for app: AudioApp) {
        var preference = preference(for: app)
        preference.volume = max(0, min(volume, 1))
        if let route = routes[app.bundleID], !preference.isNeutral {
            // Live change: no need to rebuild the route.
            route.renderer.volume = preference.volume
            preferences[app.bundleID] = preference
            store.save(preferences)
            onChange?()
        } else {
            update(app.bundleID, preference)
        }
    }

    /// Apps can start new helper processes (browsers do); widen routed apps' taps to cover any newly seen bundle IDs.
    public func absorbNewHelpers(from apps: [AudioApp]) {
        var changed = false
        for app in apps {
            guard var preference = preferences[app.bundleID] else { continue }
            let merged = Set(preference.tapBundleIDs).union(app.tapBundleIDs).sorted()
            if merged != preference.tapBundleIDs {
                preference.tapBundleIDs = merged
                preferences[app.bundleID] = preference
                changed = true
            }
        }
        if changed {
            store.save(preferences)
            reconcile()
        }
    }

    public func removeAll() {
        preferences = [:]
        store.save(preferences)
        reconcile()
    }

    /// Tears down live routes but keeps preferences, so they come back next launch.
    public func stopAll() {
        for (bundleID, route) in routes { stop(route, bundleID) }
        routes = [:]
    }

    /// Throws away every route and builds them again: after wake, or when coreaudiod restarted and
    /// every object ID we hold is stale.
    public func rebuildAll(reason: String) {
        log.notice("rebuilding all routes: \(reason, privacy: .public)")
        for (bundleID, route) in routes { stop(route, bundleID) }
        routes = [:]
        reconcile()
    }

    public func reconcile() {
        let connected = settledDevices()
        let defaultUID = (try? OutputDevices.defaultOutput())?.uid

        // Where each preference should play right now: its chosen device, or the default if that's missing.
        var targets: [String: String] = [:]
        for (bundleID, preference) in preferences {
            if let chosen = preference.deviceUID, connected.contains(chosen) {
                targets[bundleID] = chosen
            } else if let defaultUID {
                targets[bundleID] = defaultUID
            }
        }

        var replaced: [(String, Route)] = []
        for (bundleID, route) in routes {
            let stillWanted = targets[bundleID] == route.destinationUID
                && route.source == .bundleIDs(preferences[bundleID]?.tapBundleIDs ?? [])
            if stillWanted {
                route.renderer.volume = preferences[bundleID]?.volume ?? 1
            } else {
                replaced.append((bundleID, route))
                routes[bundleID] = nil
            }
        }

        for (bundleID, target) in targets where routes[bundleID] == nil {
            guard let preference = preferences[bundleID] else { continue }
            do {
                routes[bundleID] = try Route(source: .bundleIDs(preference.tapBundleIDs), destinationUID: target, volume: preference.volume)
                errors[bundleID] = nil
                log.notice("route started \(bundleID, privacy: .public) → \(target, privacy: .public) volume=\(preference.volume) taps=\(preference.tapBundleIDs, privacy: .public)")
            } catch {
                errors[bundleID] = "\(error)"
                log.error("route failed \(bundleID, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        // Stop old routes only after their replacements run, so the app never briefly plays on the wrong device.
        for (bundleID, route) in replaced { stop(route, bundleID) }
        errors = errors.filter { preferences[$0.key] != nil }
        onChange?()
    }

    /// UIDs of connected devices that have been around for `settleDelay`; schedules a re-check for the rest.
    private func settledDevices() -> Set<String> {
        let now = Date.now
        let present = Set(((try? OutputDevices.all()) ?? []).map(\.uid))
        firstSeen = firstSeen.filter { present.contains($0.key) }
        for uid in present where firstSeen[uid] == nil { firstSeen[uid] = now }

        let pending = firstSeen.values.map { Self.settleDelay - now.timeIntervalSince($0) }.filter { $0 > 0 }
        if let wait = pending.min() {
            settleWork?.cancel()
            let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.reconcile() } }
            settleWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + wait + 0.05, execute: work)
        }
        return Set(firstSeen.filter { now.timeIntervalSince($0.value) >= Self.settleDelay }.keys)
    }

    private func preference(for app: AudioApp) -> RoutePreference {
        var preference = preferences[app.bundleID] ?? RoutePreference(deviceUID: nil, tapBundleIDs: app.tapBundleIDs)
        preference.tapBundleIDs = Set(preference.tapBundleIDs).union(app.tapBundleIDs).sorted()
        return preference
    }

    private func update(_ bundleID: String, _ preference: RoutePreference) {
        preferences[bundleID] = preference.isNeutral ? nil : preference
        store.save(preferences)
        reconcile()
    }

    private func stop(_ route: Route, _ bundleID: String) {
        for error in route.stop() {
            log.error("teardown \(bundleID, privacy: .public): \(error.description, privacy: .public)")
        }
        log.notice("route stopped \(bundleID, privacy: .public)")
    }
}
