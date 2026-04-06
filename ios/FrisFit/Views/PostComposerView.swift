import SwiftUI
import PhotosUI

struct PostComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = PostComposerViewModel()
    let onPost: (FeedPost) -> Void

    private let currentUser = SocialUser(
        id: UUID(),
        name: "You",
        username: "me",
        avatarInitial: "Y",
        avatarColor: Color(red: 0, green: 229/255, blue: 255/255),
        activeProgramName: nil,
        streak: 12,
        totalFP: 7200
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        composerHeader
                        textEditor
                        tagSelector
                        attachmentsPreview
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                Divider().overlay(PepTheme.separatorColor)
                attachmentBar
            }
            .background(PepTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(PepTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        postAction()
                    } label: {
                        Text("Post")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundStyle(viewModel.canPost && !viewModel.isOverLimit ? PepTheme.invertedText : PepTheme.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(viewModel.canPost && !viewModel.isOverLimit ? PepTheme.teal : PepTheme.elevated)
                            .clipShape(.capsule)
                    }
                    .disabled(!viewModel.canPost || viewModel.isOverLimit)
                }
            }
            .photosPicker(
                isPresented: $viewModel.showPhotoPicker,
                selection: $viewModel.selectedPhotos,
                maxSelectionCount: viewModel.remainingPhotos,
                matching: .images
            )
            .onChange(of: viewModel.selectedPhotos) { _, _ in
                Task { await viewModel.loadPhotos() }
            }
            .sheet(isPresented: $viewModel.showMarketPicker) {
                MarketLinkPickerSheet { program in
                    viewModel.selectedMarketProgram = program
                }
            }
            .sheet(isPresented: $viewModel.showWorkoutPicker) {
                WorkoutLogPickerSheet { log in
                    viewModel.selectedWorkoutLog = log
                }
            }
        }
    }

    private var composerHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(currentUser.avatarColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(currentUser.avatarInitial)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(currentUser.avatarColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(currentUser.name)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                Text("@\(currentUser.username)")
                    .font(.caption)
                    .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            if viewModel.characterCount > 0 {
                characterCounter
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var characterCounter: some View {
        ZStack {
            Circle()
                .stroke(PepTheme.elevated, lineWidth: 2)
                .frame(width: 28, height: 28)

            Circle()
                .trim(from: 0, to: min(viewModel.characterProgress, 1.0))
                .stroke(
                    viewModel.isOverLimit ? Color.red : (viewModel.characterProgress > 0.9 ? PepTheme.amber : PepTheme.teal),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 28, height: 28)
                .rotationEffect(.degrees(-90))

            if viewModel.isOverLimit {
                Text("\(500 - viewModel.characterCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
    }

    private var textEditor: some View {
        TextField("What's on your mind?", text: $viewModel.textContent, axis: .vertical)
            .font(.system(.body))
            .foregroundStyle(PepTheme.textPrimary)
            .lineLimit(1...20)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private var attachmentsPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.loadedImages.isEmpty {
                photoGrid
            }

            if viewModel.isRecordingVoice {
                voiceRecordingIndicator
            } else if viewModel.hasVoiceRecording {
                voicePreview
            }

            if let program = viewModel.selectedMarketProgram {
                marketLinkPreview(program)
            }

            if let log = viewModel.selectedWorkoutLog {
                workoutLogPreview(log)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var photoGrid: some View {
        let images = viewModel.loadedImages
        let columns = images.count == 1 ? 1 : 2

        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
            spacing: 4
        ) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                Color(.secondarySystemBackground)
                    .aspectRatio(images.count == 1 ? 16/9 : 1, contentMode: .fit)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.removePhoto(at: index)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                        }
                        .padding(6)
                    }
            }
        }
    }

    private var voiceRecordingIndicator: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.red)
                .frame(width: 10, height: 10)

            Text(formatDuration(viewModel.voiceRecordingDuration))
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(PepTheme.textPrimary)

            HStack(spacing: 2) {
                ForEach(0..<12, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(PepTheme.teal)
                        .frame(width: 3, height: CGFloat.random(in: 8...24))
                }
            }

            Spacer()

            Button {
                viewModel.stopVoiceRecording()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var voicePreview: some View {
        HStack(spacing: 12) {
            Button { } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(PepTheme.teal)
            }

            HStack(spacing: 1.5) {
                ForEach(0..<30, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(PepTheme.teal.opacity(0.5))
                        .frame(width: 2.5, height: CGFloat.random(in: 4...20))
                }
            }

            Text(formatDuration(viewModel.voiceRecordingDuration))
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(PepTheme.textSecondary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.removeVoiceRecording()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(14)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func marketLinkPreview(_ program: MarketProgram) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: program.gradientColors.map { Color(red: $0.r, green: $0.g, blue: $0.b) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: program.iconName)
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(program.title)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "bag.fill")
                        .font(.system(size: 9))
                    Text("Market · \(program.creatorName)")
                        .font(.caption)
                }
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.removeMarketLink()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(12)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 12))
    }

    private func workoutLogPreview(_ log: WorkoutLogAttachment) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(PepTheme.teal.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title3)
                        .foregroundStyle(PepTheme.teal)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(log.workoutName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(PepTheme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(log.duration)m", systemImage: "clock")
                    Label("\(log.exerciseCount) exercises", systemImage: "dumbbell")
                }
                .font(.caption)
                .foregroundStyle(PepTheme.textSecondary)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3)) {
                    viewModel.removeWorkoutLog()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(PepTheme.textSecondary)
            }
        }
        .padding(12)
        .background(PepTheme.elevated)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var tagSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.showTagPicker.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                        .font(.system(size: 13, weight: .medium))
                    Text(viewModel.selectedTags.isEmpty ? "Add Tags" : "\(viewModel.selectedTags.count) Tag\(viewModel.selectedTags.count == 1 ? "" : "s")")
                        .font(.system(.subheadline, weight: .medium))
                    Image(systemName: viewModel.showTagPicker ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(viewModel.selectedTags.isEmpty ? PepTheme.textSecondary : PepTheme.teal)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    if viewModel.selectedTags.isEmpty {
                        PepTheme.elevated
                    } else {
                        PepTheme.teal.opacity(0.12)
                    }
                }
                .clipShape(.capsule)
            }
            .sensoryFeedback(.selection, trigger: viewModel.showTagPicker)

            if viewModel.showTagPicker {
                tagGrid
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if !viewModel.selectedTags.isEmpty {
                selectedTagsRow
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var tagGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(FeedTag.allCases) { tag in
                let isSelected = viewModel.selectedTags.contains(tag)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        if isSelected {
                            viewModel.selectedTags.remove(tag)
                        } else {
                            viewModel.selectedTags.insert(tag)
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tag.icon)
                            .font(.system(size: 11))
                        Text(tag.rawValue)
                            .font(.system(.caption, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? PepTheme.invertedText : PepTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? AnyShapeStyle(PepTheme.teal) : AnyShapeStyle(PepTheme.elevated))
                    .clipShape(.capsule)
                }
                .sensoryFeedback(.impact(weight: .light), trigger: isSelected)
            }
        }
    }

    private var selectedTagsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(viewModel.selectedTags).sorted(by: { $0.rawValue < $1.rawValue })) { tag in
                    selectedTagChip(tag)
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    private func selectedTagChip(_ tag: FeedTag) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tag.icon)
                .font(.system(size: 10))
            Text(tag.rawValue)
                .font(.system(.caption2, weight: .semibold))
            Button {
                withAnimation(.spring(response: 0.25)) {
                    _ = viewModel.selectedTags.remove(tag)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(PepTheme.teal)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background { PepTheme.teal.opacity(0.12) }
        .clipShape(.capsule)
    }

    private var attachmentBar: some View {
        HStack(spacing: 4) {
            Button {
                viewModel.showPhotoPicker = true
            } label: {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.loadedImages.count >= 4 ? PepTheme.textSecondary.opacity(0.4) : PepTheme.teal)
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.loadedImages.count >= 4)

            Button {
                if viewModel.isRecordingVoice {
                    viewModel.stopVoiceRecording()
                } else if !viewModel.hasVoiceRecording {
                    viewModel.startVoiceRecording()
                }
            } label: {
                Image(systemName: viewModel.isRecordingVoice ? "mic.fill" : "mic")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.isRecordingVoice ? .red : (viewModel.hasVoiceRecording ? PepTheme.textSecondary.opacity(0.4) : PepTheme.teal))
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.hasVoiceRecording && !viewModel.isRecordingVoice)

            Button {
                viewModel.showMarketPicker = true
            } label: {
                Image(systemName: "bag")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.selectedMarketProgram != nil ? PepTheme.textSecondary.opacity(0.4) : PepTheme.teal)
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.selectedMarketProgram != nil)

            Button {
                viewModel.showWorkoutPicker = true
            } label: {
                Image(systemName: "figure.run")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.selectedWorkoutLog != nil ? PepTheme.textSecondary.opacity(0.4) : PepTheme.teal)
                    .frame(width: 44, height: 44)
            }
            .disabled(viewModel.selectedWorkoutLog != nil)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(PepTheme.cardSurface)
    }

    private func postAction() {
        guard viewModel.canPost, !viewModel.isOverLimit else { return }
        viewModel.isPosting = true
        let post = viewModel.createPost(user: currentUser)
        onPost(post)
        dismiss()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
