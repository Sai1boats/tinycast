import Foundation

struct NoteOutlineHeading: Sendable, Equatable, Identifiable {
    let level: Int
    let title: String
    let range: NSRange
    var id: Int { range.location }
}

struct NoteMetadataExtractor: Sendable, Equatable {
    var preview: String?
    var tags: [String] = []
    var headings: [NoteOutlineHeading] = []
    var pendingTaskCount = 0
    var totalTaskCount = 0
    var imageCount = 0

    init(source: String) {
        let markdown = NoteMarkdownParser.parse(source)
        let text = source as NSString
        var seen = Set<String>()
        var fallback: String?
        for line in markdown.lines {
            switch line.kind {
            case .image:
                imageCount += 1
                continue
            case .code, .table, .blank, .rule, .fenceOpen, .fenceClose:
                continue
            case .heading(let level) where level <= 3:
                headings.append(
                    NoteOutlineHeading(
                        level: level,
                        title: NoteTitle.visibleText(of: line, in: markdown, text: text),
                        range: line.contentRange))
            case .task(let checked):
                totalTaskCount += 1
                if !checked { pendingTaskCount += 1 }
            default: break
            }
            let content = text.substring(with: line.contentRange)
            if preview == nil {
                let snippet = String(NoteTitle.visibleText(of: line, in: markdown, text: text).prefix(160))
                if !snippet.isEmpty {
                    if case .heading = line.kind { fallback = fallback ?? snippet } else { preview = snippet }
                }
            }
            for (tag, _) in Self.tags(in: content) where seen.insert(tag).inserted { tags.append(tag) }
        }
        preview = preview ?? fallback
    }

    static func tags(in text: String) -> [(String, NSRange)] {
        guard text.contains("#") else { return [] }
        return text.matches(of: /#([\p{L}\p{N}_-]+)/).compactMap { match in
            if let previous = text[..<match.range.lowerBound].last,
                previous.isLetter || previous.isNumber || previous == "/" || previous == "_"
            {
                return nil
            }
            return (String(match.1).lowercased(), NSRange(match.range, in: text))
        }
    }
}
