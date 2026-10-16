import Foundation

enum UUIDGenerator {
    enum Failure: Error { case invalidCount }
    static let maximumCount = 1_000

    static func generate(count: Int, uppercase: Bool, hyphenated: Bool, makeUUID: () -> UUID) throws -> String {
        guard (1...maximumCount).contains(count) else { throw Failure.invalidCount }
        return (0..<count).map { _ in
            let value = makeUUID().uuidString
            let cased = uppercase ? value : value.lowercased()
            return hyphenated ? cased : cased.replacingOccurrences(of: "-", with: "")
        }.joined(separator: "\n")
    }
}
