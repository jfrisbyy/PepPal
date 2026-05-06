import SwiftUI

nonisolated enum SocialPlatform: String, CaseIterable, Sendable {
    case instagram
    case twitter
    case tiktok
    case facebook

    var displayName: String {
        switch self {
        case .instagram: return "Instagram"
        case .twitter: return "X"
        case .tiktok: return "TikTok"
        case .facebook: return "Facebook"
        }
    }

    var prefix: String {
        switch self {
        case .instagram, .twitter, .tiktok: return "@"
        case .facebook: return "/"
        }
    }

    var placeholder: String {
        switch self {
        case .instagram: return "yourhandle"
        case .twitter: return "yourhandle"
        case .tiktok: return "yourhandle"
        case .facebook: return "yourpage"
        }
    }

    var iconName: String {
        // SF Symbols don't ship branded icons, so use universal glyphs in brand colors
        switch self {
        case .instagram: return "camera.circle.fill"
        case .twitter: return "bird.fill"
        case .tiktok: return "music.note"
        case .facebook: return "f.circle.fill"
        }
    }

    @MainActor
    var color: Color {
        switch self {
        case .instagram: return Color(red: 0.91, green: 0.30, blue: 0.62)
        case .twitter: return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .tiktok: return Color(red: 0.0, green: 0.95, blue: 0.85)
        case .facebook: return Color(red: 0.23, green: 0.40, blue: 0.85)
        }
    }
}

nonisolated enum SocialLink {
    /// Strip whitespace, leading @ / slashes, and full URL prefixes; return nil for empty.
    static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        // Strip protocol + known hosts
        let lowers = ["https://", "http://", "www."]
        for p in lowers where s.lowercased().hasPrefix(p) {
            s = String(s.dropFirst(p.count))
        }
        let hosts = ["instagram.com/", "x.com/", "twitter.com/", "tiktok.com/", "facebook.com/", "fb.com/"]
        for h in hosts where s.lowercased().hasPrefix(h) {
            s = String(s.dropFirst(h.count))
        }
        while s.first == "@" || s.first == "/" {
            s.removeFirst()
        }
        // Strip trailing slash / query
        if let q = s.firstIndex(where: { $0 == "?" || $0 == "/" }) {
            s = String(s[..<q])
        }
        return s.isEmpty ? nil : s
    }

    static func url(for platform: SocialPlatform, handle: String?) -> URL? {
        guard let cleaned = normalize(handle ?? "") else { return nil }
        let base: String
        switch platform {
        case .instagram: base = "https://instagram.com/\(cleaned)"
        case .twitter:   base = "https://x.com/\(cleaned)"
        case .tiktok:    base = "https://tiktok.com/@\(cleaned)"
        case .facebook:  base = "https://facebook.com/\(cleaned)"
        }
        return URL(string: base)
    }
}
