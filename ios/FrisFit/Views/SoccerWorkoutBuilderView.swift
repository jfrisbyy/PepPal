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
                VStack(spacing: 16) {
                    savedSessionsSection
                    builderSection
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground()
            .navigationTitle("Training Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
    }

    private var savedSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Saved Sessions")
                Spacer()
                Text("\(soccerVM.savedSoccerSessions.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
            }

            if soccerVM.savedSoccerSessions.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "soccerball")
                            .font(.title2)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        Text("No saved training sessions yet")
                            .font(.caption)
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
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func savedSessionRow(_ session: CustomSoccerSession) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "soccerball")
                    .font(.system(size: 16))
                    .foregroundStyle(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(session.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                HStack(spacing: 8) {
                    Label("\(session.drills.count) drills", systemImage: "list.bullet")
                    Label("~\(session.totalDuration) min", systemImage: "clock")
                }
                .font(.system(size: 10, weight: .medium))
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
        }
        .padding(.vertical, 4)
    }

    private var builderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "plus.square.fill")
                    .foregroundStyle(accentColor)
                HeadlineText(text: "Build Training Session")
                Spacer()
            }

            TextField("Session Name", text: $sessionName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
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
                    Text("Add Drill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(accentColor.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }

            if !drills.isEmpty {
                sessionSummary
            }

            saveButton
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(cardBorder())
    }

    private func drillEditor(index: Int) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Drill \(index + 1)")
                    .font(.system(size: 11, weight: .bold))
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
                }
            }

            TextField("Drill name", text: $drills[index].name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(10)
                .background(PepTheme.elevated.opacity(0.4))
                .clipShape(.rect(cornerRadius: 8))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Category")
                        .font(.system(size: 9, weight: .medium))
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
                    Text("Duration")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                    Stepper("\(drills[index].durationMinutes) min", value: $drills[index].durationMinutes, in: 1...60, step: 5)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                }
            }

            TextField("Notes (optional)", text: $drills[index].notes)
                .font(.system(size: 12))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(8)
                .background(PepTheme.elevated.opacity(0.3))
                .clipShape(.rect(cornerRadius: 8))
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var sessionSummary: some View {
        HStack(spacing: 16) {
            let totalMin = drills.reduce(0) { $0 + $1.durationMinutes }
            let categories = Set(drills.map(\.category)).count
            VStack(spacing: 2) {
                Text("~\(totalMin) min")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                Text("Total Duration")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            VStack(spacing: 2) {
                Text("\(drills.count)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Drills")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            VStack(spacing: 2) {
                Text("\(categories)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("Categories")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(PepTheme.elevated.opacity(0.3))
        .clipShape(.rect(cornerRadius: 10))
    }

    private var saveButton: some View {
        let canSave = !sessionName.trimmingCharacters(in: .whitespaces).isEmpty && drills.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespaces).isEmpty })
        return Button {
            guard canSave else { return }
            let session = CustomSoccerSession(name: sessionName, drills: drills)
            soccerVM.savedSoccerSessions.append(session)
            sessionName = ""
            drills = [SoccerDrillItem()]
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("Save Session")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accentColor)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.scalePrimary)
        .opacity(canSave ? 1 : 0.5)
        .disabled(!canSave)
    }

    private func cardBorder() -> some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                LinearGradient(colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 0.5
            )
    }
}
