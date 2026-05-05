import SwiftUI

nonisolated enum BiomarkerKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case weight = "Weight"
    case hba1c = "HbA1c"
    case fastingGlucose = "Fasting Glucose"
    case restingHR = "Resting HR"
    case sleepScore = "Sleep Score"
    case bodyFat = "Body Fat %"
    case waist = "Waist"
    case bloodPressure = "Systolic BP"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .weight: return "lb"
        case .hba1c: return "%"
        case .fastingGlucose: return "mg/dL"
        case .restingHR: return "bpm"
        case .sleepScore: return "/100"
        case .bodyFat: return "%"
        case .waist: return "in"
        case .bloodPressure: return "mmHg"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .hba1c: return "drop.fill"
        case .fastingGlucose: return "drop.halffull"
        case .restingHR: return "heart.fill"
        case .sleepScore: return "moon.stars.fill"
        case .bodyFat: return "figure"
        case .waist: return "ruler.fill"
        case .bloodPressure: return "waveform.path.ecg"
        }
    }

    var color: Color {
        switch self {
        case .weight: return PepTheme.teal
        case .hba1c, .fastingGlucose: return PepTheme.amber
        case .restingHR, .bloodPressure: return .red
        case .sleepScore: return PepTheme.violet
        case .bodyFat: return .orange
        case .waist: return PepTheme.blue
        }
    }

    var betterDirection: Direction {
        switch self {
        case .weight, .hba1c, .fastingGlucose, .restingHR, .bodyFat, .waist, .bloodPressure: return .down
        case .sleepScore: return .up
        }
    }

    enum Direction: Sendable { case up, down }
}

nonisolated struct BiomarkerEntry: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let kind: BiomarkerKind
    let value: Double
    let date: Date
    let note: String

    init(id: UUID = UUID(), kind: BiomarkerKind, value: Double, date: Date = Date(), note: String = "") {
        self.id = id
        self.kind = kind
        self.value = value
        self.date = date
        self.note = note
    }
}

@Observable
@MainActor
final class BiomarkerStore {
    static let shared = BiomarkerStore()

    private let storageKey = "peppal.biomarkers.v1"
    var entries: [BiomarkerEntry] = [] { didSet { save() } }

    private init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BiomarkerEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func add(_ entry: BiomarkerEntry) {
        entries.insert(entry, at: 0)
    }

    func remove(_ entry: BiomarkerEntry) {
        entries.removeAll { $0.id == entry.id }
    }

    func latest(_ kind: BiomarkerKind) -> BiomarkerEntry? {
        entries.filter { $0.kind == kind }.max(by: { $0.date < $1.date })
    }

    func series(_ kind: BiomarkerKind, within days: Int = 180) -> [BiomarkerEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date.distantPast
        return entries
            .filter { $0.kind == kind && $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    func delta(_ kind: BiomarkerKind, windowDays: Int = 30) -> (change: Double, percent: Double)? {
        let pts = series(kind, within: windowDays)
        guard let first = pts.first, let last = pts.last, first.id != last.id, first.value != 0 else { return nil }
        let change = last.value - first.value
        return (change, change / first.value * 100)
    }
}
