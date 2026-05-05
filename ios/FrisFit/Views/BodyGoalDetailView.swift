import SwiftUI
import PhotosUI

struct BodyGoalDetailView: View {
    @Bindable var viewModel: BodyGoalViewModel
    @State private var todaysPlanVM = TodaysPlanViewModel.shared
    @State private var expanded: ExpandedSection? = .trends
    @State private var photosVM = ProgressPhotosViewModel()
    @State private var photosLoaded: Bool = false
    @State private var photoFilter: String = "All"
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera: Bool = false
    @State private var showSourceDialog: Bool = false
    @State private var pendingImage: UIImage?
    @State private var pendingOrientation: String = "Front"
    @State private var pendingNote: String = ""
    @State private var selectedGoalDraft: FitnessGoalType = .weightLoss

    enum ExpandedSection: String {
        case logWeight, changeGoal, measurements, trends, photos
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                editorialMasthead
                goalHeader
                statTriptych
                EditorialInsightSection(
                    eyebrow: "BODY · INSIGHT",
                    title: "Today's Read",
                    content: todaysPlanVM.moduleContent(for: "body"),
                    accent: viewModel.currentGoal.color,
                    isRefreshing: todaysPlanVM.isBackgroundRefreshing || (todaysPlanVM.isLoading && todaysPlanVM.moduleContent(for: "body") == nil),
                    lastUpdated: todaysPlanVM.lastFetchDate
                )
                actionStack
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .appBackground()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh()
            await photosVM.loadPhotos()
        }
        .task {
            if !photosLoaded {
                photosLoaded = true
                await photosVM.loadPhotos()
            }
        }
        .onAppear {
            selectedGoalDraft = viewModel.currentGoal
        }
        .confirmationDialog("Add Progress Photo", isPresented: $showSourceDialog, titleVisibility: .visible) {
            Button {
                showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            BodyGoalCameraPicker { image in
                if let image { pendingImage = image }
            }
        }
        .onChange(of: pickerItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    pendingImage = image
                }
            }
        }
    }

    // MARK: - Editorial Masthead

    private var editorialMasthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("COMPOSITION  \u{2014}  VOL. 01")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(viewModel.currentGoal.color.opacity(0.85))

            Text(viewModel.currentGoal.rawValue)
                .font(.system(size: 34, weight: .black, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                Rectangle()
                    .fill(viewModel.currentGoal.color)
                    .frame(width: 28, height: 2)
                Text(viewModel.currentGoal.subtitle.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action Stack (inline expandable editorial sections)

    private var actionStack: some View {
        VStack(spacing: 12) {
            expandableCard(
                section: .logWeight,
                icon: "scalemass.fill",
                eyebrow: "ENTRY \u{00B7} 01",
                title: "Log Weight",
                accent: PepTheme.teal
            ) { logWeightInline }

            expandableCard(
                section: .measurements,
                icon: "ruler.fill",
                eyebrow: "ENTRY \u{00B7} 02",
                title: "Measurements",
                accent: PepTheme.amber
            ) { measurementsInline }

            expandableCard(
                section: .changeGoal,
                icon: "target",
                eyebrow: "ENTRY \u{00B7} 03",
                title: "Change Goal",
                accent: viewModel.currentGoal.color
            ) { changeGoalInline }

            expandableCard(
                section: .trends,
                icon: "chart.line.uptrend.xyaxis",
                eyebrow: "ENTRY \u{00B7} 04",
                title: "Trends & History",
                accent: PepTheme.violet
            ) { trendsInline }

            expandableCard(
                section: .photos,
                icon: "camera.aperture",
                eyebrow: "ENTRY \u{00B7} 05",
                title: "Progress Photos",
                accent: Color(red: 245/255, green: 158/255, blue: 11/255)
            ) { photosInline }
        }
    }

    private func expandableCard<Content: View>(
        section: ExpandedSection,
        icon: String,
        eyebrow: String,
        title: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expanded == section
        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    expanded = isExpanded ? nil : section
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(accent.opacity(0.14))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(eyebrow)
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(accent.opacity(0.75))
                        Text(title)
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(PepTheme.textPrimary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.scale)
            .sensoryFeedback(.selection, trigger: isExpanded)

            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(PepTheme.shimmerHighlight)
                        .frame(height: 0.6)
                        .padding(.horizontal, 16)

                    content()
                        .padding(16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isExpanded ? accent.opacity(0.25) : PepTheme.glassBorderTop,
                    lineWidth: isExpanded ? 0.8 : 0.5
                )
        )
        .shadow(color: .black.opacity(isExpanded ? 0.18 : 0.08), radius: isExpanded ? 14 : 6, x: 0, y: isExpanded ? 6 : 3)
    }

    // MARK: - Log Weight (inline)

    private var logWeightInline: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                editorialFieldLabel("WEIGHT", unit: "lbs")
                TextField("0.0", text: $viewModel.newWeighInValue)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 36, weight: .black, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.vertical, 4)
                Rectangle()
                    .fill(PepTheme.shimmerHighlight)
                    .frame(height: 0.8)
            }

            VStack(alignment: .leading, spacing: 6) {
                editorialFieldLabel("NOTE", unit: nil)
                TextField("Morning, post-workout...", text: $viewModel.newWeighInNote)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.vertical, 4)
                Rectangle()
                    .fill(PepTheme.shimmerHighlight)
                    .frame(height: 0.8)
            }

            if let last = viewModel.weightEntries.last {
                Text("Last entry: \(String(format: "%.1f lbs", last.weight)) on \(last.date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Button {
                viewModel.logWeighIn()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving { ProgressView().tint(PepTheme.invertedText) }
                    Text("Save Weigh-In")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(PepTheme.teal, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)
            .disabled(viewModel.newWeighInValue.isEmpty || viewModel.isSaving)
            .opacity(viewModel.newWeighInValue.isEmpty ? 0.5 : 1)
        }
    }

    // MARK: - Measurements (inline)

    private var measurementsInline: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ALL VALUES IN INCHES")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                inlineMeasurementField("Chest", value: $viewModel.newChest, icon: "figure.arms.open")
                inlineMeasurementField("Waist", value: $viewModel.newWaist, icon: "figure.stand")
                inlineMeasurementField("Hips", value: $viewModel.newHips, icon: "figure.walk")
                inlineMeasurementField("Neck", value: $viewModel.newNeck, icon: "person.bust")
                inlineMeasurementField("L Bicep", value: $viewModel.newBicepLeft, icon: "figure.strengthtraining.traditional")
                inlineMeasurementField("R Bicep", value: $viewModel.newBicepRight, icon: "figure.strengthtraining.traditional")
                inlineMeasurementField("L Thigh", value: $viewModel.newThighLeft, icon: "figure.run")
                inlineMeasurementField("R Thigh", value: $viewModel.newThighRight, icon: "figure.run")
            }

            Button {
                viewModel.logMeasurement()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving { ProgressView().tint(PepTheme.invertedText) }
                    Text("Save Measurements")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(PepTheme.amber, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)
            .disabled(viewModel.isSaving)

            if !viewModel.measurements.isEmpty {
                Divider().background(PepTheme.shimmerHighlight)

                Text("HISTORY  \u{00B7}  \(viewModel.measurements.count)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary)

                if viewModel.measurements.count >= 2 {
                    measurementComparisonCard
                }

                ForEach(viewModel.measurements.reversed()) { m in
                    measurementCard(m)
                        .contextMenu {
                            if m.supabaseId != nil {
                                Button(role: .destructive) {
                                    viewModel.deleteMeasurement(m)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                }
            }
        }
    }

    private func inlineMeasurementField(_ label: String, value: Binding<String>, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            TextField("\u{2014}", text: value)
                .keyboardType(.decimalPad)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(10)
                .background(PepTheme.elevated.opacity(0.6))
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    // MARK: - Change Goal (inline)

    private var changeGoalInline: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("GOAL TYPE")
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(spacing: 6) {
                ForEach(FitnessGoalType.allCases) { goal in
                    goalOptionRow(goal)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                editorialFieldLabel("TARGET WEIGHT", unit: "lbs")
                TextField("175.0", text: $viewModel.goalTargetWeightText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .black, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Rectangle()
                    .fill(PepTheme.shimmerHighlight)
                    .frame(height: 0.8)
            }

            VStack(alignment: .leading, spacing: 6) {
                editorialFieldLabel("WEEKLY RATE", unit: "lbs/wk")
                TextField("1.0", text: $viewModel.goalWeeklyRateText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                Rectangle()
                    .fill(PepTheme.shimmerHighlight)
                    .frame(height: 0.8)
            }

            VStack(alignment: .leading, spacing: 6) {
                editorialFieldLabel("TARGET DATE", unit: nil)
                DatePicker("", selection: $viewModel.targetDate, in: Date()..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .tint(selectedGoalDraft.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    editorialFieldLabel("HEIGHT", unit: "cm")
                    Spacer()
                    Text(heightInFeetInches)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text(String(format: "%.0f", viewModel.heightCm))
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                Slider(value: $viewModel.heightCm, in: 120...220, step: 1)
                    .tint(selectedGoalDraft.color)
            }

            Button {
                viewModel.currentGoal = selectedGoalDraft
                viewModel.saveGoal()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSaving { ProgressView().tint(PepTheme.invertedText) }
                    Text("Save Goal")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundStyle(PepTheme.invertedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(selectedGoalDraft.color, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.scale)
            .disabled(viewModel.isSaving)
        }
    }

    private func goalOptionRow(_ goal: FitnessGoalType) -> some View {
        let isSelected = selectedGoalDraft == goal
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedGoalDraft = goal
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(goal.color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: goal.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(goal.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(goal.rawValue)
                        .font(.system(.subheadline, design: .serif, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(goal.subtitle)
                        .font(.caption2)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(goal.color)
                }
            }
            .padding(10)
            .background(isSelected ? goal.color.opacity(0.08) : PepTheme.elevated.opacity(0.5))
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? goal.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var heightInFeetInches: String {
        let totalInches = viewModel.heightCm / 2.54
        let feet = Int(totalInches / 12)
        let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(inches)\""
    }

    // MARK: - Trends (inline)

    private var trendsInline: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("WEIGHT TREND")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                if !viewModel.weightEntries.isEmpty {
                    Text(String(format: "%.1f lbs total", abs(viewModel.totalChange)))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(
                            viewModel.currentGoal.isLosing
                            ? (viewModel.totalChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                            : (viewModel.totalChange >= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                        )
                }
            }

            if viewModel.weightChartData.count > 1 {
                WeightChartView(data: viewModel.weightChartData, goalColor: viewModel.currentGoal.color)
                    .frame(height: 160)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title)
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    Text("Log more weigh-ins to see your trend")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            }

            Divider().background(PepTheme.shimmerHighlight)

            HStack {
                Text("HISTORY")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary)
                Spacer()
                Text("\(viewModel.weightEntries.count) ENTRIES")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            if viewModel.weightEntries.isEmpty {
                EmptyStateView(
                    icon: "scalemass",
                    title: "No Weight Entries",
                    message: "Log your first weigh-in to start tracking your progress."
                )
            } else {
                ForEach(viewModel.weightEntries.reversed()) { entry in
                    weightEntryRow(entry)
                }
            }
        }
    }

    // MARK: - Photos (inline)

    private var photosInline: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let pendingImage {
                pendingPhotoEditor(image: pendingImage)
            } else {
                photoFiltersBar
                photoGrid
                addPhotoButton
            }
        }
    }

    private var photoFiltersBar: some View {
        let cats = ["All", "Front", "Side", "Back"]
        return HStack(spacing: 6) {
            ForEach(cats, id: \.self) { c in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        photoFilter = c
                    }
                } label: {
                    Text(c.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(photoFilter == c ? PepTheme.invertedText : PepTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(photoFilter == c ? Color(red: 245/255, green: 158/255, blue: 11/255) : PepTheme.elevated.opacity(0.6))
                        .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: photoFilter)
            }
            Spacer()
            if photosVM.photos.count >= 2 {
                NavigationLink {
                    ProgressPhotoComparisonView(photos: photosVM.photos)
                } label: {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PepTheme.violet)
                        .padding(8)
                        .background(PepTheme.elevated.opacity(0.6))
                        .clipShape(.circle)
                }
            }
        }
    }

    private var photoGrid: some View {
        let filtered: [ProgressPhoto] = photoFilter == "All"
            ? photosVM.photos
            : photosVM.photos.filter { ($0.orientation ?? $0.category ?? "").lowercased() == photoFilter.lowercased() }

        return VStack(spacing: 0) {
            if photosVM.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else if filtered.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.6))
                    Text("No Progress Photos Yet")
                        .font(.system(.subheadline, design: .serif, weight: .bold))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text("Document your transformation week by week.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(filtered) { photo in
                        photoTile(photo)
                    }
                }
            }
        }
    }

    private func photoTile(_ photo: ProgressPhoto) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Color(PepTheme.elevated)
                .frame(height: 160)
                .overlay {
                    if let urlStr = photo.photoUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            } else if phase.error != nil {
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                            } else {
                                ProgressView()
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                    }
                }
                .clipShape(.rect(cornerRadius: 12))

            HStack(spacing: 6) {
                if let o = photo.orientationEnum {
                    Text(o.displayName.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                }
                Spacer()
                Text(photo.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.horizontal, 4)
        }
        .contextMenu {
            Button(role: .destructive) {
                Task { await photosVM.deletePhoto(photo) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var addPhotoButton: some View {
        Button {
            showSourceDialog = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add Progress Photo")
                    .font(.system(.subheadline, weight: .semibold))
            }
            .foregroundStyle(PepTheme.invertedText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color(red: 245/255, green: 158/255, blue: 11/255), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.scale)
    }

    private func pendingPhotoEditor(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Color(PepTheme.elevated)
                .frame(height: 260)
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 8) {
                editorialFieldLabel("POSE", unit: nil)
                HStack(spacing: 8) {
                    ForEach(["Front", "Side", "Back"], id: \.self) { c in
                        Button {
                            pendingOrientation = c
                        } label: {
                            Text(c.uppercased())
                                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                .tracking(1.2)
                                .foregroundStyle(pendingOrientation == c ? PepTheme.invertedText : PepTheme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(pendingOrientation == c ? Color(red: 245/255, green: 158/255, blue: 11/255) : PepTheme.elevated.opacity(0.6))
                                .clipShape(.capsule)
                        }
                    }
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                editorialFieldLabel("NOTE", unit: nil)
                TextField("Week 4, feeling stronger", text: $pendingNote)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(PepTheme.textPrimary)
                    .padding(.vertical, 4)
                Rectangle()
                    .fill(PepTheme.shimmerHighlight)
                    .frame(height: 0.8)
            }

            HStack(spacing: 10) {
                Button {
                    pendingImage = nil
                    pendingNote = ""
                    pickerItem = nil
                } label: {
                    Text("Cancel")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(PepTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(PepTheme.elevated.opacity(0.7), in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scale)

                Button {
                    photosVM.addCategory = pendingOrientation
                    photosVM.addNote = pendingNote
                    let img = image
                    Task {
                        await photosVM.uploadPhoto(img)
                        pendingImage = nil
                        pendingNote = ""
                        pickerItem = nil
                    }
                } label: {
                    HStack(spacing: 8) {
                        if photosVM.isUploading { ProgressView().tint(PepTheme.invertedText) }
                        Text("Save Photo")
                            .font(.system(.subheadline, weight: .semibold))
                    }
                    .foregroundStyle(PepTheme.invertedText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(red: 245/255, green: 158/255, blue: 11/255), in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.scale)
                .disabled(photosVM.isUploading)
            }
        }
    }

    // MARK: - Helpers

    private func editorialFieldLabel(_ label: String, unit: String?) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary)
            if let unit {
                Text(unit)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
            }
            Spacer()
        }
    }

    // MARK: - Stat Triptych

    private var statTriptych: some View {
        HStack(spacing: 0) {
            triptychCell(
                eyebrow: "START",
                value: viewModel.startingWeight > 0 ? String(format: "%.1f", viewModel.startingWeight) : "\u{2014}",
                unit: "lbs",
                color: PepTheme.textSecondary
            )
            divider
            triptychCell(
                eyebrow: "NOW",
                value: viewModel.currentWeight > 0 ? String(format: "%.1f", viewModel.currentWeight) : "\u{2014}",
                unit: "lbs",
                color: PepTheme.textPrimary
            )
            divider
            triptychCell(
                eyebrow: "GOAL",
                value: String(format: "%.1f", viewModel.targetWeight),
                unit: "lbs",
                color: viewModel.currentGoal.color
            )
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(PepTheme.shimmerHighlight)
            .frame(width: 1, height: 36)
    }

    private func triptychCell(eyebrow: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(PepTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Goal Header

    private var goalHeader: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(PepTheme.elevated, lineWidth: 8)
                        .frame(width: 110, height: 110)
                    Circle()
                        .trim(from: 0, to: viewModel.progressToGoal)
                        .stroke(
                            LinearGradient(
                                colors: [viewModel.currentGoal.color.opacity(0.6), viewModel.currentGoal.color],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: viewModel.progressToGoal)
                    VStack(spacing: 2) {
                        Text("\(Int(viewModel.progressToGoal * 100))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(viewModel.currentGoal.color)
                        Text("PERCENT")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("PROGRESS")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(PepTheme.textSecondary)

                    Text(String(format: "%.1f lbs to go", viewModel.remainingToGoal))
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(PepTheme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 4) {
                        Image(systemName: viewModel.weeklyChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%.1f lbs this week", abs(viewModel.weeklyChange)))
                            .font(.system(.caption, weight: .semibold))
                    }
                    .foregroundStyle(
                        viewModel.currentGoal.isLosing
                        ? (viewModel.weeklyChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                        : (viewModel.weeklyChange >= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(PepTheme.elevated.opacity(0.6))
                    .clipShape(.capsule)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                bmiMiniCard
                weeklyChangeMiniCard
            }

            if let estDate = viewModel.estimatedCompletionDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.teal)
                    Text("Est. goal date: \(estDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(PepTheme.teal.opacity(0.08))
                .clipShape(.capsule)
            }

            if let avgWeekly = viewModel.averageWeeklyChange {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.flattrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundStyle(PepTheme.textSecondary)
                    Text("Avg. weekly change: \(String(format: "%+.1f", avgWeekly)) lbs")
                        .font(.system(.caption, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface.overlay(PepTheme.cardOverlay))
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [PepTheme.glassBorderTop, PepTheme.glassBorderBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    private var bmiMiniCard: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(PepTheme.elevated, lineWidth: 3)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: min(viewModel.bmi.value / 40.0, 1.0))
                    .stroke(viewModel.bmi.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%.1f", viewModel.bmi.value))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.bmi.color)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("BMI")
                    .font(.system(.caption2, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(viewModel.bmi.category)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(viewModel.bmi.color)
            }
            Spacer()
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
    }

    private var weeklyChangeMiniCard: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(PepTheme.elevated)
                    .frame(width: 36, height: 36)
                Image(systemName: viewModel.weeklyChange <= 0 ? "arrow.down.right" : "arrow.up.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(viewModel.weeklyChange <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(String(format: "%.1f lbs", abs(viewModel.weeklyChange)))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("This week")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
    }

    // MARK: - Reusable rows

    private func weightEntryRow(_ entry: WeightEntry) -> some View {
        let previousIndex = viewModel.weightEntries.firstIndex(where: { $0.id == entry.id }).map { $0 - 1 }
        let previousWeight = previousIndex.flatMap { $0 >= 0 ? viewModel.weightEntries[$0].weight : nil }
        let change = previousWeight.map { entry.weight - $0 }

        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(entry.date.formatted(.dateTime.day()))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text(entry.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: "%.1f lbs", entry.weight))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }

            Spacer()

            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change <= 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "%.1f", abs(change)))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(change <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (change <= 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : Color(red: 255/255, green: 107/255, blue: 107/255)).opacity(0.1)
                )
                .clipShape(.capsule)
            }
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
        .contextMenu {
            if entry.supabaseId != nil {
                Button(role: .destructive) {
                    viewModel.deleteWeightEntry(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func measurementCard(_ measurement: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(measurement.date.formatted(.dateTime.month(.wide).day().year()))
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(PepTheme.amber)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if let v = measurement.chest { measurementStat(label: "Chest", value: v) }
                if let v = measurement.waist { measurementStat(label: "Waist", value: v) }
                if let v = measurement.hips { measurementStat(label: "Hips", value: v) }
                if let v = measurement.neck { measurementStat(label: "Neck", value: v) }
                if let v = measurement.bicepLeft { measurementStat(label: "L Bicep", value: v) }
                if let v = measurement.bicepRight { measurementStat(label: "R Bicep", value: v) }
                if let v = measurement.thighLeft { measurementStat(label: "L Thigh", value: v) }
                if let v = measurement.thighRight { measurementStat(label: "R Thigh", value: v) }
            }
        }
        .padding(12)
        .background(PepTheme.elevated.opacity(0.5))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func measurementStat(label: String, value: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                Text(String(format: "%.1f\"", value))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            Spacer()
        }
    }

    private var measurementComparisonCard: some View {
        let latest = viewModel.measurements.last!
        let previous = viewModel.measurements[viewModel.measurements.count - 2]

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(PepTheme.violet)
                Text("Changes Since Last")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                if let lc = latest.chest, let pc = previous.chest { measurementChange(label: "Chest", change: lc - pc) }
                if let lw = latest.waist, let pw = previous.waist { measurementChange(label: "Waist", change: lw - pw) }
                if let lh = latest.hips, let ph = previous.hips { measurementChange(label: "Hips", change: lh - ph) }
                if let ln = latest.neck, let pn = previous.neck { measurementChange(label: "Neck", change: ln - pn) }
                if let lb = latest.bicepLeft, let pb = previous.bicepLeft { measurementChange(label: "L Bicep", change: lb - pb) }
                if let rb = latest.bicepRight, let prb = previous.bicepRight { measurementChange(label: "R Bicep", change: rb - prb) }
                if let lt = latest.thighLeft, let pt = previous.thighLeft { measurementChange(label: "L Thigh", change: lt - pt) }
                if let rt = latest.thighRight, let prt = previous.thighRight { measurementChange(label: "R Thigh", change: rt - prt) }
            }
        }
        .padding(12)
        .background(PepTheme.violet.opacity(0.06))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func measurementChange(label: String, change: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
                HStack(spacing: 3) {
                    Image(systemName: change < 0 ? "arrow.down" : (change > 0 ? "arrow.up" : "minus"))
                        .font(.system(size: 8, weight: .bold))
                    Text(String(format: "%+.1f\"", change))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                }
                .foregroundStyle(change == 0 ? PepTheme.textSecondary : (change < 0 ? Color(red: 76/255, green: 217/255, blue: 100/255) : PepTheme.amber))
            }
            Spacer()
        }
    }
}

// MARK: - Camera Picker

struct BodyGoalCameraPicker: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        #if targetEnvironment(simulator)
        picker.sourceType = .photoLibrary
        #else
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = .rear
        } else {
            picker.sourceType = .photoLibrary
        }
        #endif
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onComplete: (UIImage?) -> Void

        init(onComplete: @escaping (UIImage?) -> Void) {
            self.onComplete = onComplete
        }

        nonisolated func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            Task { @MainActor in
                picker.dismiss(animated: true)
                onComplete(image)
            }
        }

        nonisolated func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            Task { @MainActor in
                picker.dismiss(animated: true)
                onComplete(nil)
            }
        }
    }
}

// MARK: - Weight Chart

struct WeightChartView: View {
    let data: [(date: Date, weight: Double)]
    let goalColor: Color

    var body: some View {
        GeometryReader { geo in
            let minW = data.map(\.weight).min() ?? 0
            let maxW = data.map(\.weight).max() ?? 1
            let range = max(maxW - minW, 1)
            let padding: Double = range * 0.1

            let adjustedMin = minW - padding
            let adjustedRange = range + padding * 2

            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    let y = geo.size.height * (1 - CGFloat(i) / 3.0)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(PepTheme.shimmerHighlight, lineWidth: 0.5)

                    let labelValue = adjustedMin + adjustedRange * (Double(i) / 3.0)
                    Text(String(format: "%.0f", labelValue))
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.5))
                        .position(x: 16, y: y - 8)
                }

                Path { path in
                    for (index, point) in data.enumerated() {
                        let x = data.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(data.count - 1) : geo.size.width / 2
                        let y = geo.size.height * (1 - CGFloat((point.weight - adjustedMin) / adjustedRange))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [goalColor.opacity(0.5), goalColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

                Path { path in
                    for (index, point) in data.enumerated() {
                        let x = data.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(data.count - 1) : geo.size.width / 2
                        let y = geo.size.height * (1 - CGFloat((point.weight - adjustedMin) / adjustedRange))
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    if let last = data.last {
                        let lastX = data.count > 1 ? geo.size.width : geo.size.width / 2
                        let lastY = geo.size.height * (1 - CGFloat((last.weight - adjustedMin) / adjustedRange))
                        path.addLine(to: CGPoint(x: lastX, y: geo.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        path.closeSubpath()
                        _ = lastY
                    }
                }
                .fill(
                    LinearGradient(
                        colors: [goalColor.opacity(0.15), goalColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                ForEach(data.indices, id: \.self) { index in
                    let point = data[index]
                    let x = data.count > 1 ? geo.size.width * CGFloat(index) / CGFloat(data.count - 1) : geo.size.width / 2
                    let y = geo.size.height * (1 - CGFloat((point.weight - adjustedMin) / adjustedRange))
                    Circle()
                        .fill(goalColor)
                        .frame(width: index == data.count - 1 ? 8 : 5, height: index == data.count - 1 ? 8 : 5)
                        .shadow(color: goalColor.opacity(0.5), radius: index == data.count - 1 ? 4 : 0)
                        .position(x: x, y: y)
                }
            }
        }
    }
}
