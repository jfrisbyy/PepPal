import SwiftUI

@Observable
final class DebugBanner {
    @MainActor static let shared = DebugBanner()

    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let kind: Kind
        let title: String
        let detail: String
    }

    enum Kind {
        case info, success, error
    }

    var entries: [Entry] = []
    var isExpanded: Bool = false

    func log(_ kind: Kind, _ title: String, _ detail: String = "") {
        let entry = Entry(date: Date(), kind: kind, title: title, detail: detail)
        entries.insert(entry, at: 0)
        if entries.count > 20 { entries = Array(entries.prefix(20)) }
        print("[DebugBanner] \(title) — \(detail)")
    }

    func clear() {
        entries.removeAll()
    }

    var latest: Entry? { entries.first }
}

struct DebugBannerOverlay: View {
    @State private var banner = DebugBanner.shared

    var body: some View {
        VStack {
            if let latest = banner.latest {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: iconName(for: latest.kind))
                            .foregroundStyle(color(for: latest.kind))
                        Text(latest.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                        Button {
                            banner.isExpanded.toggle()
                        } label: {
                            Image(systemName: banner.isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Button {
                            banner.clear()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    if !latest.detail.isEmpty {
                        Text(latest.detail)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(banner.isExpanded ? nil : 3)
                            .textSelection(.enabled)
                    }
                    if banner.isExpanded && banner.entries.count > 1 {
                        Divider().overlay(Color.white.opacity(0.2))
                        ForEach(banner.entries.dropFirst()) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: iconName(for: entry.kind))
                                        .foregroundStyle(color(for: entry.kind))
                                        .font(.system(size: 10))
                                    Text(entry.title)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                if !entry.detail.isEmpty {
                                    Text(entry.detail)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.85))
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color(for: latest.kind).opacity(0.6), lineWidth: 1)
                )
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: banner.entries.count)
    }

    private func iconName(for kind: DebugBanner.Kind) -> String {
        switch kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }

    private func color(for kind: DebugBanner.Kind) -> Color {
        switch kind {
        case .info: return .blue
        case .success: return .green
        case .error: return .red
        }
    }
}
