import Foundation

@main
struct TranslationTests {
    static func main() throws {
        let credentials = BaiduTranslationService.Credentials(appID: "2015063000000001", secret: "12345678")
        let request = try BaiduTranslationService.request(
            text: "apple", source: "en", target: "zh", credentials: credentials, salt: "1435660288")
        let body = String(bytes: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        precondition(request.httpMethod == "POST")
        precondition(request.url?.scheme == "https")
        precondition(body.contains("sign=f89f9594663708c1605f3d736d01d2d4"))
        precondition(!body.contains("12345678"))
        let original = "你好 & + ? #\nworld"
        let unicodeRequest = try BaiduTranslationService.request(
            text: original, source: "auto", target: "en", credentials: credentials, salt: "test")
        var components = URLComponents()
        components.percentEncodedQuery = String(bytes: unicodeRequest.httpBody ?? Data(), encoding: .utf8)
        precondition(components.queryItems?.first { $0.name == "q" }?.value == original)
        precondition(components.percentEncodedQuery?.contains("%2B") == true)
        try BaiduTranslation.validate(String(repeating: "中", count: 2000), source: "auto", target: "zh")
        for (text, source, target) in [(" ", "auto", "zh"), (String(repeating: "中", count: 2001), "auto", "zh"),
            ("hello", "auto", "auto"), ("hello", "invalid", "en")] {
            do {
                try BaiduTranslation.validate(text, source: source, target: target)
                preconditionFailure("Invalid translation request accepted")
            } catch is BaiduTranslation.Failure { }
        }
        let data = Data(#"{"from":"en","to":"zh","trans_result":[{"dst":"你好"},{"dst":"世界"}]}"#.utf8)
        let result = try BaiduTranslation.decode(data, original: "hello\nworld")
        precondition(result.text == "你好\n世界")
        precondition(result.source == "en" && result.target == "zh")
        for invalid in ["{}", "null", #"{"error_code":"54001"}"#,
            #"{"from":"en","to":"zh","trans_result":[]}"#,
            #"{"from":"en","to":"zh","trans_result":[{"dst":123}]}"#] {
            do {
                _ = try BaiduTranslation.decode(Data(invalid.utf8), original: "test")
                preconditionFailure("Invalid response accepted")
            } catch is BaiduTranslation.Failure { }
        }
        precondition(TranslationLanguage.automaticTarget(detectedSource: "zh") == "en")
        precondition(TranslationLanguage.automaticTarget(detectedSource: "cht") == "en")
        precondition(TranslationLanguage.automaticTarget(detectedSource: "jp") == "zh")
        var history = TranslationHistory()
        precondition(history.move(older: true) == nil)
        for index in 0..<25 {
            history.append(BaiduTranslation(original: "\(index)", text: "result", source: "en", target: "zh"))
        }
        precondition(history.entries.count == 20)
        precondition(history.move(older: true)?.original == "24")
        precondition(history.move(older: true)?.original == "23")
        precondition(history.move(older: false)?.original == "24")
        for _ in 0..<30 { _ = history.move(older: true) }
        precondition(history.move(older: true)?.original == "5")
        history.append(result)
        history.append(result)
        precondition(history.entries.filter { $0 == result }.count == 1)
        precondition(history.index == nil)
        print("Translation signing, encoding, validation, responses, language selection and history passed")
    }
}
