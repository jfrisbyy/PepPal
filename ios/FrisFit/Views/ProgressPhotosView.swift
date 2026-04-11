import SwiftUI
import PhotosUI
import Supabase

@Observable
final class ProgressPhotosViewModel {
    var photos: [ProgressPhoto] = []
    var isLoading: Bool = true
    var selectedCategory: String = "All"
    var errorMessage: String?
    var isUploading: Bool = false
    var showAddSheet: Bool = false
    var showSourcePicker: Bool = false
    var showCamera: Bool = false
    var selectedPhotoItem: PhotosPickerItem?
    var addCategory: String = "Front"
    var addNote: String = ""
    var capturedImage: UIImage?

    let categories = ["All", "Front", "Side", "Back"]
    let addCategories = ["Front", "Side", "Back"]

    var filteredPhotos: [ProgressPhoto] {
        if selectedCategory == "All" { return photos }
        return photos.filter { ($0.category ?? "").lowercased() == selectedCategory.lowercased() }
    }

    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let userId = try AuthService.shared.currentUserId()
            let rows: [SupabaseProgressPhoto] = try await SupabaseService.shared.client
                .from("progress_photos")
                .select()
                .eq("user_id", value: userId)
                .order("taken_at", ascending: false)
                .execute()
                .value
            photos = rows.compactMap { row in
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let basicFormatter = ISO8601DateFormatter()
                basicFormatter.formatOptions = [.withInternetDateTime]
                let date = formatter.date(from: row.taken_at ?? "") ?? basicFormatter.date(from: row.taken_at ?? "") ?? Date()
                return ProgressPhoto(
                    id: UUID(uuidString: row.id ?? "") ?? UUID(),
                    date: date,
                    label: row.note ?? "",
                    photoUrl: row.photo_url,
                    category: row.category,
                    supabaseId: row.id
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePhoto(_ photo: ProgressPhoto) async {
        guard let sid = photo.supabaseId else { return }
        do {
            try await SupabaseService.shared.client
                .from("progress_photos")
                .delete()
                .eq("id", value: sid)
                .execute()
            photos.removeAll { $0.id == photo.id }
        } catch {}
    }

    func uploadPhoto(_ image: UIImage) async {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            errorMessage = "Failed to process image"
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            let userId = try AuthService.shared.currentUserId()
            let fileName = "\(userId)/progress_\(UUID().uuidString).jpg"

            try await SupabaseService.shared.client.storage
                .from("progress-photos")
                .upload(
                    path: fileName,
                    file: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )

            let publicURL = try SupabaseService.shared.client.storage
                .from("progress-photos")
                .getPublicURL(path: fileName)

            let now = ISO8601DateFormatter()
            now.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let payload = InsertProgressPhoto(
                user_id: userId,
                photo_url: publicURL.absoluteString,
                category: addCategory,
                note: addNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : addNote.trimmingCharacters(in: .whitespacesAndNewlines),
                taken_at: now.string(from: Date())
            )

            try await SupabaseService.shared.client
                .from("progress_photos")
                .insert(payload)
                .execute()

            addNote = ""
            addCategory = "Front"
            capturedImage = nil
            selectedPhotoItem = nil
            showAddSheet = false
            await loadPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadImageFromPicker(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        capturedImage = image
        showAddSheet = true
    }
}

nonisolated struct InsertProgressPhoto: Codable, Sendable {
    let user_id: String
    let photo_url: String
    let category: String
    let note: String?
    let taken_at: String
}

nonisolated struct SupabaseProgressPhoto: Codable, Sendable {
    let id: String?
    let user_id: String?
    let photo_url: String?
    let category: String?
    let note: String?
    let taken_at: String?
}

struct ProgressPhotosView: View {
    @State private var viewModel = ProgressPhotosViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                categoryPicker

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.filteredPhotos.isEmpty {
                    emptyState
                } else {
                    photoGrid
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(PepTheme.background.ignoresSafeArea())
        .navigationTitle("Progress Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.showSourcePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PepTheme.teal)
                }
            }
        }
        .confirmationDialog("Add Progress Photo", isPresented: $viewModel.showSourcePicker, titleVisibility: .visible) {
            Button {
                viewModel.showCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }
            PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            ProgressPhotoCameraView { image in
                if let image {
                    viewModel.capturedImage = image
                    viewModel.showAddSheet = true
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddProgressPhotoSheet(viewModel: viewModel)
        }
        .onChange(of: viewModel.selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task { await viewModel.loadImageFromPicker(item) }
        }
        .task { await viewModel.loadPhotos() }
        .refreshable { await viewModel.loadPhotos() }
    }

    private var categoryPicker: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.categories, id: \.self) { category in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedCategory = category
                    }
                } label: {
                    Text(category)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(viewModel.selectedCategory == category ? .white : PepTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedCategory == category ? PepTheme.teal : PepTheme.elevated)
                        .clipShape(.capsule)
                }
                .sensoryFeedback(.selection, trigger: viewModel.selectedCategory)
            }
            Spacer()
        }
    }

    private var photoGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(viewModel.filteredPhotos) { photo in
                ProgressPhotoCard(photo: photo) {
                    Task { await viewModel.deletePhoto(photo) }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(PepTheme.teal.opacity(0.5))
            Text("No Progress Photos")
                .font(.system(.title3, weight: .bold))
                .foregroundStyle(PepTheme.textPrimary)
            Text("Track your transformation by adding progress photos. Tap + to get started.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                viewModel.showSourcePicker = true
            } label: {
                Label("Add Photo", systemImage: "plus")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(PepTheme.teal)
                    .clipShape(.capsule)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

private struct AddProgressPhotoSheet: View {
    @Bindable var viewModel: ProgressPhotosViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let image = viewModel.capturedImage {
                        Color(PepTheme.elevated)
                            .frame(height: 300)
                            .overlay {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 16, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pose".uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .tracking(0.8)

                        HStack(spacing: 8) {
                            ForEach(viewModel.addCategories, id: \.self) { cat in
                                Button {
                                    viewModel.addCategory = cat
                                } label: {
                                    Text(cat)
                                        .font(.system(.subheadline, weight: .semibold))
                                        .foregroundStyle(viewModel.addCategory == cat ? .white : PepTheme.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(viewModel.addCategory == cat ? PepTheme.teal : PepTheme.elevated)
                                        .clipShape(.capsule)
                                }
                            }
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)".uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PepTheme.textSecondary)
                            .tracking(0.8)

                        TextField("e.g. Week 4, feeling stronger", text: $viewModel.addNote)
                            .font(.body)
                            .foregroundStyle(PepTheme.textPrimary)
                            .padding(12)
                            .background(PepTheme.elevated)
                            .clipShape(.rect(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
            .background(PepTheme.background.ignoresSafeArea())
            .navigationTitle("New Progress Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.capturedImage = nil
                        viewModel.selectedPhotoItem = nil
                        viewModel.addNote = ""
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isUploading {
                        ProgressView()
                    } else {
                        Button("Save") {
                            guard let image = viewModel.capturedImage else { return }
                            Task { await viewModel.uploadPhoto(image) }
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(PepTheme.teal)
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct ProgressPhotoCard: View {
    let photo: ProgressPhoto
    let onDelete: () -> Void
    @State private var showDeleteConfirm: Bool = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let urlStr = photo.photoUrl, let url = URL(string: urlStr) {
                Color(PepTheme.elevated)
                    .frame(height: 200)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            } else if phase.error != nil {
                                placeholderIcon
                            } else {
                                ProgressView()
                            }
                        }
                    }
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
            } else {
                placeholderIcon
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(PepTheme.elevated)
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                if let cat = photo.category, !cat.isEmpty {
                    Text(cat.capitalized)
                        .font(.system(.caption2, weight: .bold))
                        .foregroundStyle(PepTheme.teal)
                }
                Text(dateFormatter.string(from: photo.date))
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)
        }
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .alert("Delete Photo?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var placeholderIcon: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.fill")
                .font(.system(size: 32))
                .foregroundStyle(PepTheme.textSecondary.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ProgressPhotoCameraView: UIViewControllerRepresentable {
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
