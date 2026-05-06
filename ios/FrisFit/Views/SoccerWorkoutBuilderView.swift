import SwiftUI

struct SoccerWorkoutBuilderView: View {
    @Bindable var soccerVM: SoccerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var sessionName: String = ""
    @State private var drills: [SoccerDrillItem] = [SoccerDrillItem()]

    private let accentColor = Color(red: 0.2, green: 0.78, blue: 0.35)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    savedSessionsSection
                    builderSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 10) {
                Text("TRAINING SESSIONS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor.opacity(0.9))
                Text("Build your circuit.")
                    .font(.system(size: 24, weight: .semibold, design: .serif))
                    .kerning(-0.5)
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Stack drills into a session you'll actually run — the engine behind every match.")
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var savedSessionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(
                kicker: "Saved",
                title: "Your Sessions",
                accent: accentColor,
                trailing: AnyView(
                    Text("\(soccerVM.savedSoccerSessions.count)")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(accentColor)
                )
            )

            if soccerVM.savedSoccerSessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "soccerball")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        Text("No saved sessions yet — build one below.")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 14)
                    Spacer()
                }
            } else {
                ForEach(soccerVM.savedSoccerSessions) { session in
                    savedSessionRow(session)
                }
            }
        }
        .editorialCard(accent: accentColor)
    }

    private func savedSessionRow(_ session: CustomSoccerSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.14))
                    .frame(width: 40, height: 40)
                Image(systemName: "soccerball")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 8) {
                    Label("\(session.drills.count) drills", systemImage: "list.bullet")
                    Label("~\(session.totalDuration) min", systemImage: "clock")
                }
                .font(.system(size: 10, design: .serif))
                .italic()
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Button {
                soccerVM.savedSoccerSessions.removeAll { $0.id == session.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(PepTheme.elevated.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var builderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            EditorialSectionHeading(kicker: "Build", title: "New Session", accent: accentColor)

            TextField("Session name", text: $sessionName)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)
                .padding(12)
                .background(PepTheme.elevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 10))

            ForEach(Array(drills.enumerated()), id: \.element.id) { index, _ in
                drillEditor(index: index)
            }

            Button {
                drills.append(SoccerDrillItem())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                    Text("ADD DRILL")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                }
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(accentColor.opacity(0.10))
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if !drills.isEmpty {
                sessionSummary
            }

            saveButton
        }
        .editorialCard(accent: accentColor)
    }

    private func drillEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: "DRILL %02d", index + 1))
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(accentColor)
                Spacer()
                if drills.count > 1 {
                    Button {
                        drills.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Drill name", text: $drills[index].name)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)
                .padding(10)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 8))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CATEGORY")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                    Picker("", selection: $drills[index].category) {
                        ForEach(SoccerDrillCategory.allCases) { cat in
                            HStack {
                                Image(systemName: cat.icon)
                                Text(cat.rawValue)
                            }.tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("DURATION")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(PepTheme.textSecondary)
                    Stepper("\(drills[index].durationMinutes) min", value: $drills[index].durationMinutes, in: 1...60, step: 5)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }

            TextField("Notes (optional)", text: $drills[index].notes)
                .font(.system(size: 12, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .tint(accentColor)
                .padding(8)
                .background(PepTheme.elevated.opacity(0.3))
                .clipShape(.rect(cornerRadius: 8))
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var sessionSummary: some View {
        let totalMin = drills.reduce(0) { $0 + $1.durationMinutes }
        let categories = Set(drills.map(\.category)).count
        return HStack(spacing: 0) {
            summaryCol(value: "~\(totalMin)", unit: "min", label: "TOTAL")
            divider
            summaryCol(value: "\(drills.count)", unit: "", label: "DRILLS")
            divider
            summaryCol(value: "\(categories)", unit: "", label: "CATEGORIES")
        }
        .padding(.vertical, 12)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 0.5, height: 26)
    }

    private func summaryCol(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(.subheadline, design: .serif, weight: .semibold))
                    .foregroundStyle(accentColor)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(accentColor.opacity(0.7))
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var saveButton: some View {
        let canSave = !sessionName.trimmingCharacters(in: .whitespaces).isEmpty
            && drills.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespaces).isEmpty })
        return EditorialPrimaryButton("Save Session", icon: "checkmark.circle.fill", accent: accentColor) {
            guard canSave else { return }
            let session = CustomSoccerSession(name: sessionName, drills: drills)
            soccerVM.savedSoccerSessions.append(session)
            sessionName = ""
            drills = [SoccerDrillItem()]
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .opacity(canSave ? 1 : 0.5)
        .disabled(!canSave)
    }
}
