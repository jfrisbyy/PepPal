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

    func liveUserCount(for compound: CompoundProfile) -> Int {
        if let s = liveStats[compound.name.lowercased()], s.recent_users > 0 {
            return s.recent_users
        }
        return compound.communityUsers
    }

    func newStarts(for compound: CompoundProfile) -> Int {
        liveStats[compound.name.lowercased()]?.new_starts_7d ?? 0
    }

    func trendingScore(for compound: CompoundProfile) -> Int {
        if let s = liveStats[compound.name.lowercased()] {
            // If we have live data, prefer it. Mix in mock as a tiny tiebreaker
            // so brand-new compounds with no real signal still get some ordering.
            return s.trending_score * 1000 + (compound.communityUsers / 100)
        }
        // No live signal yet — use mock community users so the rail isn't empty on
        // first launch.
        return compound.communityUsers
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
