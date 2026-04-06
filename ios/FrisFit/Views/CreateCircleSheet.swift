import SwiftUI

struct CreateCircleSheet: View {
    @Bindable var viewModel: CirclesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Circle Name")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            TextField("e.g. Gym Bros", text: $viewModel.createName)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary)
                            TextField("What's this circle about?", text: $viewModel.createDescription, axis: .vertical)
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textPrimary)
                                .lineLimit(3...5)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(PepTheme.elevated)
                                .clipShape(.rect(cornerRadius: 12))
                        }
                    }

                    VStack(spacing: 12) {
                        Text("GOALS (OPTIONAL)")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            GoalField(label: "Daily Goal", text: $viewModel.createDailyGoal, icon: "sun.max.fill", color: PepTheme.amber)
                            GoalField(label: "Weekly Goal", text: $viewModel.createWeeklyGoal, icon: "calendar", color: PepTheme.teal)
                        }
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Private Circle")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text("Only invited members can join")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $viewModel.createIsPrivate)
                            .tint(PepTheme.teal)
                    }
                    .padding(14)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))

                    Button {
                        viewModel.createCircle()
                    } label: {
                        Text("Create Circle")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(PepTheme.invertedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                viewModel.createName.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? PepTheme.textSecondary.opacity(0.3)
                                    : PepTheme.teal,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(.scalePrimary)
                    .disabled(viewModel.createName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(PepTheme.background)
            .navigationTitle("Create Circle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(PepTheme.background)
    }
}

struct GoalField: View {
    let label: String
    @Binding var text: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            TextField("0", text: $text)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .keyboardType(.numberPad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}
