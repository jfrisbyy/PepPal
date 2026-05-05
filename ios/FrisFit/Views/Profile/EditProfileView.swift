import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var username: String = ""
    @State private var bio: String = ""
    @State private var activeProgram: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImageData: Data?
    @State private var pendingCropImage: UIImage?
    @State private var isUploading: Bool = false

    @State private var selectedBannerPhoto: PhotosPickerItem?
    @State private var pendingBannerCropImage: UIImage?
    @State private var bannerStore = ProfileBannerStore.shared
    @State private var pendingBannerData: Data?
    @State private var bannerRemoved: Bool = false

    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var hasDOB: Bool = false
    @State private var biologicalSex: BiologicalSex? = nil
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 10
    @State private var hasHeight: Bool = false
    @State private var useMetricHeight: Bool = false
    @State private var heightCmText: String = ""
    @State private var isPrivate: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    bannerSection
                    avatarSection
                    fieldsSection
                    privacySection
                    biometricSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .appBackground()
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if viewModel.isSaving || isUploading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isSaving || isUploading || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .tint(PepTheme.teal)
                }
            }
            .onAppear {
                displayName = viewModel.profile.displayName
                username = viewModel.profile.username
                bio = viewModel.profile.bio
                activeProgram = viewModel.profile.activeProgram ?? ""

                if let dob = viewModel.profile.dateOfBirth {
                    dateOfBirth = dob
                    hasDOB = true
                }
                biologicalSex = viewModel.profile.biologicalSex
                isPrivate = viewModel.profile.isPrivate
                if let h = viewModel.profile.heightCm {
                    hasHeight = true
                    let totalInches = h / 2.54
                    heightFeet = Int(totalInches) / 12
                    heightInches = Int(totalInches) % 12
                    heightCmText = String(format: "%.0f", h)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pendingCropImage = image
                    }
                }
            }
            .onChange(of: selectedBannerPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        pendingBannerCropImage = image
                    }
                }
            }
            .fullScreenCover(item: Binding(
                get: { pendingBannerCropImage.map { CropImageWrapper(image: $0) } },
                set: { newValue in pendingBannerCropImage = newValue?.image }
            )) { wrapper in
                BannerCropSheet(
                    sourceImage: wrapper.image,
                    onSave: { data in
                        bannerStore.setBanner(data)
                        pendingBannerData = data
                        bannerRemoved = false
                        pendingBannerCropImage = nil
                        selectedBannerPhoto = nil
                    },
                    onCancel: {
                        pendingBannerCropImage = nil
                        selectedBannerPhoto = nil
                    }
                )
            }
            .fullScreenCover(item: Binding(
                get: { pendingCropImage.map { CropImageWrapper(image: $0) } },
                set: { newValue in pendingCropImage = newValue?.image }
            )) { wrapper in
                AvatarCropSheet(
                    sourceImage: wrapper.image,
                    onSave: { data in
                        avatarImageData = data
                        pendingCropImage = nil
                        selectedPhoto = nil
                    },
                    onCancel: {
                        pendingCropImage = nil
                        selectedPhoto = nil
                    }
                )
            }
        }
    }

    private struct CropImageWrapper: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    private var bannerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PROFILE HEADER")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(0.8)
                Spacer()
                if bannerStore.bannerImage != nil || pendingBannerData != nil {
                    Button(role: .destructive) {
                        bannerStore.setBanner(nil)
                        pendingBannerData = nil
                        bannerRemoved = true
                    } label: {
                        Text("Remove")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
            }

            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image = bannerStore.bannerImage {
                        Color(.secondarySystemBackground)
                            .frame(height: 130)
                            .overlay {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            }
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [
                                PepTheme.teal.opacity(0.35),
                                PepTheme.violet.opacity(0.25),
                                PepTheme.background
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 130)
                        .overlay {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 24))
                                Text("Add a header image")
                                    .font(.system(.caption, weight: .semibold))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )

                PhotosPicker(selection: $selectedBannerPhoto, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(bannerStore.bannerImage == nil ? "Add" : "Change")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(PepTheme.teal)
                    .clipShape(.capsule)
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                }
                .padding(10)
            }
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let data = avatarImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else if let url = viewModel.profile.avatarUrl, let imageUrl = URL(string: url) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [viewModel.profile.avatarColor.opacity(0.8), PepTheme.violet.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .overlay {
                            AsyncImage(url: imageUrl) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [viewModel.profile.avatarColor.opacity(0.8), PepTheme.violet.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .overlay {
                            Text(viewModel.profile.initials)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(PepTheme.teal)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(PepTheme.background, lineWidth: 2))
                }
            }
        }
    }

    private var fieldsSection: some View {
        VStack(spacing: 16) {
            editField(label: "Display Name", text: $displayName, placeholder: "Your name")
            editField(label: "Username", text: $username, placeholder: "username")
            editField(label: "Active Program", text: $activeProgram, placeholder: "e.g. Push Pull Legs")

            VStack(alignment: .leading, spacing: 8) {
                Text("Bio".uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(0.8)

                TextEditor(text: $bio)
                    .font(.body)
                    .foregroundStyle(PepTheme.textPrimary)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )
            }
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                Text("Privacy")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }

            Toggle(isOn: $isPrivate) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Private Account")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(PepTheme.textPrimary)
                    Text(isPrivate
                         ? "Only approved followers can see your posts and profile."
                         : "Anyone can see your posts and profile.")
                        .font(.caption)
                        .foregroundStyle(PepTheme.textSecondary)
                }
            }
            .tint(PepTheme.teal)
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private var biometricSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(PepTheme.teal)
                Text("Biometrics")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
            }
            .padding(.bottom, 4)

            Text("Used for BMR calculation and calorie tracking accuracy.")
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("DATE OF BIRTH")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(0.8)

                DatePicker(
                    "Date of Birth",
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(PepTheme.teal)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
                .onChange(of: dateOfBirth) { _, _ in
                    hasDOB = true
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("BIOLOGICAL SEX")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PepTheme.textSecondary)
                    .tracking(0.8)

                HStack(spacing: 12) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Button {
                            biologicalSex = sex
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: sex == .male ? "figure.stand" : "figure.stand.dress")
                                    .font(.system(size: 14))
                                Text(sex.displayName)
                                    .font(.system(.subheadline, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(biologicalSex == sex ? PepTheme.teal.opacity(0.15) : PepTheme.elevated)
                            .foregroundStyle(biologicalSex == sex ? PepTheme.teal : PepTheme.textSecondary)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(biologicalSex == sex ? PepTheme.teal.opacity(0.5) : PepTheme.glassBorderTop, lineWidth: biologicalSex == sex ? 1 : 0.5)
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("HEIGHT")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PepTheme.textSecondary)
                        .tracking(0.8)
                    Spacer()
                    Button {
                        useMetricHeight.toggle()
                        if useMetricHeight {
                            let totalInches = Double(heightFeet * 12 + heightInches)
                            heightCmText = String(format: "%.0f", totalInches * 2.54)
                        } else {
                            if let cm = Double(heightCmText) {
                                let totalInches = cm / 2.54
                                heightFeet = Int(totalInches) / 12
                                heightInches = Int(totalInches) % 12
                            }
                        }
                    } label: {
                        Text(useMetricHeight ? "cm" : "ft/in")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.teal)
                    }
                }

                if useMetricHeight {
                    HStack(spacing: 8) {
                        TextField("Height", text: $heightCmText)
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                            )
                            .onChange(of: heightCmText) { _, _ in hasHeight = true }

                        Text("cm")
                            .font(.subheadline)
                            .foregroundStyle(PepTheme.textSecondary)
                    }
                } else {
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Picker("Feet", selection: $heightFeet) {
                                ForEach(3...7, id: \.self) { ft in
                                    Text("\(ft)").tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 100)
                            .clipShape(.rect(cornerRadius: 12))
                            Text("ft")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textSecondary)
                        }

                        HStack(spacing: 8) {
                            Picker("Inches", selection: $heightInches) {
                                ForEach(0...11, id: \.self) { inch in
                                    Text("\(inch)").tag(inch)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60, height: 100)
                            .clipShape(.rect(cornerRadius: 12))
                            Text("in")
                                .font(.subheadline)
                                .foregroundStyle(PepTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                    )
                    .onChange(of: heightFeet) { _, _ in hasHeight = true }
                    .onChange(of: heightInches) { _, _ in hasHeight = true }
                }
            }
        }
        .padding(16)
        .background(PepTheme.cardSurface)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
        )
    }

    private func editField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PepTheme.textSecondary)
                .tracking(0.8)

            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(PepTheme.textPrimary)
                .padding(12)
                .background(PepTheme.elevated)
                .clipShape(.rect(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(PepTheme.glassBorderTop, lineWidth: 0.5)
                )
        }
    }

    private var computedHeightCm: Double? {
        guard hasHeight else { return nil }
        if useMetricHeight {
            return Double(heightCmText)
        } else {
            let totalInches = Double(heightFeet * 12 + heightInches)
            return totalInches * 2.54
        }
    }

    private func save() async {
        if let data = avatarImageData {
            isUploading = true
            _ = await viewModel.uploadAvatar(imageData: data)
            isUploading = false
        }

        if let bannerData = pendingBannerData {
            isUploading = true
            _ = await viewModel.uploadBanner(imageData: bannerData)
            isUploading = false
            pendingBannerData = nil
        } else if bannerRemoved {
            isUploading = true
            await viewModel.removeBanner()
            isUploading = false
            bannerRemoved = false
        }

        let program = activeProgram.trimmingCharacters(in: .whitespaces).isEmpty ? nil : activeProgram.trimmingCharacters(in: .whitespaces)
        await viewModel.saveProfileEdits(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            bio: bio.trimmingCharacters(in: .whitespaces),
            activeProgram: program,
            avatarColor: nil,
            dateOfBirth: hasDOB ? dateOfBirth : viewModel.profile.dateOfBirth,
            biologicalSex: biologicalSex ?? viewModel.profile.biologicalSex,
            heightCm: computedHeightCm ?? viewModel.profile.heightCm,
            isPrivate: isPrivate
        )
        dismiss()
    }
}
