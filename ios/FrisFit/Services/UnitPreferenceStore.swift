import Foundation
import SwiftUI

nonisolated enum UnitOverrideStorage {
    static let key = "compound_unit_overrides_v1"

    static func loadRaw() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    static func saveRaw(_ overrides: [String: String]) {
        if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func unitOverride(for compoundName: String) -> CompoundUnit? {
        guard let raw = loadRaw()[compoundName] else { return nil }
        return CompoundUnit(rawValue: raw)
    }
}

@Observable
final class UnitPreferenceStore {
    static let shared = UnitPreferenceStore()

    private(set) var overrides: [String: String] = [:]

    private init() {
        overrides = UnitOverrideStorage.loadRaw()
    }

    func unitOverride(for compoundName: String) -> CompoundUnit? {
        guard let raw = overrides[compoundName] else { return nil }
        return CompoundUnit(rawValue: raw)
    }

    func effectiveUnit(for compoundName: String) -> CompoundUnit {
        if let override = unitOverride(for: compoundName) { return override }
        return CompoundUnitHelper.defaultUnit(for: compoundName)
    }

    func setUnit(_ unit: CompoundUnit, for compoundName: String) {
        overrides[compoundName] = unit.rawValue
        UnitOverrideStorage.saveRaw(overrides)
    }

    func clearOverride(for compoundName: String) {
        overrides.removeValue(forKey: compoundName)
        UnitOverrideStorage.saveRaw(overrides)
    }

    func toggleUnit(for compoundName: String) {
        let current = effectiveUnit(for: compoundName)
        let next: CompoundUnit = current == .mg ? .mcg : .mg
        setUnit(next, for: compoundName)
    }
}
