import Foundation

enum QRCodeHistory {
    static let limit = 200
    static let byteLimit = 2_000

    static func validate(_ content: String) throws {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Failure.empty
        }
        guard content.utf8.count <= byteLimit else { throw Failure.tooLong }
    }

    static func recording(
        _ content: String, in entries: [QRCodeEntry], id: UUID, now: Date
    ) -> [QRCodeEntry] {
        let entry = QRCodeEntry(id: id, content: content, createdAt: now)
        return [entry] + entries.filter { $0.content != content }.prefix(limit - 1)
    }

    enum Failure: LocalizedError {
        case empty, tooLong, rendering, invalidHistory

        var errorDescription: String? {
            switch self {
            case .empty: String(localized: "Enter text or a URL to generate a QR code.")
            case .tooLong: String(localized: "QR code content must fit within 2,000 UTF-8 bytes.")
            case .rendering: String(localized: "Could not generate the QR code.")
            case .invalidHistory: String(localized: "Could not read QR code history. The saved file was not changed.")
            }
        }
    }
}
