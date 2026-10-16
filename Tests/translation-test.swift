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
        try BaiduTranslation.validateDocument(String(repeating: "中", count: 20000), source: "auto", target: "auto")
        for (text, target) in [("  \n ", "zh"), (String(repeating: "中", count: 20001), "zh"), ("hi", "invalid")] {
            do {
                try BaiduTranslation.validateDocument(text, source: "auto", target: target)
                preconditionFailure("Invalid document accepted")
            } catch is BaiduTranslation.Failure { }
        }
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
        precondition(result.source == "en" && result.target == "zh" && result.provider == .baidu)
        precondition(result.paragraphs.map(\.source) == ["hello", "world"])
        let spaced = try BaiduTranslation.decode(
            Data(#"{"from":"en","to":"zh","trans_result":[{"src":"a","dst":"甲"},{"src":"b","dst":"乙"}]}"#.utf8),
            original: "a\n\n  \nb")
        precondition(spaced.text == "甲\n\n\n乙", "blank source lines survive as blank paragraphs")
        let mismatched = TranslationResult.paragraphs(original: "one line", translations: [("x", "1"), ("y", "2")])
        precondition(mismatched.map(\.text) == ["1", "2"], "an unexpected segment count keeps Baidu's own pairs")
        let joined = spaced.appending(result)
        precondition(joined.text == "甲\n\n\n乙\n你好\n世界" && joined.original == "a\n\n  \nb\nhello\nworld")
        testChunks()
        testFallbackPolicy()
        testLanguages()
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
            history.append(TranslationResult(
                original: "\(index)", paragraphs: [.init(source: "\(index)", text: "result")],
                source: "en", target: "zh", provider: .baidu))
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

    static func testChunks() {
        precondition(TranslationChunks.split("short\ntext") == ["short\ntext"])
        precondition(TranslationChunks.split(" \n\t").isEmpty, "blank text sends nothing")
        let paragraph = String(repeating: "句子。", count: 400)
        let document = (0..<12).map { _ in paragraph }.joined(separator: "\n\n")
        let chunks = TranslationChunks.split(document)
        precondition(chunks.count > 1 && chunks.allSatisfy { $0.utf8.count <= TranslationChunks.requestLimit })
        precondition(chunks.joined(separator: "\n") == document, "chunks rejoin to the exact source")
        let line = String(repeating: "word ", count: 1500) + "end."
        let pieces = TranslationChunks.split(line)
        precondition(pieces.count > 1 && pieces.allSatisfy { $0.utf8.count <= TranslationChunks.requestLimit })
        precondition(pieces.joined(separator: "\n").replacingOccurrences(of: "\n", with: "") == line,
                     "an overlong line keeps every character")
        let sentences = String(repeating: "很长的一句话。", count: 400)
        precondition(TranslationChunks.split(sentences).dropLast().allSatisfy { $0.hasSuffix("。") },
                     "an overlong line breaks after sentences")
        let emoji = String(repeating: "👩‍💻", count: 1000)
        precondition(TranslationChunks.split(emoji).joined() == emoji, "grapheme clusters are never cut")
        let padded = String(repeating: "\n", count: 50) + String(repeating: "x", count: 5990)
        precondition(TranslationChunks.split("a\n" + padded).allSatisfy {
            $0.utf8.count <= TranslationChunks.requestLimit })
    }

    static func testFallbackPolicy() {
        for failure: BaiduTranslation.Failure in [.credentials, .authentication, .rateLimit, .balance, .unavailable,
            .malformed, .tooLong] {
            precondition(BaiduTranslation.allowsFallback(after: failure), "\(failure) falls back")
        }
        precondition(!BaiduTranslation.allowsFallback(after: BaiduTranslation.Failure.empty))
        precondition(!BaiduTranslation.allowsFallback(after: BaiduTranslation.Failure.language))
        precondition(!BaiduTranslation.allowsFallback(after: CancellationError()))
        precondition(!BaiduTranslation.allowsFallback(after: URLError(.cancelled)))
        precondition(BaiduTranslation.allowsFallback(after: URLError(.notConnectedToInternet)))
        precondition(BaiduTranslation.allowsFallback(after: URLError(.timedOut)))
    }

    static func testLanguages() {
        precondition(TranslationLanguage.apple(for: "zh") == "zh-Hans")
        precondition(TranslationLanguage.apple(for: "jp") == "ja")
        precondition(TranslationLanguage.apple(for: "yue") == nil && TranslationLanguage.apple(for: "auto") == nil)
        for (tag, code) in [("zh-Hans", "zh"), ("zh-Hant", "cht"), ("zh-TW", "cht"), ("ja", "jp"), ("ko", "kor"),
            ("en-US", "en"), ("pt-BR", "pt"), ("es", "spa"), ("fr", "fra"), ("ar", "ara"), ("vi", "vie")] {
            precondition(TranslationLanguage.code(forLanguageTag: tag) == code, "\(tag) reads as \(code)")
        }
        for language in TranslationLanguage.all {
            guard let apple = language.apple else { continue }
            precondition(TranslationLanguage.code(forLanguageTag: apple) == language.id, "\(apple) round-trips")
        }
    }
}
