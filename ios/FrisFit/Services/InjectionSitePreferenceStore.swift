import Foundation
import SwiftUI

@Observable
@MainActor
final class InjectionSitePreferenceStore {
    static let shared = InjectionSitePreferenceStore()

    private let storageKey = "peppal.injectionSitePreferences.v1"

    var preferredSites: Set<InjectionSite> = [] {
        didSet { save() }
    }

    private init() {
        load()
    }

    private func load() {
        guard let raw = UserDefaults.standard.array(forKey: storageKey) as? [String] else { return }
        preferredSites = Set(raw.compactMap { InjectionSite(rawValue: $0) })
    }

    private func save() {
        let raw = preferredSites.map { $0.rawValue }
        UserDefaults.standard.set(raw, forKey: storageKey)
    }

    func toggle(_ site: InjectionSite) {
        if preferredSites.contains(site) {
            preferredSites.remove(site)
        } else {
            preferredSites.insert(site)
        }
    }
}
