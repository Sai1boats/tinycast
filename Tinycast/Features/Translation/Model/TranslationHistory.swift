import Foundation

struct TranslationHistory {
    private(set) var entries: [TranslationResult] = []
    private(set) var index: Int?

    mutating func append(_ result: TranslationResult) {
        entries.removeAll { $0 == result }
        entries.insert(result, at: 0)
        entries = Array(entries.prefix(20))
        index = nil
    }

    mutating func move(older: Bool) -> TranslationResult? {
        guard !entries.isEmpty else { return nil }
        let next = index.map { $0 + (older ? 1 : -1) } ?? 0
        index = min(max(next, 0), entries.count - 1)
        return entries[index ?? 0]
    }
}
