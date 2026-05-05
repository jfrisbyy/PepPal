import SwiftUI

struct NutritionResultView: View {
    let capturedImage: UIImage
    @Binding var estimatedItems: [EstimatedFoodItem]
    let overlays: [PhotoFoodOverlay]
    let mealTime: MealTime
    let onAddAll: () -> Void
    let onRetake: () -> Void
    let onDismiss: () -> Void
    var onSaveMeal: ((_ name: String, _ calories: Int, _ protein: Double, _ carbs: Double, _ fat: Double) -> Void)? = nil

    @State private var showClarifySheet: Bool = false
    @State private var selectedItemIndex: Int? = nil
    @State private var appeared: Bool = false
    @State private var showSaveMealSheet: Bool = false
    @State private var saveMealName: String = ""
    @State private var mealSaved: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    photoSection
                    contentSection
                }
            }
            .scrollIndicators(.hidden)

            VStack {
                navigationBar
                Spacer()
            }
        }
        .statusBarHidden(true)
        .sheet(isPresented: $showClarifySheet) {
            if let idx = selectedItemIndex, idx < estimatedItems.count {
                ClarifyItemSheet(item: $estimatedItems[idx])
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showSaveMealSheet) {
            saveMealSheetContent
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            Button {
                onRetake()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text("Retake")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Capsule())
            }

            Spacer()

            VStack(spacing: 1) {
                Text("Scan Results")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(.white)
                Text(mealTime.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial.opacity(0.6))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                    .overlay {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                ForEach(Array(overlays.enumerated()), id: \.element.id) { index, overlay in
                    let x = overlay.relativeX * geo.size.width
                    let y = overlay.relativeY * geo.size.height

                    overlayBubble(item: overlay.item, index: index)
                        .position(
                            x: min(max(x, 65), geo.size.width - 65),
                            y: min(max(y, 30), geo.size.height - 30)
                        )
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.6)
                        .animation(
                            .spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1 + 0.2),
                            value: appeared
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(height: UIScreen.main.bounds.height * 0.45)
    }

    private func overlayBubble(item: EstimatedFoodItem, index: Int) -> some View {
        Button {
            selectedItemIndex = index
            showClarifySheet = true
        } label: {
            VStack(spacing: 2) {
                Text(item.name)
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(item.amount) · \(item.calories) cal")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                PepTheme.teal.opacity(0.85)
                    .background(.ultraThinMaterial)
            )
            .clipShape(.rect(cornerRadius: 10))
            .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: 16) {
            summaryCard
                .padding(.top, 20)

            detectedItemsHeader

            ForEach(Array(estimatedItems.enumerated()), id: \.element.id) { index, item in
                Button {
                    selectedItemIndex = index
                    showClarifySheet = true
                } label: {
                    detectedItemRow(item: item, index: index)
                }
                .buttonStyle(.scale)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08 + 0.3),
                    value: appeared
                )
            }

            HStack(spacing: 10) {
                addButton
                saveMealButton
            }
            .padding(.top, 8)

            retakeButton

            Color.clear.frame(height: 40)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let totalCal = estimatedItems.reduce(0) { $0 + $1.calories }
        let totalP = estimatedItems.reduce(0) { $0 + $1.protein }
        let totalC = estimatedItems.reduce(0) { $0 + $1.carbs }
        let totalF = estimatedItems.reduce(0) { $0 + $1.fat }

        return VStack(spacing: 12) {
            Text("\(totalCal)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(PepTheme.teal)
            +
            Text(" cal")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 0) {
                macroColumn(label: "Protein", value: Int(totalP), unit: "g", color: PepTheme.teal)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 0.5, height: 32)

                macroColumn(label: "Carbs", value: Int(totalC), unit: "g", color: PepTheme.amber)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 0.5, height: 32)

                macroColumn(label: "Fat", value: Int(totalF), unit: "g", color: PepTheme.violet)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)
    }

    private func macroColumn(label: String, value: Int, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 1) {
                Text("\(value)")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(color.opacity(0.7))
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Detected Items

    private var detectedItemsHeader: some View {
        HStack {
            Text("Detected Items")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
            Text("Tap to adjust")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 4)
    }

    private func detectedItemRow(item: EstimatedFoodItem, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(PepTheme.teal.opacity(0.2))
                    .frame(width: 36, height: 36)
                Text("\(index + 1)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.teal)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(item.amount)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.3))
                    HStack(spacing: 4) {
                        Text("P:\(Int(item.protein))g")
                            .foregroundStyle(PepTheme.teal.opacity(0.8))
                        Text("C:\(Int(item.carbs))g")
                            .foregroundStyle(PepTheme.amber.opacity(0.8))
                        Text("F:\(Int(item.fat))g")
                            .foregroundStyle(PepTheme.violet.opacity(0.8))
                    }
                }
                .font(.caption2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(item.calories)")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text("cal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(12)
        .background(.white.opacity(0.06))
        .clipShape(.rect(cornerRadius: 14))
    }

    // MARK: - Buttons

    private var addButton: some View {
        Button {
            onAddAll()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                Text("Add to \(mealTime.rawValue)")
                    .font(.system(.body, weight: .bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(PepTheme.teal, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.scale)
        .sensoryFeedback(.success, trigger: estimatedItems.count)
    }

    private var saveMealButton: some View {
        Button {
            let names = estimatedItems.map { $0.name }
            saveMealName = names.count <= 2 ? names.joined(separator: " & ") : "\(names[0]) + \(names.count - 1) more"
            showSaveMealSheet = true
        } label: {
            Image(systemName: mealSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PepTheme.amber)
                .frame(width: 54, height: 52)
                .background(PepTheme.amber.opacity(0.15), in: .rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.amber.opacity(0.3), lineWidth: 0.5)
                )
        }
        .sensoryFeedback(.impact(weight: .light), trigger: showSaveMealSheet)
    }

    private var saveMealSheetContent: some View {
        let totalCal = estimatedItems.reduce(0) { $0 + $1.calories }
        let totalP = estimatedItems.reduce(0) { $0 + $1.protein }
        let totalC = estimatedItems.reduce(0) { $0 + $1.carbs }
        let totalF = estimatedItems.reduce(0) { $0 + $1.fat }

        return NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(PepTheme.amber.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(PepTheme.amber)
                    }

                    Text("Save This Meal")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)

                    Text("Quick-log it anytime from Saved Meals")
                        .font(.subheadline)
                        .foregroundStyle(PepTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Meal Name")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)

                    TextField("e.g. Chicken & Rice Bowl", text: $saveMealName)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 12))
                }

                HStack(spacing: 16) {
                    saveMealMacroPreview("Calories", value: "\(totalCal)", color: PepTheme.teal)
                    saveMealMacroPreview("Protein", value: "\(Int(totalP))g", color: PepTheme.teal)
                    saveMealMacroPreview("Carbs", value: "\(Int(totalC))g", color: PepTheme.amber)
                    saveMealMacroPreview("Fat", value: "\(Int(totalF))g", color: PepTheme.violet)
                }
                .padding(14)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 14))

                Button {
                    onSaveMeal?(
                        saveMealName.isEmpty ? "My Meal" : saveMealName,
                        totalCal,
                        totalP,
                        totalC,
                        totalF
                    )
                    mealSaved = true
                    showSaveMealSheet = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bookmark.fill")
                        Text("Save Meal")
                            .font(.system(.body, weight: .semibold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(PepTheme.amber, in: .rect(cornerRadius: 12))
                }
                .sensoryFeedback(.success, trigger: mealSaved)

                Spacer()
            }
            .padding(20)
            .appBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSaveMealSheet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                    }
                }
            }
        }
    }

    private func saveMealMacroPreview(_ label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var retakeButton: some View {
        Button {
            onRetake()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 13))
                Text("Retake Photo")
                    .font(.system(.subheadline, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white.opacity(0.06), in: .rect(cornerRadius: 12))
        }
    }
}
