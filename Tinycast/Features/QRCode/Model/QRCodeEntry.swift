import Foundation

struct QRCodeEntry: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let content: String
    let createdAt: Date

    var title: String {
        if let url = URL(string: content), let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme), let host = url.host, !host.isEmpty
        {
            return host
        }
        return String(content.prefix(100))
    }
}
