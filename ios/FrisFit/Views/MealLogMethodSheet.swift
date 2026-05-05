import SwiftUI

struct MealLogMethodSheet: View {
    let mealTime: MealTime
    @Bindable var viewModel: NutritionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showQuickAdd: Bool = false
    @State private var showDescribe: Bool = false
    @State private var showPhoto: Bool = false
    @State private var showFoodSearch: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(PepTheme.teal)

                    Text("Log Meal")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("Choose how to add your \(mealTime.rawValue.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .padding(.top, 8)

                VStack(spacing: 12) {
                    methodButton(
                        icon: "bolt.fill",
                        title: "Quick Add",
                        subtitle: "Manually enter calories & macros",
                        color: PepTheme.teal
                    ) {
                        showQuickAdd = true
                    }

                    methodButton(
                        icon: "text.bubble.fill",
                        title: "Describe",
                        subtitle: "Tell AI what you ate for an estimate",
                        color: PepTheme.violet
                    ) {
                        showDescribe = true
                    }

                    methodButton(
                        icon: "camera.fill",
                        title: "Picture",
                        subtitle: "Snap a photo and AI estimates calories",
                        color: PepTheme.amber
                    ) {
                        showPhoto = true
                    }

                    Button {
                        showFoodSearch = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(PepTheme.elevated)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(PepTheme.textSecondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Search Database")
                                    .font(.system(.subheadline, weight: .semibold))
                                    .foregroundStyle(PepTheme.textPrimary)
                                Text("Browse 200+ foods with full nutrition info")
                                    .font(.caption)
                                    .foregroundStyle(PepTheme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        }
                        .padding(14)
                        .background(PepTheme.cardSurface)
                        .clipShape(.rect(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.scale)
                }
                .padding(.horizontal, 4)

                Spacer()
            }
            .padding(20)
            .appBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(viewModel: viewModel, mealTime: mealTime)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: $showDescribe) {
                DescribeMealView(viewModel: viewModel, mealTime: mealTime)
            }
            .fullScreenCover(isPresented: $showPhoto) {
                PhotoMealView(viewModel: viewModel, mealTime: mealTime)
            }
            .sheet(isPresented: $showFoodSearch) {
                FoodSearchView(viewModel: viewModel, selectedMealTime: mealTime)
            }
        }
    }

    private func methodButton(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(color.opacity(0.5))
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.scale)
    }
}
