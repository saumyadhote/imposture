import Foundation

protocol PreferencesStoring {
    func load() -> UserPreferences
    func save(_ preferences: UserPreferences)
}

protocol SessionSnapshotStoring {
    func load() -> SessionSnapshot?
    func save(_ snapshot: SessionSnapshot)
    func clear()
}

/// Stores small Codable values in UserDefaults under a single key.
private struct DefaultsCodableBox<Value: Codable> {
    let defaults: UserDefaults
    let key: String

    func read() -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func write(_ value: Value) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    func remove() {
        defaults.removeObject(forKey: key)
    }
}

struct UserDefaultsPreferencesStore: PreferencesStoring {
    private let box: DefaultsCodableBox<UserPreferences>

    init(defaults: UserDefaults = .standard) {
        box = DefaultsCodableBox(defaults: defaults, key: "imposture.preferences")
    }

    func load() -> UserPreferences { box.read() ?? UserPreferences() }
    func save(_ preferences: UserPreferences) { box.write(preferences) }
}

struct UserDefaultsSnapshotStore: SessionSnapshotStoring {
    private let box: DefaultsCodableBox<SessionSnapshot>

    init(defaults: UserDefaults = .standard) {
        box = DefaultsCodableBox(defaults: defaults, key: "imposture.activeSession")
    }

    func load() -> SessionSnapshot? { box.read() }
    func save(_ snapshot: SessionSnapshot) { box.write(snapshot) }
    func clear() { box.remove() }
}
