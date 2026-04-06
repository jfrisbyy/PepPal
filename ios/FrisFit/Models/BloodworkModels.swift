import SwiftUI

nonisolated enum Biomarker: String, CaseIterable, Identifiable, Sendable {
    case igf1 = "IGF-1"
    case testosteroneTotal = "Testosterone (Total)"
    case testosteroneFree = "Testosterone (Free)"
    case a1c = "A1C"
    case fastingGlucose = "Fasting Glucose"
    case fastingInsulin = "Fasting Insulin"
    case ast = "AST"
    case alt = "ALT"
    case totalCholesterol = "Total Cholesterol"
    case hdl = "HDL"
    case ldl = "LDL"
    case triglycerides = "Triglycerides"
    case tsh = "TSH"
    case t3 = "T3"
    case t4 = "T4"
    case creatinine = "Creatinine"
    case bun = "BUN"

    var id: String { rawValue }

    var unit: String {
        switch self {
        case .igf1: return "ng/mL"
        case .testosteroneTotal: return "ng/dL"
        case .testosteroneFree: return "pg/mL"
        case .a1c: return "%"
        case .fastingGlucose: return "mg/dL"
        case .fastingInsulin: return "µIU/mL"
        case .ast, .alt: return "U/L"
        case .totalCholesterol, .hdl, .ldl, .triglycerides: return "mg/dL"
        case .tsh: return "mIU/L"
        case .t3: return "pg/mL"
        case .t4: return "ng/dL"
        case .creatinine: return "mg/dL"
        case .bun: return "mg/dL"
        }
    }

    var category: BiomarkerCategory {
        switch self {
        case .igf1: return .hormones
        case .testosteroneTotal, .testosteroneFree: return .hormones
        case .a1c, .fastingGlucose, .fastingInsulin: return .metabolic
        case .ast, .alt: return .liver
        case .totalCholesterol, .hdl, .ldl, .triglycerides: return .lipids
        case .tsh, .t3, .t4: return .thyroid
        case .creatinine, .bun: return .kidney
        }
    }

    var normalRange: ClosedRange<Double> {
        switch self {
        case .igf1: return 100...350
        case .testosteroneTotal: return 300...1000
        case .testosteroneFree: return 5...25
        case .a1c: return 4.0...5.6
        case .fastingGlucose: return 70...100
        case .fastingInsulin: return 2...25
        case .ast: return 10...40
        case .alt: return 7...56
        case .totalCholesterol: return 0...200
        case .hdl: return 40...100
        case .ldl: return 0...100
        case .triglycerides: return 0...150
        case .tsh: return 0.4...4.0
        case .t3: return 2.3...4.2
        case .t4: return 0.8...1.8
        case .creatinine: return 0.6...1.2
        case .bun: return 7...20
        }
    }
}

nonisolated enum BiomarkerCategory: String, CaseIterable, Sendable {
    case hormones = "Hormones"
    case metabolic = "Metabolic"
    case liver = "Liver"
    case lipids = "Lipids"
    case thyroid = "Thyroid"
    case kidney = "Kidney"

    var icon: String {
        switch self {
        case .hormones: return "waveform.path.ecg"
        case .metabolic: return "flame.fill"
        case .liver: return "cross.case.fill"
        case .lipids: return "heart.fill"
        case .thyroid: return "bolt.fill"
        case .kidney: return "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .hormones: return PepTheme.teal
        case .metabolic: return .orange
        case .liver: return .green
        case .lipids: return .red
        case .thyroid: return PepTheme.violet
        case .kidney: return PepTheme.blue
        }
    }
}

nonisolated struct BloodworkEntry: Identifiable, Sendable {
    let id: UUID
    let date: Date
    var results: [BiomarkerResult]
    var photoData: Data?
    var notes: String

    init(date: Date = Date(), results: [BiomarkerResult] = [], photoData: Data? = nil, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.results = results
        self.photoData = photoData
        self.notes = notes
    }
}

nonisolated struct BiomarkerResult: Identifiable, Sendable {
    let id: UUID
    let biomarker: Biomarker
    let value: Double

    init(biomarker: Biomarker, value: Double) {
        self.id = UUID()
        self.biomarker = biomarker
        self.value = value
    }

    var isInRange: Bool {
        biomarker.normalRange.contains(value)
    }

    var status: BiomarkerStatus {
        if value < biomarker.normalRange.lowerBound { return .low }
        if value > biomarker.normalRange.upperBound { return .high }
        return .normal
    }
}

nonisolated enum BiomarkerStatus: String, Sendable {
    case low = "Low"
    case normal = "Normal"
    case high = "High"

    var color: Color {
        switch self {
        case .low: return PepTheme.blue
        case .normal: return .green
        case .high: return .red
        }
    }
}
