import CryptoKit
import Foundation

struct BaiduTranslationService: Sendable {
    struct Credentials: Codable, Sendable {
        let appID: String
        let secret: String
    }

    private static let account = UUID(uuidString: "B71D64D2-D2F0-4433-952B-79D55F345EDA")!
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration)
    }()

    @concurrent static func credentials() async throws -> Credentials? {
        guard let value = try KeychainSecretStore.baiduTranslation.secret(for: account) else { return nil }
        return try JSONDecoder().decode(Credentials.self, from: Data(value.utf8))
    }

    @concurrent static func save(_ credentials: Credentials) async throws {
        guard !credentials.appID.isEmpty, !credentials.secret.isEmpty else {
            throw BaiduTranslation.Failure.credentials
        }
        let data = try JSONEncoder().encode(credentials)
        guard let value = String(data: data, encoding: .utf8) else { throw KeychainSecretStore.StoreError.invalidEncoding }
        try Task.checkCancellation()
        try KeychainSecretStore.baiduTranslation.setSecret(value, for: account)
    }

    static func request(
        text: String, source: String, target: String, credentials: Credentials, salt: String
    ) throws -> URLRequest {
        try BaiduTranslation.validate(text, source: source, target: target)
        guard !credentials.appID.isEmpty, !credentials.secret.isEmpty else { throw BaiduTranslation.Failure.credentials }
        let signature = Insecure.MD5.hash(data: Data((credentials.appID + text + salt + credentials.secret).utf8))
            .map { String(format: "%02x", $0) }.joined()
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "q", value: text), URLQueryItem(name: "from", value: source),
            URLQueryItem(name: "to", value: target), URLQueryItem(name: "appid", value: credentials.appID),
            URLQueryItem(name: "salt", value: salt), URLQueryItem(name: "sign", value: signature)
        ]
        var request = URLRequest(url: URL(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        return request
    }

    @concurrent static func translate(
        text: String, source: String, target: String, credentials: Credentials
    ) async throws -> TranslationResult {
        let resolvedTarget = TranslationLanguageDetector.resolvedTarget(for: text, source: source, target: target)
        let request = try request(
            text: text, source: source, target: resolvedTarget, credentials: credentials, salt: UUID().uuidString)
        try Task.checkCancellation()
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw BaiduTranslation.Failure.unavailable
        }
        return try BaiduTranslation.decode(data, original: text)
    }
}
