import SwiftUI

nonisolated enum JourneyEventType: String, Sendable {
    case dose
    case weight
    case bloodwork
    case photo
    case sideEffect
    case milestone

    var icon: String {
        switch self {
        case .dose: return "syringe.fill"
        case .weight: return "scalemass.fill"
        case .bloodwork: return "drop.fill"
        case .photo: return "camera.fill"
        case .sideEffect: return "exclamationmark.triangle.fill"
        case .milestone: return "flag.fill"
        }
    }

    var color: Color {
        switch self {
        case .dose: return PepTheme.teal
        case .weight: return Color(red: 76/255, green: 217/255, blue: 100/255)
        case .bloodwork: return PepTheme.blue
        case .photo: return PepTheme.violet
        case .sideEffect: return PepTheme.amber
        case .milestone: return Color(red: 255/255, green: 107/255, blue: 107/255)
        }
    }
}

nonisolated struct JourneyEvent: Identifiable, Sendable {
    let id: UUID
    let type: JourneyEventType
    let date: Date
    let title: String
    let subtitle: String
    let detail: String?
    let week: Int

    init(type: JourneyEventType, date: Date, title: String, subtitle: String, detail: String? = nil, week: Int) {
        self.id = UUID()
        self.type = type
        self.date = date
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.week = week
    }
}

nonisolated struct JourneyWeek: Identifiable, Sendable {
    let id: Int
    let weekNumber: Int
    let events: [JourneyEvent]
    let startDate: Date
    let endDate: Date
    let isCurrentWeek: Bool
}

@Observable
final class ProtocolJourneyViewModel {
    let protocolData: PeptideProtocol
    var weightEntries: [WeightEntry] = []
    var bloodworkEntries: [BloodworkEntry] = []
    var progressPhotos: [ProgressPhoto] = []
    var isLoading: Bool = true
    var selectedWeekFilter: Int? = nil
    var showProtocolDetail: Bool = false

    private let bodyGoalsService = BodyGoalsService.shared
    private let bloodworkService = BloodworkService.shared
    private let calendar = Calendar.current

    init(protocolData: PeptideProtocol) {
        self.protocolData = protocolData
    }

    var allEvents: [JourneyEvent] {
        var events: [JourneyEvent] = []

        for dose in protocolData.doseLog {
            let week = weekNumber(for: dose.timestamp)
            events.append(JourneyEvent(
                type: .dose,
                date: dose.timestamp,
                title: dose.compoundName,
                subtitle: CompoundUnitHelper.displayDoseShort(dose.doseMcg, for: dose.compoundName),
                detail: dose.notes.isEmpty ? dose.injectionSite.shortName : "\(dose.injectionSite.shortName) · \(dose.notes)",
                week: week
            ))
        }

        for entry in weightEntries {
            let week = weekNumber(for: entry.date)
            let changeText = weightChangeText(for: entry)
            events.append(JourneyEvent(
                type: .weight,
                date: entry.date,
                title: String(format: "%.1f lbs", entry.weight),
                subtitle: changeText,
                detail: entry.note.isEmpty ? nil : entry.note,
                week: week
            ))
        }

        for entry in bloodworkEntries {
            let week = weekNumber(for: entry.date)
            let abnormalCount = entry.results.filter { !$0.isInRange }.count
            let subtitle = abnormalCount > 0
                ? "\(entry.results.count) markers · \(abnormalCount) flagged"
                : "\(entry.results.count) markers · All normal"
            events.append(JourneyEvent(
                type: .bloodwork,
                date: entry.date,
                title: "Lab Results",
                subtitle: subtitle,
                detail: entry.notes.isEmpty ? nil : entry.notes,
                week: week
            ))
        }

        for photo in progressPhotos {
            let week = weekNumber(for: photo.date)
            events.append(JourneyEvent(
                type: .photo,
                date: photo.date,
                title: "Progress Photo",
                subtitle: photo.label.isEmpty ? (photo.category ?? "Week \(week)") : photo.label,
                week: week
            ))
        }

        for effect in protocolData.sideEffectLog {
            let week = weekNumber(for: effect.timestamp)
            let severityLabel: String
            switch effect.severity {
            case 1: severityLabel = "Mild"
            case 2: severityLabel = "Moderate"
            case 3: severityLabel = "Significant"
            default: severityLabel = "Severe"
            }
            events.append(JourneyEvent(
                type: .sideEffect,
                date: effect.timestamp,
                title: effect.effect,
                subtitle: severityLabel,
                detail: effect.notes.isEmpty ? nil : effect.notes,
                week: week
            ))
        }

        return events.sorted { $0.date > $1.date }
    }

    var journeyWeeks: [JourneyWeek] {
        let currentWeek = protocolData.currentWeek
        let totalWeeks = max(currentWeek, protocolData.effectiveTotalWeeks)
        let events = allEvents

        var weeks: [JourneyWeek] = []
        for w in (1...totalWeeks).reversed() {
            let weekEvents = events.filter { $0.week == w }
            let weekStart = calendar.date(byAdding: .day, value: (w - 1) * 7, to: protocolData.startDate) ?? protocolData.startDate
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

            weeks.append(JourneyWeek(
                id: w,
                weekNumber: w,
                events: weekEvents,
                startDate: weekStart,
                endDate: weekEnd,
                isCurrentWeek: w == currentWeek
            ))
        }

        if let filter = selectedWeekFilter {
            return weeks.filter { $0.weekNumber == filter }
        }

        return weeks
    }

    var totalDoses: Int {
        protocolData.doseLog.count
    }

    var totalWeightChange: Double? {
        guard let first = weightEntries.first, let last = weightEntries.last, weightEntries.count >= 2 else { return nil }
        return last.weight - first.weight
    }

    var totalBloodworkPanels: Int {
        bloodworkEntries.count
    }

    var totalPhotos: Int {
        progressPhotos.count
    }

    var adherenceRate: Double {
        guard protocolData.currentDay > 0 else { return 0 }
        let expectedDoses = estimateExpectedDoses()
        guard expectedDoses > 0 else { return 1.0 }
        return min(Double(totalDoses) / Double(expectedDoses), 1.0)
    }

    var weightTrend: [(date: Date, weight: Double)] {
        weightEntries.sorted { $0.date < $1.date }.map { ($0.date, $0.weight) }
    }

    func loadData() {
        Task {
            isLoading = true
            await fetchAllJourneyData()
            isLoading = false
        }
    }

    private func fetchAllJourneyData() async {
        do {
            let weights = try await bodyGoalsService.fetchWeightLogs()
            weightEntries = weights.filter { $0.date >= protocolData.startDate }
        } catch {}

        do {
            let userId = try AuthService.shared.currentUserId()
            let supaEntries = try await bloodworkService.fetchEntries(userId: userId)
            var loaded: [BloodworkEntry] = []
            for entry in supaEntries {
                guard let entryId = entry.id else { continue }
                let results = try await bloodworkService.fetchBiomarkerResults(entryId: entryId)
                let converted = bloodworkService.toBloodworkEntry(entry, results: results)
                if converted.date >= protocolData.startDate {
                    loaded.append(converted)
                }
            }
            bloodworkEntries = loaded
        } catch {}
    }

    private func weekNumber(for date: Date) -> Int {
        let days = max(0, calendar.dateComponents([.day], from: protocolData.startDate, to: date).day ?? 0)
        return days / 7 + 1
    }

    private func weightChangeText(for entry: WeightEntry) -> String {
        guard let firstWeight = weightEntries.first?.weight else { return "" }
        let change = entry.weight - firstWeight
        if abs(change) < 0.1 { return "Starting weight" }
        let sign = change > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", change)) lbs from start"
    }

    private func estimateExpectedDoses() -> Int {
        guard !protocolData.compounds.isEmpty else { return 0 }
        let days = protocolData.currentDay
        var total = 0
        for compound in protocolData.compounds {
            let freq = compound.frequency.lowercased()
            if freq.contains("daily") {
                total += days
            } else if freq.contains("twice") {
                total += days / 3
            } else if freq.contains("week") || freq.contains("7") {
                total += days / 7
            } else if freq.contains("other") || freq.contains("eod") {
                total += days / 2
            } else {
                total += days / 7
            }
        }
        return max(1, total)
    }
}
