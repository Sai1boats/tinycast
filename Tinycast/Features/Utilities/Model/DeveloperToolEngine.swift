import Foundation

enum DeveloperToolEngine {
    enum Operation: Sendable {
        case encodeURL(URLCodec.Mode), decodeURL(URLCodec.Mode)
        case encodeBase64(Base64Codec.Alphabet), decodeBase64(Base64Codec.Alphabet)
        case hash(TextHash.Algorithm)
        case jwt(Date)
        case diff(String)
    }

    enum Result: Sendable {
        case text(String)
        case jwt(JWTContents.Result)
        case diff(TextComparison.Result)
    }

    @concurrent static func run(_ input: String, operation: Operation) async throws -> Result {
        try Task.checkCancellation()
        let result: Result = switch operation {
        case .encodeURL(let mode): .text(try URLCodec.encode(input, mode: mode))
        case .decodeURL(let mode): .text(try URLCodec.decode(input, mode: mode))
        case .encodeBase64(let alphabet): .text(try Base64Codec.encode(input, alphabet: alphabet))
        case .decodeBase64(let alphabet): .text(try Base64Codec.decode(input, alphabet: alphabet))
        case .hash(let algorithm): .text(try TextHash.digest(input, algorithm: algorithm))
        case .jwt(let now): .jwt(try JWTContents.inspect(input, now: now))
        case .diff(let modified): .diff(try TextComparison.compare(original: input, modified: modified))
        }
        try Task.checkCancellation()
        return result
    }
}
