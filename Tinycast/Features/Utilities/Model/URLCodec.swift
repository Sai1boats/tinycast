import Foundation

enum URLCodec {
    enum Mode: String, CaseIterable, Sendable {
        case component, form
        var title: String { self == .component ? "URL Component" : "Form Value" }
    }

    enum Failure: Error { case tooLarge, invalidEncoding }
    static let maximumBytes = 1_048_576
    private static let unreserved = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    private static let formCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789*-._")

    static func encode(_ source: String, mode: Mode) throws -> String {
        guard source.utf8.count <= maximumBytes else { throw Failure.tooLarge }
        let allowed = mode == .form ? formCharacters : unreserved
        guard let encoded = source.addingPercentEncoding(withAllowedCharacters: allowed) else {
            throw Failure.invalidEncoding
        }
        return mode == .form ? encoded.replacingOccurrences(of: "%20", with: "+") : encoded
    }

    static func decode(_ source: String, mode: Mode) throws -> String {
        guard source.utf8.count <= maximumBytes else { throw Failure.tooLarge }
        let input = mode == .form ? source.replacingOccurrences(of: "+", with: " ") : source
        guard let decoded = input.removingPercentEncoding else { throw Failure.invalidEncoding }
        return decoded
    }
}
