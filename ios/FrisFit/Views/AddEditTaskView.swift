import SwiftUI

struct AddEditTaskView: View {
    @Bindable var viewModel: HomeViewModel
    var editingTask: DailyTask? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIcon: String = "star.fill"
    @State private var selectedCategory: TaskCategory = .fitness
    @State private var selectedCustomCategoryId: UUID? = nil
    @State private var scheduleType: TaskScheduleType = .daily
    @State private var selectedDays: Set<Weekday> = Set(Weekday.allCases)
    @State private var oneTimeDate: Date = Date()
    @State private var actionLink: TaskActionLink = .none
    @State private var actionTarget: String = ""
    @State private var expandedGroup: ActionLinkGroup? = nil
    @State private var showCreateCategory: Bool = false

    private let iconOptions: [String] = [
        "star.fill", "dumbbell.fill", "figure.walk", "figure.run",
        "drop.fill", "fish.fill", "leaf.fill", "flame.fill",
        "moon.fill", "brain.head.profile.fill", "snowflake", "book.fill",
        "heart.fill", "pills.fill", "cup.and.saucer.fill", "fork.knife",
        "alarm.fill", "figure.flexibility", "bolt.fill", "hand.raised.fill",
        "eye.fill", "music.note", "camera.fill", "pencil",
        "graduationcap.fill", "house.fill", "cart.fill", "phone.fill"
    ]

    private var isEditing: Bool { editingTask != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    nameSection
                    iconSection
                    categorySection
                    scheduleSection
                    actionLinkSection

                    if isEditing {
                        deleteButton
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveTask()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? PepTheme.textSecondary : PepTheme.teal)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let task = editingTask {
                    name = task.name
                    selectedIcon = task.icon
                    selectedCategory = task.category
                    selectedCustomCategoryId = task.customCategoryId
                    scheduleType = task.scheduleType
                    selectedDays = task.scheduledDays
                    oneTimeDate = task.oneTimeDate ?? Date()
                    actionLink = task.actionLink
                    actionTarget = task.actionTarget > 0 ? "\(task.actionTarget)" : ""
                    expandedGroup = actionLink.group
                }
            }
            .sheet(isPresented: $showCreateCategory) {
                CreateCategorySheet(viewModel: viewModel) { newCategory in
                    selectedCategory = .custom
                    selectedCustomCategoryId = newCategory.id
                }
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TASK NAME")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .tracking(0.5)

            TextField("e.g. Drink a gallon of water", text: $name)
                .font(.system(.body, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)
                .padding(14)
                .background(PepTheme.cardSurface)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ICON")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .tracking(0.5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(selectedIcon == icon ? PepTheme.invertedText : PepTheme.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(selectedIcon == icon ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }
            .padding(12)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .tracking(0.5)

            let builtIn = TaskCategory.builtInCases
            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(builtIn.count, 4))

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(builtIn) { category in
                    Button {
                        selectedCategory = category
                        selectedCustomCategoryId = nil
                    } label: {
                        let isSelected = selectedCategory == category && selectedCustomCategoryId == nil
                        VStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 14))
                                .foregroundStyle(isSelected ? PepTheme.invertedText : category.color)
                            Text(category.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isSelected ? category.color : PepTheme.elevated)
                        .clipShape(.rect(cornerRadius: 10))
                    }
                }
            }

            if !viewModel.customCategories.isEmpty {
                VStack(spacing: 6) {
                    ForEach(viewModel.customCategories) { custom in
                        Button {
                            selectedCategory = .custom
                            selectedCustomCategoryId = custom.id
                        } label: {
                            let isSelected = selectedCustomCategoryId == custom.id
                            HStack(spacing: 10) {
                                Image(systemName: custom.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(isSelected ? PepTheme.invertedText : custom.color)
                                    .frame(width: 24)
                                Text(custom.name)
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(PepTheme.invertedText)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSelected ? custom.color : PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
            }

            Button {
                showCreateCategory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                    Text("New Category")
                        .font(.system(.caption, weight: .semibold))
                }
                .foregroundStyle(PepTheme.teal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(PepTheme.teal.opacity(0.08))
                .clipShape(.rect(cornerRadius: 10))
            }
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .tracking(0.5)

            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(TaskScheduleType.allCases) { type in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scheduleType = type
                            }
                        } label: {
                            Text(type.rawValue)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(scheduleType == type ? PepTheme.invertedText : PepTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(scheduleType == type ? PepTheme.teal : PepTheme.elevated)
                                .clipShape(.capsule)
                        }
                    }
                }

                switch scheduleType {
                case .daily:
                    HStack(spacing: 4) {
                        Image(systemName: "repeat")
                            .font(.system(size: 12))
                            .foregroundStyle(PepTheme.teal)
                        Text("Repeats every day")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                    .padding(.vertical, 4)

                case .customDays:
                    HStack(spacing: 6) {
                        ForEach(Weekday.allCases) { day in
                            Button {
                                if selectedDays.contains(day) {
                                    if selectedDays.count > 1 {
                                        selectedDays.remove(day)
                                    }
                                } else {
                                    selectedDays.insert(day)
                                }
                            } label: {
                                Text(day.initial)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(selectedDays.contains(day) ? PepTheme.invertedText : PepTheme.textSecondary)
                                    .frame(width: 36, height: 36)
                                    .background(selectedDays.contains(day) ? PepTheme.teal : PepTheme.elevated)
                                    .clipShape(.circle)
                            }
                        }
                    }

                case .oneTime:
                    DatePicker("Date", selection: $oneTimeDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(PepTheme.teal)
                }
            }
            .padding(14)
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )
        }
    }

    private var actionLinkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTION LINK")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .tracking(0.5)

            Text("Link to app features for auto-completion")
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))

            VStack(spacing: 0) {
                ForEach(ActionLinkGroup.allCases) { group in
                    actionLinkGroupSection(group)
                }
            }
            .background(PepTheme.cardSurface)
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
            )

            if actionLink.hasCustomTarget {
                targetInputField
            }
        }
    }

    private func actionLinkGroupSection(_ group: ActionLinkGroup) -> some View {
        let isGroupExpanded = expandedGroup == group
        let groupContainsSelected = group.links.contains(actionLink)

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandedGroup = isGroupExpanded ? nil : group
                }
            } label: {
                HStack(spacing: 10) {
                    Text(group.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(groupContainsSelected ? PepTheme.teal : PepTheme.textSecondary.opacity(0.7))
                        .tracking(0.5)

                    if groupContainsSelected && !isGroupExpanded {
                        HStack(spacing: 4) {
                            Image(systemName: actionLink.icon)
                                .font(.system(size: 9))
                            Text(actionLink.rawValue)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(PepTheme.teal)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(PepTheme.teal.opacity(0.12))
                        .clipShape(.capsule)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.4))
                        .rotationEffect(.degrees(isGroupExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if isGroupExpanded {
                ForEach(group.links) { link in
                    actionLinkRow(link)
                }
            }

            if group != ActionLinkGroup.allCases.last {
                Divider()
                    .overlay(PepTheme.cardOverlay)
            }
        }
    }

    private func actionLinkRow(_ link: TaskActionLink) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                actionLink = link
                if !link.hasCustomTarget {
                    actionTarget = ""
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: link.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(actionLink == link ? PepTheme.teal : PepTheme.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(link.rawValue)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(actionLink == link ? PepTheme.textPrimary : PepTheme.textPrimary.opacity(0.7))
                    Text(link.description)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                if link.hasCustomTarget {
                    let displayTarget = Int(actionTarget) ?? viewModel.defaultTarget(for: link)
                    Text("\(displayTarget) \(link.targetUnit)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
                }

                if actionLink == link {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(PepTheme.teal)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(actionLink == link ? PepTheme.teal.opacity(0.04) : Color.clear)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var targetInputField: some View {
        HStack(spacing: 8) {
            Text(actionLink.targetLabel)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            Spacer()

            TextField(actionLink.targetPlaceholder, text: $actionTarget)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(PepTheme.textPrimary)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)

            Text(actionLink.targetUnit)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.6))
        }
        .padding(12)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            if let task = editingTask {
                viewModel.deleteTask(task)
            }
            dismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                Text("Delete Task")
                    .font(.system(.subheadline, weight: .semibold))
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.red.opacity(0.1))
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    private func saveTask() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let target = Int(actionTarget) ?? 0

        if let existing = editingTask {
            var updated = existing
            updated.name = trimmedName
            updated.icon = selectedIcon
            updated.category = selectedCategory
            updated.customCategoryId = selectedCategory == .custom ? selectedCustomCategoryId : nil
            updated.scheduleType = scheduleType
            updated.scheduledDays = selectedDays
            updated.oneTimeDate = scheduleType == .oneTime ? oneTimeDate : nil
            updated.actionLink = actionLink
            updated.actionTarget = target
            viewModel.updateTask(updated)
        } else {
            let newTask = DailyTask(
                name: trimmedName,
                icon: selectedIcon,
                category: selectedCategory,
                customCategoryId: selectedCategory == .custom ? selectedCustomCategoryId : nil,
                scheduleType: scheduleType,
                scheduledDays: selectedDays,
                oneTimeDate: scheduleType == .oneTime ? oneTimeDate : nil,
                actionLink: actionLink,
                actionTarget: target,
                isUserCreated: true
            )
            viewModel.addTask(newTask)
        }
    }
}
