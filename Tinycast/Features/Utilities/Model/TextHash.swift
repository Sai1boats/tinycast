import CryptoKit
import Foundation

enum TextHash {
    enum Algorithm: String, CaseIterable, Sendable {
        case sha256, sha384, sha512, sha1, md5
        var title: String {
            switch self {
            case .sha256: "SHA-256"
            case .sha384: "SHA-384"
            case .sha512: "SHA-512"
            case .sha1: "SHA-1"
            case .md5: "MD5"
            }
        }
    }

    enum Failure: Error { case tooLarge }
    static let maximumBytes = 1_048_576

    static func digest(_ source: String, algorithm: Algorithm) throws -> String {
        guard source.utf8.count <= maximumBytes else { throw Failure.tooLarge }
        let data = Data(source.utf8)
        let bytes: [UInt8] = switch algorithm {
        case .sha256: Array(SHA256.hash(data: data))
        case .sha384: Array(SHA384.hash(data: data))
        case .sha512: Array(SHA512.hash(data: data))
        case .sha1: Array(Insecure.SHA1.hash(data: data))
        case .md5: Array(Insecure.MD5.hash(data: data))
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
