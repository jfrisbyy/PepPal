import SwiftUI
import AVKit

struct AttachmentPreviewView: View {
    let attachment: DirectMessageAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = URL(string: attachment.url) {
                switch attachment.kind {
                case .image:
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit)
                        } else if phase.error != nil {
                            Image(systemName: "photo").font(.largeTitle).foregroundStyle(.white)
                        } else {
                            ProgressView().tint(.white)
                        }
                    }
                case .video:
                    VideoPlayer(player: AVPlayer(url: url))
                case .voice:
                    VStack(spacing: 16) {
                        Image(systemName: "waveform")
                            .font(.system(size: 60))
                            .foregroundStyle(.white)
                        VoiceMessagePlayer(attachment: attachment, isFromMe: false)
                    }
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding()
                    }
                }
                Spacer()
            }
        }
    }
}
