import SwiftUI

struct VolleyballWorkoutBuilderView: View {
    @Bindable var volleyballVM: VolleyballViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var sessionName: String = ""
    @State private var draftDrills: [VolleyballDrillItem] = []
    @State private var showDrillPicker: Bool = false

    private let accentColor = Color(red: 0.95, green: 0.30, blue: 0.20)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    nameSection
                    drillsSection
                    if !volleyballVM.savedSessions.isEmpty {
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
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canSave ? accentColor : PepTheme.textSecondary)
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showDrillPicker) {
                drillPickerSheet
                    .presentationDetents([.large])
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
                Text("VOLLEYBALL · BUILDER")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.9))
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
            TextField("e.g. Tuesday Skills, Pre-Match Warmup", text: $sessionName)
                .font(.system(size: 14, design: .serif))
                .padding(12)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 10))
        }
        .editorialCard(accent: accentColor)
    }

    private var drillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(
                kicker: "02 — Drills",
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

    private func drillRow(idx: Int, item: VolleyballDrillItem) -> some View {
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
                ForEach(volleyballVM.savedSessions) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name)
                                .font(.system(size: 13, weight: .semibold, design: .serif))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text("\(session.drills.count) drills · \(session.totalDuration) min")
                                .font(.system(size: 10, design: .serif))
                                .italic()
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            volleyballVM.savedSessions.removeAll { $0.id == session.id }
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
                    ForEach(VolleyballDrillLibrary.all) { drill in
                        Button {
                            draftDrills.append(VolleyballDrillItem(drillName: drill.name, durationMinutes: drill.durationMinutes))
                            showDrillPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(drill.category.color.opacity(0.16))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: drill.category.icon)
                                        .font(.system(size: 14))
                                        .foregroundStyle(drill.category.color)
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
        let session = CustomVolleyballSession(name: trimmed, drills: draftDrills)
        volleyballVM.savedSessions.insert(session, at: 0)
        dismiss()
    }
}
