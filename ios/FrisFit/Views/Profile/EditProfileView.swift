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
    @State private var isUploading: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    avatarSection
                    fieldsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(PepTheme.background.ignoresSafeArea())
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
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        avatarImageData = data
                    }
                }
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

    private func save() async {
        if let data = avatarImageData {
            isUploading = true
            _ = await viewModel.uploadAvatar(imageData: data)
            isUploading = false
        }

        let program = activeProgram.trimmingCharacters(in: .whitespaces).isEmpty ? nil : activeProgram.trimmingCharacters(in: .whitespaces)
        await viewModel.saveProfileEdits(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            username: username.trimmingCharacters(in: .whitespaces),
            bio: bio.trimmingCharacters(in: .whitespaces),
            activeProgram: program,
            avatarColor: nil
        )
        dismiss()
    }
}
