import SwiftUI

@Observable
final class DiscoverViewModel {
    var searchText: String = ""
    var selectedCategory: PeptideCategory = .all
    var selectedSegment: DiscoverSegment = .compounds
    var compounds: [CompoundProfile] = CompoundDatabase.all
    var vendors: [Vendor] = CompoundDatabase.vendors
    var liveStats: [String: CompoundUsageStat] = [:]

    init() {
        // Apply any cached stats immediately for snappier first paint.
        liveStats = CompoundStatsService.shared.stats
        Task { await refreshLiveStats() }
    }

    enum DiscoverSegment: String, CaseIterable {
        case compounds = "Compounds"
        case vendors = "Vendors"
    }

    // MARK: - Live counts

    /// Real Supabase user count for a compound. Returns 0 when no live data
    /// is available — we intentionally do NOT fall back to the mock
    /// `communityUsers` placeholder on Discover so social stats reflect the
    /// actual community.
    func liveUserCount(for compound: CompoundProfile) -> Int {
        max(liveStats[compound.name.lowercased()]?.recent_users ?? 0, 0)
    }

    func newStarts(for compound: CompoundProfile) -> Int {
        liveStats[compound.name.lowercased()]?.new_starts_7d ?? 0
    }

    func trendingScore(for compound: CompoundProfile) -> Int {
        // Order purely by live signal. Compounds with no real users score 0.
        (liveStats[compound.name.lowercased()]?.trending_score ?? 0)
    }

    func refreshLiveStats() async {
        await CompoundStatsService.shared.loadIfNeeded()
        liveStats = CompoundStatsService.shared.stats
    }

    func forceRefreshLiveStats() async {
        await CompoundStatsService.shared.refresh()
        liveStats = CompoundStatsService.shared.stats
    }

    // MARK: - Sections

    var featuredCompounds: [CompoundProfile] {
        Array(compounds.sorted { liveUserCount(for: $0) > liveUserCount(for: $1) }.prefix(5))
    }

    var trendingCompounds: [CompoundProfile] {
        Array(compounds.sorted { trendingScore(for: $0) > trendingScore(for: $1) }.prefix(5))
    }

    var filteredCompounds: [CompoundProfile] {
        var result = selectedCategory == .all ? compounds : compounds.filter { $0.categories.contains(selectedCategory) }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedStandardContains(searchText) || $0.peptideType.localizedStandardContains(searchText) }
        }
        return result
    }

    var filteredVendors: [Vendor] {
        if searchText.isEmpty { return vendors }
        return vendors.filter { $0.name.localizedStandardContains(searchText) }
    }

    func vendors(for compoundName: String) -> [Vendor] {
        CompoundDatabase.vendors(for: compoundName)
    }
}
