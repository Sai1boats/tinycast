import Foundation

/// Long text becomes whole lines grouped under Baidu's per-request limit, in reading order.
enum TranslationChunks {
    static let requestLimit = 6000
    static let maximumChunks = 10
    static let totalLimit = requestLimit * maximumChunks

    /// Room for the blank lines a chunk may carry ahead of a line split to the piece limit.
    private static let blankLineAllowance = 100

    static func split(_ text: String, limit: Int = requestLimit) -> [String] {
        let pieceLimit = max(limit - blankLineAllowance, limit / 2)
        let lines = text.components(separatedBy: "\n").flatMap { pieces(of: $0, limit: pieceLimit) }
        var chunks: [String] = []
        var current: [String] = []
        var size = 0
        for line in lines {
            let added = line.utf8.count + (current.isEmpty ? 0 : 1)
            if !current.isEmpty, size + added > limit, current.contains(where: isFilled) {
                chunks.append(current.joined(separator: "\n"))
                current = []
                size = 0
            }
            size += line.utf8.count + (current.isEmpty ? 0 : 1)
            current.append(line)
        }
        if current.contains(where: isFilled) {
            chunks.append(current.joined(separator: "\n"))
        } else if !current.isEmpty, !chunks.isEmpty {
            chunks[chunks.count - 1] += "\n" + current.joined(separator: "\n")
        }
        return chunks
    }

    private static func isFilled(_ line: String) -> Bool {
        !line.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// An overlong line breaks after a sentence where it can, otherwise between characters.
    private static func pieces(of line: String, limit: Int) -> [String] {
        guard line.utf8.count > limit else { return [line] }
        var pieces: [String] = []
        var current = ""
        var lastBreak: String.Index?
        for character in line {
            if current.utf8.count + character.utf8.count > limit {
                if let lastBreak, lastBreak < current.endIndex {
                    pieces.append(String(current[..<lastBreak]))
                    current = String(current[lastBreak...])
                }
                if current.utf8.count + character.utf8.count > limit {
                    pieces.append(current)
                    current = ""
                }
                lastBreak = nil
            }
            current.append(character)
            if "。！？；.!?;".contains(character) { lastBreak = current.endIndex }
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }
}
