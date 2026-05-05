import SwiftUI

nonisolated enum RichTextToken: Sendable, Equatable {
    case text(String)
    case mention(String)
    case hashtag(String)

    var displayString: String {
        switch self {
        case .text(let s): return s
        case .mention(let h): return "@\(h)"
        case .hashtag(let h): return "#\(h)"
        }
    }
}

nonisolated enum RichTextParser {
    static func tokens(in text: String) -> [RichTextToken] {
        guard !text.isEmpty else { return [] }
        var result: [RichTextToken] = []
        var buffer = ""
        let scalars = Array(text)
        var i = 0
        while i < scalars.count {
            let ch = scalars[i]
            if ch == "@" || ch == "#" {
                let prevOK: Bool = {
                    guard i > 0 else { return true }
                    let p = scalars[i - 1]
                    return p.isWhitespace || p.isNewline || !(p.isLetter || p.isNumber || p == "_")
                }()
                if prevOK {
                    var j = i + 1
                    var word = ""
                    while j < scalars.count {
                        let c = scalars[j]
                        if c.isLetter || c.isNumber || c == "_" || c == "-" {
                            word.append(c)
                            j += 1
                        } else {
                            break
                        }
                    }
                    if !word.isEmpty {
                        if !buffer.isEmpty {
                            result.append(.text(buffer))
                            buffer = ""
                        }
                        if ch == "@" {
                            result.append(.mention(word))
                        } else {
                            result.append(.hashtag(word))
                        }
                        i = j
                        continue
                    }
                }
            }
            buffer.append(ch)
            i += 1
        }
        if !buffer.isEmpty { result.append(.text(buffer)) }
        return result
    }

    static func extractMentions(_ text: String) -> [String] {
        tokens(in: text).compactMap {
            if case .mention(let h) = $0 { return h.lowercased() } else { return nil }
        }
    }

    static func extractHashtags(_ text: String) -> [String] {
        tokens(in: text).compactMap {
            if case .hashtag(let h) = $0 { return h.lowercased() } else { return nil }
        }
    }

    /// Parses the active token at caret for autocomplete suggestions.
    /// Returns the trigger character (@ or #), the query string, and the range of the token.
    static func activeAutocompleteQuery(in text: String, caret: Int) -> (trigger: Character, query: String, range: Range<String.Index>)? {
        let chars = Array(text)
        let safeCaret = min(max(caret, 0), chars.count)
        var j = safeCaret
        while j > 0 {
            let c = chars[j - 1]
            if c.isLetter || c.isNumber || c == "_" || c == "-" {
                j -= 1
            } else {
                break
            }
        }
        guard j > 0 else { return nil }
        let trig = chars[j - 1]
        guard trig == "@" || trig == "#" else { return nil }
        let prevOK: Bool = {
            guard j > 1 else { return true }
            let p = chars[j - 2]
            return p.isWhitespace || p.isNewline || !(p.isLetter || p.isNumber || p == "_")
        }()
        guard prevOK else { return nil }
        let query = String(chars[j..<safeCaret])
        let start = text.index(text.startIndex, offsetBy: j - 1)
        let end = text.index(text.startIndex, offsetBy: safeCaret)
        return (trig, query, start..<end)
    }
}

struct RichText: View {
    let text: String
    var font: Font = .body
    var textColor: Color = PepTheme.textPrimary
    var linkColor: Color = PepTheme.teal
    var onMention: ((String) -> Void)? = nil
    var onHashtag: ((String) -> Void)? = nil

    var body: some View {
        let tokens = RichTextParser.tokens(in: text)
        let attr = buildAttributedString(tokens: tokens)
        Text(attr)
            .font(font)
            .foregroundStyle(textColor)
            .environment(\.openURL, OpenURLAction { url in
                guard let scheme = url.scheme else { return .discarded }
                let handle = url.host ?? url.path.trimmingCharacters(in: .init(charactersIn: "/"))
                if scheme == "peppalmention" {
                    onMention?(handle)
                    return .handled
                }
                if scheme == "peppalhashtag" {
                    onHashtag?(handle)
                    return .handled
                }
                return .discarded
            })
    }

    private func buildAttributedString(tokens: [RichTextToken]) -> AttributedString {
        var out = AttributedString("")
        for token in tokens {
            switch token {
            case .text(let s):
                var piece = AttributedString(s)
                piece.foregroundColor = textColor
                out.append(piece)
            case .mention(let h):
                var piece = AttributedString("@\(h)")
                piece.foregroundColor = linkColor
                piece.font = font.weight(.semibold)
                if let url = URL(string: "peppalmention://\(h)") {
                    piece.link = url
                }
                out.append(piece)
            case .hashtag(let h):
                var piece = AttributedString("#\(h)")
                piece.foregroundColor = linkColor
                piece.font = font.weight(.semibold)
                if let url = URL(string: "peppalhashtag://\(h.lowercased())") {
                    piece.link = url
                }
                out.append(piece)
            }
        }
        return out
    }
}
