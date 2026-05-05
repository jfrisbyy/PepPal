import Foundation
import SwiftUI

/// Lanes the journey map renders. Each pin lives on exactly one lane.
nonisolated enum JourneyLane: String, Codable, Sendable, CaseIterable, Identifiable {
    case body
    case compounds
    case training
    case bloodwork
    case life
    case agentAnnotation = "agent_annotation"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .body: return "Body"
        case .compounds: return "Compounds"
        case .training: return "Training"
        case .bloodwork: return "Bloodwork"
        case .life: return "Life"
        case .agentAnnotation: return "Agent"
        }
    }

    var icon: String {
        switch self {
        case .body: return "figure.arms.open"
        case .compounds: return "syringe.fill"
        case .training: return "dumbbell.fill"
        case .bloodwork: return "drop.fill"
        case .life: return "calendar"
        case .agentAnnotation: return "sparkles"
        }
    }

    /// Lanes the user sees as horizontal rows by default.
    static var visibleLanes: [JourneyLane] { [.body, .compounds, .training, .bloodwork, .life] }
}

/// Where the pin originated.
nonisolated enum JourneySourceType: String, Codable, Sendable, CaseIterable {
    case manual
    case healthkit
    case doseLog = "dose_log"
    case workout
    case bloodwork
    case agent
}

/// Optional structured payload carried per pin. Captured by the lane-specific
/// form. Encoded into Supabase as JSON in a single `payload` column.
nonisolated struct JourneyEventPayload: Codable, Sendable, Hashable {
    // Body milestone
    var weightLbs: Double?
    var bodyFatPercent: Double?
    var note: String?

    // Compound cycle (past or current)
    var compoundName: String?
    var doseAmount: Double?
    var doseUnit: String?
    var frequency: String?
    var schedule: String?
    var startDate: Date?
    var endDate: Date?
    var perceivedResults: String?
    var sideEffects: [String]?
    var reasonStopped: [String]?
    var plannedCycleWeeks: Int?
    var vialsRemaining: Int?

    // Training phase
    var phaseType: String?

    // Life event
    var lifeEventType: String?
    var shortDescription: String?

    // Agent annotation
    var annotationKind: String?
    var annotationTargetLane: String?

    init(
        weightLbs: Double? = nil,
        bodyFatPercent: Double? = nil,
        note: String? = nil,
        compoundName: String? = nil,
        doseAmount: Double? = nil,
        doseUnit: String? = nil,
        frequency: String? = nil,
        schedule: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        perceivedResults: String? = nil,
        sideEffects: [String]? = nil,
        reasonStopped: [String]? = nil,
        plannedCycleWeeks: Int? = nil,
        vialsRemaining: Int? = nil,
        phaseType: String? = nil,
        lifeEventType: String? = nil,
        shortDescription: String? = nil,
        annotationKind: String? = nil,
        annotationTargetLane: String? = nil
    ) {
        self.weightLbs = weightLbs
        self.bodyFatPercent = bodyFatPercent
        self.note = note
        self.compoundName = compoundName
        self.doseAmount = doseAmount
        self.doseUnit = doseUnit
        self.frequency = frequency
        self.schedule = schedule
        self.startDate = startDate
        self.endDate = endDate
        self.perceivedResults = perceivedResults
        self.sideEffects = sideEffects
        self.reasonStopped = reasonStopped
        self.plannedCycleWeeks = plannedCycleWeeks
        self.vialsRemaining = vialsRemaining
        self.phaseType = phaseType
        self.lifeEventType = lifeEventType
        self.shortDescription = shortDescription
        self.annotationKind = annotationKind
        self.annotationTargetLane = annotationTargetLane
    }
}

/// A single pin in the Journey Map.
nonisolated struct JourneyEvent: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    var lane: JourneyLane
    var timestamp: Date
    var durationDays: Int?
    var title: String
    var description: String?
    var sourceType: JourneySourceType
    var confidence: Double
    var attachments: [URL]
    var linkedFactIds: [UUID]
    var payload: JourneyEventPayload?

    init(
        id: UUID = UUID(),
        userId: UUID,
        lane: JourneyLane,
        timestamp: Date,
        durationDays: Int? = nil,
        title: String,
        description: String? = nil,
        sourceType: JourneySourceType,
        confidence: Double = 1.0,
        attachments: [URL] = [],
        linkedFactIds: [UUID] = [],
        payload: JourneyEventPayload? = nil
    ) {
        self.id = id
        self.userId = userId
        self.lane = lane
        self.timestamp = timestamp
        self.durationDays = durationDays
        self.title = title
        self.description = description
        self.sourceType = sourceType
        self.confidence = confidence
        self.attachments = attachments
        self.linkedFactIds = linkedFactIds
        self.payload = payload
    }

    var endDate: Date? {
        guard let d = durationDays, d > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: d, to: timestamp)
    }
}

nonisolated enum JourneyLifeEventType: String, CaseIterable, Codable, Sendable {
    case vacation
    case surgery
    case scheduleChange = "schedule_change"
    case family
    case other

    var label: String {
        switch self {
        case .vacation: return "Vacation"
        case .surgery: return "Surgery"
        case .scheduleChange: return "Schedule Change"
        case .family: return "Family"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .vacation: return "airplane"
        case .surgery: return "cross.case.fill"
        case .scheduleChange: return "calendar.badge.clock"
        case .family: return "house.fill"
        case .other: return "circle.dashed"
        }
    }
}

nonisolated enum JourneyTrainingPhase: String, CaseIterable, Codable, Sendable {
    case cut
    case bulk
    case maintenance
    case deload
    case recovery

    var label: String {
        switch self {
        case .cut: return "Cut"
        case .bulk: return "Bulk"
        case .maintenance: return "Maintenance"
        case .deload: return "Deload"
        case .recovery: return "Recovery"
        }
    }

    var icon: String {
        switch self {
        case .cut: return "flame.fill"
        case .bulk: return "arrow.up.right.circle.fill"
        case .maintenance: return "equal.circle.fill"
        case .deload: return "arrow.down.circle.fill"
        case .recovery: return "bed.double.fill"
        }
    }
}

@MainActor
extension JourneyLane {
    var color: Color {
        switch self {
        case .body: return Color(red: 76/255, green: 217/255, blue: 100/255)
        case .compounds: return PepTheme.teal
        case .training: return Color(red: 255/255, green: 149/255, blue: 0)
        case .bloodwork: return PepTheme.blue
        case .life: return PepTheme.violet
        case .agentAnnotation: return PepTheme.amber
        }
    }
}
