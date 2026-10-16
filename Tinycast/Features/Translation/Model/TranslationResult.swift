import Foundation

struct TranslationResult: Equatable, Sendable {
    enum Provider: String, Sendable { case baidu, apple }

    /// One source line and its translation; a blank line stays a blank paragraph on both sides.
    struct Paragraph: Equatable, Sendable {
        let source: String
        let text: String
    }

    let original: String
    let paragraphs: [Paragraph]
    let source: String
    let target: String
    let provider: Provider

    var text: String { paragraphs.map(\.text).joined(separator: "\n") }

    /// Pairs translated lines with the non-blank source lines they answer, keeping blank lines.
    static func paragraphs(original: String, translations: [(source: String, text: String)]) -> [Paragraph] {
        let lines = original.components(separatedBy: "\n")
        let filled = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard filled.count == translations.count else {
            return translations.map { Paragraph(source: $0.source, text: $0.text) }
        }
        var remaining = translations[...]
        return lines.map { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty, let next = remaining.popFirst() else {
                return Paragraph(source: "", text: "")
            }
            return Paragraph(source: line, text: next.text)
        }
    }

    /// Appends a later chunk; both sides already agree on what the languages resolved to.
    func appending(_ next: Self) -> Self {
        Self(original: original + "\n" + next.original, paragraphs: paragraphs + next.paragraphs,
             source: source, target: target, provider: provider)
    }
}
