import SwiftUI

struct BasketballWeeklyFocusView: View {
    @Bindable var bbVM: BasketballViewModel
    @Environment(\.dismiss) private var dismiss

    private let accentColor = BasketballPalette.courtAmber

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    skillSwitcher
                    recommendedDrillsCard
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .appBackground(accent: accentColor)
            .navigationTitle("Weekly Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(accentColor)
                }
            }
        }
    }

    private var heroCard: some View {
        PepSportCard(accent: accentColor) {
            VStack(alignment: .leading, spacing: 12) {
                Text("THIS WEEK'S FOCUS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(accentColor)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(accentColor.opacity(0.14))
                            .frame(width: 56, height: 56)
                        Image(systemName: bbVM.weeklyFocus.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(accentColor)
                    }
                    Text(bbVM.weeklyFocus.rawValue)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)
                }

                Text(bbVM.weeklyFocus.blurb)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundStyle(PepTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var skillSwitcher: some View {
        VStack(alignment: .leading, spacing: 10) {
            EditorialSectionHeading(kicker: "Swap focus", title: "Pick a Skill", accent: accentColor)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(BasketballFocusSkill.allCases) { skill in
                    let isActive = bbVM.weeklyFocus == skill
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            bbVM.weeklyFocus = skill
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: skill.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(isActive ? .black : skill.primaryCategory.color)
                            Text(skill.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isActive ? .black : PepTheme.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isActive ? accentColor : PepTheme.cardSurface)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(isActive ? .clear : PepTheme.glassBorderTop, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.selection, trigger: isActive)
                }
            }
        }
    }

    private var recommendedDrillsCard: some View {
        let drills = BasketballDrillLibrary.all
            .filter { $0.category == bbVM.weeklyFocus.primaryCategory }
            .prefix(6)
        return VStack(alignment: .leading, spacing: 12) {
            EditorialSectionHeading(kicker: "Recommended", title: "Drills to Run", accent: bbVM.weeklyFocus.primaryCategory.color)
            VStack(spacing: 8) {
                ForEach(Array(drills), id: \.id) { drill in
                    Button {
                        bbVM.selectedDrill = drill
                        bbVM.showDrillDetail = true
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: drill.category.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(drill.category.color)
                                .frame(width: 32, height: 32)
                                .background(drill.category.color.opacity(0.12))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(drill.name)
                                    .font(.system(size: 13, weight: .semibold, design: .serif))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text(drill.purpose)
                                    .font(.system(size: 10, design: .serif))
                                    .italic()
                                    .foregroundStyle(PepTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(drill.durationMinutes)m")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(PepTheme.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        }
                        .padding(12)
                        .background(PepTheme.cardSurface)
                        .clipShape(.rect(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
