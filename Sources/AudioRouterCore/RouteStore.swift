import Foundation

/// Persists `[app bundleID: RoutePreference]` as one JSON blob in UserDefaults.
public struct RouteStore {
    private let defaults: UserDefaults
    private let key = "routes.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> [String: RoutePreference] {
        guard let data = defaults.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: RoutePreference].self, from: data)) ?? [:]
    }

    public func save(_ preferences: [String: RoutePreference]) {
        defaults.set(try? JSONEncoder().encode(preferences), forKey: key)
    }
}
