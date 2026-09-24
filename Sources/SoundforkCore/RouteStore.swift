import Foundation
import os

/// Persists `[app bundleID: RoutePreference]` as one JSON blob in UserDefaults.
///
/// Loading is per entry: one entry that no longer decodes (a schema change, a hand edit) is dropped and logged,
/// never the whole map. If the blob itself is unreadable it's copied to a backup key before anything can overwrite it.
public struct RouteStore {
    private let defaults: UserDefaults
    private let key = "routes.v1"
    static let backupKey = "routes.v1.unreadable"
    private let log = Logger(subsystem: AppIdentity.bundleID, category: "store")

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> [String: RoutePreference] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        guard let entries = try? JSONDecoder().decode([String: LossyEntry].self, from: data) else {
            log.error("saved routes are unreadable; kept a copy under \(Self.backupKey, privacy: .public)")
            defaults.set(data, forKey: Self.backupKey)
            return [:]
        }
        var preferences: [String: RoutePreference] = [:]
        for (bundleID, entry) in entries {
            if let preference = entry.preference {
                preferences[bundleID] = preference
            } else {
                log.error("dropped unreadable saved route for \(bundleID, privacy: .public)")
            }
        }
        return preferences
    }

    public func save(_ preferences: [String: RoutePreference]) {
        do {
            defaults.set(try JSONEncoder().encode(preferences), forKey: key)
        } catch {
            // Keep what's on disk rather than deleting it.
            log.error("couldn't save routes: \(String(describing: error), privacy: .public)")
        }
    }

    /// Decodes one entry without failing the whole map.
    private struct LossyEntry: Decodable {
        let preference: RoutePreference?
        init(from decoder: any Decoder) throws {
            preference = try? RoutePreference(from: decoder)
        }
    }
}
