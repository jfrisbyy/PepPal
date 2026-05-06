import SwiftUI

struct MartialArtsWorkoutBuilderView: View {
    @Bindable var maVM: MartialArtsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var sessionName: String = ""
    @State private var draftDiscipline: MartialArtsDiscipline = .bjj
    @State private var draftDrills: [MartialArtsDrillItem] = []
    @State private var showDrillPicker: Bool = false

    private var accentColor: Color { draftDiscipline.color }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    nameSection
                    disciplineSection
                    drillsSection
                    if !maVM.savedSessions.isEmpty {
                        savedSessionsSection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? accentColor : PepTheme.textSecondary)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showDrillPicker) {
                drillPickerSheet
                    .presentationDetents([.large])
            }
            .onAppear {
                draftDiscipline = maVM.primaryDiscipline
            }
        }
    }

    private var canSave: Bool {
        !sessionName.trimmingCharacters(in: .whitespaces).isEmpty && !draftDrills.isEmpty
    }

    private var totalDuration: Int { draftDrills.reduce(0) { $0 + $1.durationMinutes } }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(draftDiscipline.rawValue.uppercased()) · BUILDER")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.95))
                Text("Stack the session.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Pick the drills, set the order, save it for next time. \(totalDuration > 0 ? "\(totalDuration) min total." : "")")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "01 — Name", title: "Call it something", accent: accentColor)
            TextField("e.g. Pre-Comp Sharpening, Tuesday Pad Work", text: $sessionName)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    private var disciplineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "02 — Discipline", title: "Style", accent: PepTheme.violet)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(MartialArtsDiscipline.allCases) { d in
                        let isSelected = draftDiscipline == d
                        Button {
                            draftDiscipline = d
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: d.icon)
                                    .font(.system(size: 11))
                                Text(d.rawValue)
                                    .font(.system(size: 11, weight: .semibold, design: .serif))
                            }
                            .foregroundStyle(isSelected ? .black : d.color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(isSelected ? d.color : d.color.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "03 — Drills",
                title: "The Sequence",
                accent: PepTheme.amber,
                trailing: AnyView(
                    Button {
                        showDrillPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13))
                            Text("ADD")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.4)
                        }
                        .foregroundStyle(accentColor)
                    }
                )
            )

            if draftDrills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.title2)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    Text("No drills yet — tap Add to start stacking.")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(draftDrills.enumerated()), id: \.element.id) { idx, item in
                        drillRow(idx: idx, item: item)
                    }
                }
            }
        }
        .editorialCard(accent: PepTheme.amber)
    }

    private func drillRow(idx: Int, item: MartialArtsDrillItem) -> some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", idx + 1))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(accentColor)
                .frame(width: 24, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.drillName)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("\(item.durationMinutes) min")
                    .font(.system(size: 10, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
            Button {
                draftDrills.removeAll { $0.id == item.id }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var savedSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Saved", title: "Past Sessions", accent: PepTheme.violet)
            VStack(spacing: 8) {
                ForEach(maVM.savedSessions) { session in
                    HStack {
                        ZStack {
                            Circle()
                                .fill(session.discipline.color.opacity(0.14))
                                .frame(width: 32, height: 32)
                            Image(systemName: session.discipline.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(session.discipline.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name)
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text("\(session.discipline.rawValue) · \(session.drills.count) drills · \(session.totalDuration) min")
                                .font(.system(size: 10, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            maVM.savedSessions.removeAll { $0.id == session.id }
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .editorialCard(accent: PepTheme.violet)
    }

    private var drillPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(MartialArtsDrillLibrary.filtered(discipline: draftDiscipline)) { drill in
                        Button {
                            draftDrills.append(MartialArtsDrillItem(drillName: drill.name, durationMinutes: drill.durationMinutes))
                            showDrillPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(drill.discipline.color.opacity(0.16))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: drill.category.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(drill.discipline.color)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(drill.name)
                                        .font(.system(size: 13, weight: .semibold, design: .serif))
                                        .foregroundStyle(PepTheme.textPrimary)
                                        .lineLimit(1)
                                    Text("\(drill.category.rawValue) · \(drill.durationMinutes) min")
                                        .font(.system(size: 10, design: .serif))
                                        .italic()
                                        .foregroundStyle(PepTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(accentColor)
                            }
                            .padding(12)
                            .background(PepTheme.cardSurface)
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("Add Drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDrillPicker = false }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private func save() {
        let trimmed = sessionName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !draftDrills.isEmpty else { return }
        let session = CustomMartialArtsSession(name: trimmed, discipline: draftDiscipline, drills: draftDrills)
        maVM.savedSessions.insert(session, at: 0)
        dismiss()
    }
}
