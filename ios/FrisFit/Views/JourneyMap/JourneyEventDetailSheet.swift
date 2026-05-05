import SwiftUI

struct JourneyEventDetailSheet: View {
    let event: JourneyEvent
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(event.lane.color.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: event.lane.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(event.lane.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.headline)
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(event.lane.title)
                                .font(.caption)
                                .foregroundStyle(event.lane.color)
                        }
                    }
                }

                Section("When") {
                    LabeledContent("Timestamp", value: event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    if let d = event.durationDays, d > 0 {
                        LabeledContent("Duration", value: "\(d) day\(d == 1 ? "" : "s")")
                    }
                    if let end = event.endDate {
                        LabeledContent("End", value: end.formatted(date: .abbreviated, time: .omitted))
                    }
                }

                if let desc = event.description, !desc.isEmpty {
                    Section("Description") {
                        Text(desc)
                            .foregroundStyle(PepTheme.textPrimary)
                    }
                }

                payloadSection

                Section("Source") {
                    LabeledContent("Type", value: event.sourceType.rawValue)
                    LabeledContent("Confidence", value: "\(Int(event.confidence * 100))%")
                }

                if !event.attachments.isEmpty {
                    Section("Attachments") {
                        ForEach(event.attachments, id: \.self) { url in
                            Link(destination: url) {
                                Label(url.lastPathComponent, systemImage: "paperclip")
                            }
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete pin", systemImage: "trash")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Pin Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Delete this pin?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task {
                        await JourneyEventService.shared.delete(event)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var payloadSection: some View {
        if let p = event.payload {
            Section("Details") {
                if let v = p.weightLbs { LabeledContent("Weight", value: String(format: "%.1f lbs", v)) }
                if let v = p.bodyFatPercent { LabeledContent("Body fat", value: String(format: "%.1f%%", v)) }
                if let v = p.compoundName { LabeledContent("Compound", value: v) }
                if let v = p.doseAmount, let unit = p.doseUnit {
                    LabeledContent("Dose", value: String(format: "%g \(unit)", v))
                }
                if let v = p.frequency { LabeledContent("Frequency", value: v) }
                if let v = p.schedule { LabeledContent("Schedule", value: v) }
                if let v = p.startDate { LabeledContent("Start", value: v.formatted(date: .abbreviated, time: .omitted)) }
                if let v = p.endDate { LabeledContent("End", value: v.formatted(date: .abbreviated, time: .omitted)) }
                if let v = p.plannedCycleWeeks { LabeledContent("Planned weeks", value: "\(v)") }
                if let v = p.vialsRemaining { LabeledContent("Vials remaining", value: "\(v)") }
                if let v = p.perceivedResults, !v.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Perceived results").font(.caption).foregroundStyle(PepTheme.textSecondary)
                        Text(v)
                    }
                }
                if let arr = p.sideEffects, !arr.isEmpty {
                    LabeledContent("Side effects", value: arr.joined(separator: ", "))
                }
                if let arr = p.reasonStopped, !arr.isEmpty {
                    LabeledContent("Reason stopped", value: arr.joined(separator: ", "))
                }
                if let v = p.phaseType, let phase = JourneyTrainingPhase(rawValue: v) {
                    LabeledContent("Phase", value: phase.label)
                }
                if let v = p.lifeEventType, let life = JourneyLifeEventType(rawValue: v) {
                    LabeledContent("Type", value: life.label)
                }
                if let v = p.shortDescription, !v.isEmpty {
                    LabeledContent("Description", value: v)
                }
                if let v = p.note, !v.isEmpty {
                    LabeledContent("Note", value: v)
                }
            }
        }
    }
}
