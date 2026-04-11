import SwiftUI
import Supabase

@Observable
final class ProgressPhotosViewModel {
    var photos: [ProgressPhoto] = []
    var isLoading: Bool = true
    var selectedCategory: String = "All"
    var errorMessage: String?

    let categories = ["All", "Front", "Side", "Back"]

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
            Text("Progress photos help you see changes that the scale can't capture. Photos will appear here once logged.")
                .font(.subheadline)
                .foregroundStyle(PepTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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
