import SwiftUI

struct CreateCategorySheet: View {
    @Bindable var viewModel: HomeViewModel
    var onCreated: (CustomTaskCategory) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var selectedIcon: String = "folder.fill"
    @State private var selectedColorHex: String = "8B5CF6"

    private let iconOptions: [String] = [
        "folder.fill", "tag.fill", "flag.fill", "bookmark.fill",
        "trophy.fill", "target", "sparkles", "wand.and.stars",
        "briefcase.fill", "hammer.fill", "wrench.and.screwdriver.fill", "paintbrush.fill",
        "theatermasks.fill", "gamecontroller.fill", "music.note", "camera.fill",
        "airplane", "car.fill", "bicycle", "pawprint.fill",
        "graduationcap.fill", "cross.case.fill", "banknote.fill", "gift.fill"
    ]

    private let colorOptions: [(String, String)] = [
        ("8B5CF6", "Purple"),
        ("F97316", "Orange"),
        ("EF4444", "Red"),
        ("EC4899", "Pink"),
        ("06B6D4", "Cyan"),
        ("3B82F6", "Blue"),
        ("10B981", "Emerald"),
        ("84CC16", "Lime"),
        ("F59E0B", "Amber"),
        ("6366F1", "Indigo"),
        ("14B8A6", "Teal"),
        ("F43F5E", "Rose"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    previewSection
                    nameSection
                    colorSection
                    iconSection
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let category = CustomTaskCategory(
                            name: name.trimmingCharacters(in: .whitespaces),
                            icon: selectedIcon,
                            colorHex: selectedColorHex
                        )
                        viewModel.addCustomCategory(category)
                        onCreated(category)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(name.trimmingCharacters(in: .whitespaces).isEmpty ? PepTheme.textSecondary : PepTheme.teal)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var previewSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((Color(hex: selectedColorHex) ?? PepTheme.violet).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: selectedIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: selectedColorHex) ?? PepTheme.violet)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Category Name" : name)
                    .font(.system(.headline, weight: .semibold))
                    .foregroundStyle(name.isEmpty ? PepTheme.textSecondary.opacity(0.5) : PepTheme.textPrimary)
                Text("Custom Category")
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NAME")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .tracking(0.5)

            TextField("e.g. Mindfulness, Recovery, Work", text: $name)
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

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COLOR")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .tracking(0.5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(colorOptions, id: \.0) { hex, _ in
                    Button {
                        selectedColorHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex) ?? .purple)
                                .frame(width: 40, height: 40)

                            if selectedColorHex == hex {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
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

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ICON")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.7))
                .tracking(0.5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(iconOptions, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(selectedIcon == icon ? PepTheme.invertedText : PepTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(selectedIcon == icon ? (Color(hex: selectedColorHex) ?? PepTheme.violet) : PepTheme.elevated)
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
}
