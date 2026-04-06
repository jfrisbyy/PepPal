import SwiftUI

struct CompetitionChallengeSheet: View {
    @Bindable var viewModel: CirclesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var lookupResult: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("OPPONENT CIRCLE")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(FrisTheme.textSecondary)
                            .tracking(0.5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Invite Code")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                            HStack {
                                TextField("Enter code...", text: $viewModel.challengeInviteCode)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(FrisTheme.textPrimary)
                                    .textCase(.uppercase)
                                    .autocorrectionDisabled()
                                Button {
                                    lookupResult = "Iron Warriors (5 members)"
                                } label: {
                                    Text("Look Up")
                                        .font(.system(.caption, weight: .semibold))
                                        .foregroundStyle(FrisTheme.cyan)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(FrisTheme.elevated)
                            .clipShape(.rect(cornerRadius: 10))

                            if let result = lookupResult {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text(result)
                                        .font(.caption)
                                        .foregroundStyle(FrisTheme.textPrimary)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("COMPETITION DETAILS")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(FrisTheme.textSecondary)
                            .tracking(0.5)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                            TextField("e.g. January Showdown", text: $viewModel.challengeName)
                                .font(.subheadline)
                                .foregroundStyle(FrisTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(FrisTheme.elevated)
                                .clipShape(.rect(cornerRadius: 10))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(FrisTheme.textSecondary)
                            TextField("What's the challenge?", text: $viewModel.challengeDescription)
                                .font(.subheadline)
                                .foregroundStyle(FrisTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(FrisTheme.elevated)
                                .clipShape(.rect(cornerRadius: 10))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("TYPE")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(FrisTheme.textSecondary)
                            .tracking(0.5)

                        HStack(spacing: 8) {
                            ForEach(CompetitionType.allCases, id: \.self) { type in
                                Button {
                                    viewModel.challengeType = type
                                } label: {
                                    Text(type.rawValue)
                                        .font(.system(.caption, weight: .semibold))
                                        .foregroundStyle(viewModel.challengeType == type ? FrisTheme.invertedText : FrisTheme.textSecondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            viewModel.challengeType == type ? FrisTheme.cyan : FrisTheme.elevated,
                                            in: .capsule
                                        )
                                }
                            }
                        }

                        if viewModel.challengeType == .targetPoints {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Target Points")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(FrisTheme.textSecondary)
                                TextField("e.g. 50000", text: $viewModel.challengeTargetPoints)
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(FrisTheme.textPrimary)
                                    .keyboardType(.numberPad)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(FrisTheme.elevated)
                                    .clipShape(.rect(cornerRadius: 10))
                            }
                        }

                        if viewModel.challengeType == .timed {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("End Date")
                                    .font(.system(.caption, weight: .medium))
                                    .foregroundStyle(FrisTheme.textSecondary)
                                DatePicker("", selection: $viewModel.challengeEndDate, in: Date()..., displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .tint(FrisTheme.cyan)
                            }
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Send Challenge")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(FrisTheme.invertedText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(FrisTheme.cyan, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.scalePrimary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(FrisTheme.background)
            .navigationTitle("Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FrisTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(FrisTheme.background)
    }
}
