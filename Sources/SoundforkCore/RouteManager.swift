import Foundation
import os

/// Owns every live `Route` and keeps them matching the user's preferences, the devices currently connected
/// and the audio processes currently running. Works on its own in the background; the UI only reads and edits it.
@MainActor
public final class RouteManager {
    public private(set) var preferences: [String: RoutePreference]
    /// Last failure per app bundle ID, shown in the UI.
    public private(set) var errors: [String: String] = [:]
    /// Called after routes start or stop.
    public var onChange: (() -> Void)?

    private var routes: [String: Route] = [:]
    private let store: RouteStore
    private var hardwareObserver: HardwareObserver?
    private var settling: DeviceSettling
    private var settleWork: DispatchWorkItem?
    private var saveWork: DispatchWorkItem?
    private var reconcileScheduled = false
    /// Tap creation blocks until the user answers the audio-capture prompt, so the first route waits for an
    /// off-main permission check instead of freezing the main thread.
    private var permission = PermissionState.unknown
    private enum PermissionState { case unknown, checking, settled }
    private let log = Logger(subsystem: AppIdentity.bundleID, category: "routes")

    public init(store: RouteStore = RouteStore()) {
        self.store = store
        preferences = store.load()
        settling = DeviceSettling(alreadyPresent: ((try? OutputDevices.all()) ?? []).map(\.uid))
        hardwareObserver = try? HardwareObserver { [weak self] change in
            switch change {
            case .devices: self?.scheduleReconcile()
            case .processes: self?.absorbNewHelpers()
            case .serviceRestarted: self?.rebuildAll(reason: "audio service restarted")
            }
        }
        absorbNewHelpers()
        reconcile()
    }

    public var hasActiveRoutes: Bool { !routes.isEmpty }

    /// UID of the device the app is actually playing through right now, or nil if it isn't routed.
    public func currentDestination(for bundleID: String) -> String? { routes[bundleID]?.destinationUID }

    /// `nil` sends the app back to the system default output.
    public func setDestination(_ device: OutputDevice?, for app: AudioApp) {
        var preference = preference(for: app)
        preference.deviceUID = device?.uid
        preference.deviceName = device?.name
        update(app.bundleID, preference)
    }

    /// Pass `final: false` for ticks during a drag and `true` when it ends. Mid-drag the live route is kept even at
    /// 100%, so crossing the top doesn't tear it down and rebuild it; whether it's still needed is decided at the end.
    /// Moving the slider also unmutes the app.
    public func setVolume(_ volume: Float, for app: AudioApp, final: Bool = true) {
        var preference = preference(for: app)
        preference.volume = max(0, min(volume, 1))
        if preference.volume > 0 { preference.muted = false }
        if let route = routes[app.bundleID], !final || !preference.isNeutral {
            route.renderer.volume = preference.gain
            preferences[app.bundleID] = preference
            scheduleSave()
        } else {
            update(app.bundleID, preference)
        }
    }

    public func setMuted(_ muted: Bool, for app: AudioApp) {
        var preference = preference(for: app)
        preference.muted = muted
        update(app.bundleID, preference)
    }

    public func removeAll() {
        preferences = [:]
        save()
        reconcile()
    }

    /// Tears down live routes but keeps preferences, so they come back next launch.
    public func stopAll() {
        if saveWork != nil { save() }
        for (bundleID, route) in routes { stop(route, bundleID) }
        routes = [:]
    }

    /// Throws away every route and builds them again, e.g. when coreaudiod restarted and every object ID we hold is stale.
    public func rebuildAll(reason: String) {
        log.notice("rebuilding all routes: \(reason, privacy: .public)")
        stopAll()
        reconcile()
    }

    /// After sleep, Bluetooth devices often reconnect late: rebuild once they've had time to settle.
    public func handleWake() {
        DispatchQueue.main.asyncAfter(deadline: .now() + DeviceSettling.delay) { [weak self] in
            MainActor.assumeIsolated { self?.rebuildAll(reason: "woke from sleep") }
        }
    }

    public func reconcile() {
        guard permission == .settled else {
            if permission == .unknown, !preferences.isEmpty { checkPermissionThenReconcile() }
            return
        }
        // If the device list can't be read at all (mid-switch), keep the current routes and look again shortly,
        // rather than treating it as "every device disappeared" and tearing routes down.
        guard let devices = try? OutputDevices.all() else {
            scheduleSettleCheck(in: 0.5)
            return
        }
        let byUID = Dictionary(devices.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        let (settled, nextCheck) = settling.update(present: Set(byUID.keys), now: .now)
        if let nextCheck { scheduleSettleCheck(in: nextCheck) }

        let plan = RoutePlan.make(
            preferences: preferences,
            settled: settled,
            defaultUID: (try? OutputDevices.defaultOutput(in: devices))?.uid,
            live: routes.mapValues { RoutePlan.Live(destinationUID: $0.destinationUID, tapBundleIDs: $0.tapBundleIDs) }
        )

        for bundleID in plan.keep {
            routes[bundleID]?.renderer.volume = preferences[bundleID]?.gain ?? 1
        }
        // Stopped only after their replacements run, so an app never briefly plays on the wrong device.
        let replaced = plan.stop.compactMap { bundleID in routes.removeValue(forKey: bundleID).map { (bundleID, $0) } }

        for (bundleID, uid) in plan.start {
            guard let preference = preferences[bundleID], let device = byUID[uid] else { continue }
            do {
                routes[bundleID] = try Route(source: .bundleIDs(preference.tapBundleIDs), destination: device, volume: preference.gain)
                errors[bundleID] = nil
                log.notice("route started \(bundleID, privacy: .public) → \(uid, privacy: .private(mask: .hash)) taps=\(preference.tapBundleIDs, privacy: .public)")
            } catch {
                errors[bundleID] = "\(error)"
                log.error("route failed \(bundleID, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        for bundleID in plan.unroutable {
            errors[bundleID] = "No output device is available."
        }
        for (bundleID, route) in replaced { stop(route, bundleID) }
        errors = errors.filter { preferences[$0.key] != nil }
        onChange?()
    }

    // MARK: Private

    /// Coalesces bursts of hardware notifications (plugging in a device fires several) into one reconcile.
    private func scheduleReconcile() {
        guard !reconcileScheduled else { return }
        reconcileScheduled = true
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.reconcileScheduled = false
                self?.reconcile()
            }
        }
    }

    /// Apps start new helper processes (browsers do); widen routed apps' taps to cover any newly seen bundle IDs.
    private func absorbNewHelpers() {
        guard !preferences.isEmpty, let apps = try? AudioApps.current() else { return }
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
            save()
            scheduleReconcile()
        }
    }

    private func checkPermissionThenReconcile() {
        permission = .checking
        Task { [weak self] in
            await AudioCapturePermission.request()
            guard let self else { return }
            permission = .settled
            reconcile()
        }
    }

    private func scheduleSettleCheck(in wait: TimeInterval) {
        settleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.reconcile() } }
        settleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + wait + 0.05, execute: work)
    }

    private func preference(for app: AudioApp) -> RoutePreference {
        var preference = preferences[app.bundleID] ?? RoutePreference(deviceUID: nil, tapBundleIDs: app.tapBundleIDs)
        preference.tapBundleIDs = Set(preference.tapBundleIDs).union(app.tapBundleIDs).sorted()
        return preference
    }

    private func update(_ bundleID: String, _ preference: RoutePreference) {
        preferences[bundleID] = preference.isNeutral ? nil : preference
        save()
        reconcile()
    }

    private func save() {
        saveWork?.cancel()
        saveWork = nil
        store.save(preferences)
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.save() } }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func stop(_ route: Route, _ bundleID: String) {
        for error in route.stop() {
            log.error("teardown \(bundleID, privacy: .public): \(error.description, privacy: .public)")
        }
        log.notice("route stopped \(bundleID, privacy: .public)")
    }
}
