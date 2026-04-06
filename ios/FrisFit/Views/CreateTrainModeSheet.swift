import SwiftUI

struct CreateTrainModeSheet: View {
    @Bindable var viewModel: TrainViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var customName: String = ""
    @State private var selectedType: TrainModeType = .custom
    @State private var selectedCards: Set<TrainCardType> = [.sportSessions, .sportStats, .sportHistory, .goals]

    private let sportCardOptions: [TrainCardType] = [
        .sportSessions, .sportStats, .weeklyDistance, .paceChart,
        .gameLog, .shootingStats, .lapTracker, .goals, .sportHistory
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    nameSection
                    iconSection
                    cardsSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(FrisTheme.background.ignoresSafeArea())
            .navigationTitle("Create Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(FrisTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        createMode()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canCreate ? FrisTheme.cyan : FrisTheme.textSecondary)
                    .disabled(!canCreate)
                }
            }
        }
    }

    private var canCreate: Bool {
        !customName.trimmingCharacters(in: .whitespaces).isEmpty && !selectedCards.isEmpty
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODE NAME")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FrisTheme.textSecondary)
                .tracking(1.2)

            TextField("e.g. Boxing, Hiking, Martial Arts", text: $customName)
                .font(.body)
                .foregroundStyle(FrisTheme.textPrimary)
                .padding(14)
                .background(FrisTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(FrisTheme.glassBorderTop, lineWidth: 0.5)
                )
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BASED ON")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FrisTheme.textSecondary)
                .tracking(1.2)

            let types: [TrainModeType] = [.custom, .running, .cycling, .swimming, .basketball, .soccer, .tennis, .football]

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                ForEach(types) { type in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedType = type
                            selectedCards = Set(type.defaultCards)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(selectedType == type ? type.color : FrisTheme.textSecondary)
                            Text(type == .custom ? "General" : type.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(selectedType == type ? FrisTheme.textPrimary : FrisTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selectedType == type ? type.color.opacity(0.1) : FrisTheme.cardSurface)
                        .clipShape(.rect(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    selectedType == type ? type.color.opacity(0.3) : FrisTheme.glassBorderTop,
                                    lineWidth: selectedType == type ? 1 : 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var cardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DASHBOARD CARDS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(FrisTheme.textSecondary)
                .tracking(1.2)

            ForEach(sportCardOptions) { card in
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        if selectedCards.contains(card) {
                            selectedCards.remove(card)
                        } else {
                            selectedCards.insert(card)
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: card.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(selectedCards.contains(card) ? selectedType.color : FrisTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(selectedCards.contains(card) ? selectedType.color.opacity(0.12) : FrisTheme.elevated)
                            .clipShape(Circle())

                        Text(card.rawValue)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(FrisTheme.textPrimary)

                        Spacer()

                        Image(systemName: selectedCards.contains(card) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selectedCards.contains(card) ? selectedType.color : FrisTheme.glassBorderTop)
                    }
                    .padding(12)
                    .background(FrisTheme.cardSurface)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func createMode() {
        var mode = TrainMode(type: selectedType, customSportName: customName)
        mode.cards = Array(selectedCards)
        viewModel.addMode(mode)
        dismiss()
    }
}
