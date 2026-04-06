import SwiftUI

struct CircleSettingsSheet: View {
    @Bindable var viewModel: CirclesViewModel
    let circle: FitCircle
    @Environment(\.dismiss) private var dismiss

    @State private var editName: String
    @State private var editDescription: String
    @State private var editDailyGoal: String
    @State private var editWeeklyGoal: String
    @State private var editIsPrivate: Bool
    @State private var showDeleteConfirmation: Bool = false
    @State private var showInviteCode: Bool = false

    init(viewModel: CirclesViewModel, circle: FitCircle) {
        self.viewModel = viewModel
        self.circle = circle
        _editName = State(initialValue: circle.name)
        _editDescription = State(initialValue: circle.description)
        _editDailyGoal = State(initialValue: circle.dailyPointGoal.map(String.init) ?? "")
        _editWeeklyGoal = State(initialValue: circle.weeklyPointGoal.map(String.init) ?? "")
        _editIsPrivate = State(initialValue: circle.isPrivate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    settingsSection
                    inviteCodeSection
                    membersSection
                    dangerZone
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(PepTheme.background)
            .navigationTitle("Circle Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        dismiss()
                    }
                    .foregroundStyle(PepTheme.teal)
                    .font(.system(.body, weight: .semibold))
                }
            }
            .alert("Delete Circle?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    viewModel.leaveCircle(circle)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This action cannot be undone. All data will be permanently deleted.")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(PepTheme.background)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GENERAL")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.5)

            VStack(spacing: 12) {
                SettingsField(label: "Name", text: $editName)
                SettingsField(label: "Description", text: $editDescription)
                SettingsField(label: "Daily Goal", text: $editDailyGoal, keyboardType: .numberPad)
                SettingsField(label: "Weekly Goal", text: $editWeeklyGoal, keyboardType: .numberPad)

                HStack {
                    Text("Private")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textPrimary)
                    Spacer()
                    Toggle("", isOn: $editIsPrivate)
                        .tint(PepTheme.teal)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var inviteCodeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INVITE CODE")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.5)

            HStack {
                Text(circle.inviteCode)
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
                Spacer()
                Button {
                    UIPasteboard.general.string = circle.inviteCode
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .padding(14)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MEMBERS (\(circle.memberCount))")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(circle.members) { member in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(member.user.avatarColor.opacity(0.2))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(member.user.avatarInitial)
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(member.user.avatarColor)
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.user.name)
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundStyle(PepTheme.textPrimary)
                            Text(member.role.rawValue)
                                .font(.caption2)
                                .foregroundStyle(member.role.color)
                        }

                        Spacer()

                        if member.role != .owner && viewModel.currentUserRole == .owner {
                            Menu {
                                Button("Make Admin") {}
                                Button("Remove", role: .destructive) {}
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.subheadline)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.vertical, 10)

                    if member.id != circle.members.last?.id {
                        Divider().overlay(PepTheme.separatorColor)
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(PepTheme.elevated)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DANGER ZONE")
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.red.opacity(0.7))
                .tracking(0.5)

            if viewModel.currentUserRole == .owner {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete Circle")
                    }
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.red.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }

            Button {
                viewModel.leaveCircle(circle)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                    Text("Leave Circle")
                }
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }
}

struct SettingsField: View {
    let label: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            TextField(label, text: $text)
                .font(.subheadline)
                .foregroundStyle(PepTheme.textPrimary)
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 10))
        }
    }
}
