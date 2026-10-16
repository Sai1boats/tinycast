import Foundation

enum UtilityTool: String, CaseIterable, Identifiable, Sendable {
    case json, timestamp, currency
    case urlCodec, base64, uuid, hash, jwt, textDiff
    var id: Self { self }
    var title: String {
        switch self {
        case .json: "JSON Tools"
        case .timestamp: "Timestamp Converter"
        case .currency: "Currency Converter"
        case .urlCodec: "URL Encoder / Decoder"
        case .base64: "Base64 Encoder / Decoder"
        case .uuid: "UUID Generator"
        case .hash: "Hash Generator"
        case .jwt: "JWT Viewer"
        case .textDiff: "Text Diff"
        }
    }

    var isDeveloperTool: Bool {
        switch self {
        case .json, .timestamp, .currency: false
        case .urlCodec, .base64, .uuid, .hash, .jwt, .textDiff: true
        }
    }
}
