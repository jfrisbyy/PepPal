import SwiftUI

struct RoutinesListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = RoutineStore.shared
    @State private var showEditor: Bool = false
    @State private var editingRoutine: Routine? = nil
    @State private var showPrograms: Bool = false
    var trainViewModel: TrainViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if store.routines.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.routines) { routine in
                            NavigationLink(value: routine) {
                                RoutineCard(routine: routine)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    store.duplicate(routine)
                                } label: {
                                    Label("Duplicate", systemImage: "plus.square.on.square")
                                }
                                Button(role: .destructive) {
                                    store.delete(routine.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }

                    programsFooter
                        .padding(.top, 8)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .appBackground()
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(PepTheme.teal)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingRoutine = nil
                        showEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }
            }
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine, trainViewModel: trainViewModel)
            }
            .sheet(isPresented: $showEditor) {
                RoutineEditorView(existing: editingRoutine)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showPrograms) {
                ProgramManagementView(viewModel: trainViewModel)
                    .presentationDetents([.large])
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle.portrait")
                .font(.system(size: 44))
                .foregroundStyle(PepTheme.teal.opacity(0.7))
            Text("No Routines Yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Save your favorite workouts as routines to start them with one tap. Log a workout and tap Save as Routine when you're done.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                editingRoutine = nil
                showEditor = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("New Routine")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(PepTheme.teal)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var programsFooter: some View {
        Button {
            showPrograms = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PepTheme.violet)
                    .frame(width: 36, height: 36)
                    .background(PepTheme.violet.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Multi-Week Programs")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Structured plans with progression")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RoutineCard: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(routine.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(metaLine)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
            }

            if !routine.muscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(routine.muscleGroups, id: \.self) { muscle in
                            HStack(spacing: 4) {
                                Image(systemName: muscle.icon)
                                    .font(.system(size: 9))
                                Text(muscle.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(PepTheme.teal)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PepTheme.teal.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var metaLine: String {
        var parts: [String] = ["\(routine.exercises.count) exercises"]
        parts.append("~\(routine.estimatedMinutes)m")
        if let last = routine.lastPerformedAt {
            parts.append("Last: \(relativeDate(last))")
        } else if routine.timesPerformed == 0 {
            parts.append("New")
        }
        return parts.joined(separator: " · ")
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
