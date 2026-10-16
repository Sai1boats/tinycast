import Foundation

@main
struct DeveloperToolsTests {
    @MainActor static func main() async throws {
        try urls()
        try base64()
        try uuids()
        try hashes()
        try tokens()
        try differences()
        try await sessions()
        print("URL and Base64 vectors, UUID formats, hash vectors, JWT claims, exact diffs and cancellation passed")
    }

    static func urls() throws {
        let source = "你好 👩🏽‍💻 +/?&=#%"
        for mode in URLCodec.Mode.allCases {
            check(try URLCodec.decode(URLCodec.encode(source, mode: mode), mode: mode) == source)
        }
        check(try URLCodec.encode("AZaz09-._~", mode: .component) == "AZaz09-._~")
        check(try URLCodec.encode("a b+c/d?e&f=g", mode: .component) == "a%20b%2Bc%2Fd%3Fe%26f%3Dg")
        check(try URLCodec.encode("a b+c", mode: .form) == "a+b%2Bc")
        check(try URLCodec.encode("*~!()' ", mode: .form) == "*%7E%21%28%29%27+")
        check(try URLCodec.encode("*~!()' ", mode: .component) == "%2A~%21%28%29%27%20")
        check(try URLCodec.decode("a+b", mode: .component) == "a+b")
        check(try URLCodec.decode("a+b", mode: .form) == "a b")
        check(try URLCodec.decode("%2520", mode: .component) == "%20")
        check(try URLCodec.encode("", mode: .component).isEmpty)
        for invalid in ["%", "%0", "%GG", "%FF", "%C0%AF", "%ED%A0%80"] {
            rejects { _ = try URLCodec.decode(invalid, mode: .component) }
        }
        rejects { _ = try URLCodec.encode(String(repeating: "x", count: URLCodec.maximumBytes + 1), mode: .form) }
    }

    static func base64() throws {
        let vectors = [("", ""), ("f", "Zg=="), ("fo", "Zm8="), ("foo", "Zm9v"),
                       ("foob", "Zm9vYg=="), ("fooba", "Zm9vYmE="), ("foobar", "Zm9vYmFy")]
        for (source, encoded) in vectors {
            check(try Base64Codec.encode(source, alphabet: .standard) == encoded)
            check(try Base64Codec.decode(encoded, alphabet: .standard) == source)
            check(try Base64Codec.decode(encoded.replacingOccurrences(of: "=", with: ""), alphabet: .urlSafe) == source)
        }
        check(try Base64Codec.decode(" Zm\n9v\r\n", alphabet: .standard) == "foo")
        check(try Base64Codec.decode("Zg==", alphabet: .urlSafe) == "f")
        check(Base64Codec.encode(Data([251, 255]), alphabet: .urlSafe) == "-_8")
        check(try Base64Codec.decodeData("-_8", alphabet: .urlSafe) == Data([251, 255]))
        let unicode = "你好\n👩🏽‍💻\0"
        check(try Base64Codec.decode(Base64Codec.encode(unicode, alphabet: .standard), alphabet: .standard) == unicode)
        for invalid in ["Zg", "Zg=", "Zg===", "Z=g=", "Zh==", "Zm9=", "A===", "Zm9v!", "-_8="] {
            rejects { _ = try Base64Codec.decode(invalid, alphabet: .standard) }
        }
        for invalid in ["A", "Zh", "Zm9", "+/8", "Zm9v=", "===="] {
            rejects { _ = try Base64Codec.decodeData(invalid, alphabet: .urlSafe) }
        }
        rejects { _ = try Base64Codec.decodeData("Z m9v", alphabet: .urlSafe, allowsWhitespace: false) }
        rejects { _ = try Base64Codec.decode("/w==", alphabet: .standard) }
        rejects { _ = try Base64Codec.decode(String(repeating: "A", count: Base64Codec.maximumBytes + 1), alphabet: .standard) }
    }

    static func uuids() throws {
        let id = UUID(uuidString: "12345678-90AB-4CDE-8F01-234567890ABC")!
        check(try UUIDGenerator.generate(count: 2, uppercase: true, hyphenated: true, makeUUID: { id })
              == id.uuidString + "\n" + id.uuidString)
        check(try UUIDGenerator.generate(count: 1, uppercase: false, hyphenated: false, makeUUID: { id })
              == "1234567890ab4cde8f01234567890abc")
        let generated = try UUIDGenerator.generate(count: 100, uppercase: false, hyphenated: true, makeUUID: { UUID() })
        let lines = generated.split(separator: "\n")
        check(lines.count == 100 && Set(lines).count == 100)
        for line in lines {
            let value = UUID(uuidString: String(line))!.uuid
            check(value.6 >> 4 == 4 && value.8 >> 6 == 2)
        }
        for count in [0, -1, UUIDGenerator.maximumCount + 1] {
            rejects { _ = try UUIDGenerator.generate(count: count, uppercase: false, hyphenated: true, makeUUID: { id }) }
        }
    }

    static func hashes() throws {
        let expected: [TextHash.Algorithm: String] = [
            .md5: "900150983cd24fb0d6963f7d28e17f72",
            .sha1: "a9993e364706816aba3e25717850c26c9cd0d89d",
            .sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            .sha384: "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7",
            .sha512: "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a219"
                + "2992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
        ]
        for algorithm in TextHash.Algorithm.allCases {
            check(try TextHash.digest("abc", algorithm: algorithm) == expected[algorithm])
            check(try TextHash.digest("abc\n", algorithm: algorithm) != expected[algorithm])
        }
        check(try TextHash.digest("", algorithm: .md5) == "d41d8cd98f00b204e9800998ecf8427e")
        check(try TextHash.digest("", algorithm: .sha256)
              == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        rejects { _ = try TextHash.digest(String(repeating: "x", count: TextHash.maximumBytes + 1), algorithm: .sha256) }
    }

    static func token(_ payload: String, header: String = #"{"alg":"none"}"#, signature: String = "") throws -> String {
        try Base64Codec.encode(header, alphabet: .urlSafe) + "."
            + Base64Codec.encode(payload, alphabet: .urlSafe) + "." + signature
    }

    static func tokens() throws {
        let now = Date(timeIntervalSince1970: 100)
        let sample = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
            + "eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ."
            + "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let decoded = try JWTContents.inspect(sample, now: now)
        check(decoded.payload.contains("John Doe") && decoded.header.contains("HS256"))
        check(decoded.claims.first?.date == Date(timeIntervalSince1970: 1_516_239_022))
        let claims = try token(#"{"iat":10.5,"nbf":99,"exp":101,"id":123456789012345678901234567890}"#)
        let result = try JWTContents.inspect(claims, now: now)
        check(result.claims.map(\.name) == ["iat", "nbf", "exp"])
        check(result.claims[0].date.timeIntervalSince1970 == 10.5)
        check(result.payload.contains("123456789012345678901234567890"))
        check(result.timeStatus == .withinWindow)
        check(try JWTContents.inspect(token(#"{"exp":100}"#), now: now).timeStatus == .expired)
        check(try JWTContents.inspect(token(#"{"nbf":101}"#), now: now).timeStatus == .notYetActive)
        check(try JWTContents.inspect(token(#"{"exp":true,"iat":"10","nbf":1e999}"#), now: now).claims.isEmpty)
        check(try JWTContents.inspect("  Bearer " + sample + "\n", now: now).payload == decoded.payload)
        for invalid in ["", "a.b", "a.b.c.d.e", "a.b.c", try token("[]"), try token("null"),
                        try token("{}", header: "{}"), try token("{}", header: #"{"alg":"none","b64":false}"#),
                        try token("{}", signature: "!"), "=" + sample, sample + "\ninside"] {
            rejects { _ = try JWTContents.inspect(invalid, now: now) }
        }
        rejects { _ = try JWTContents.inspect(String(repeating: "x", count: Base64Codec.maximumBytes + 1), now: now) }
    }

    static func differences() throws {
        check(try TextComparison.compare(original: "", modified: "").isIdentical)
        let changed = try TextComparison.compare(original: "same\nold\nend\n", modified: "same\nnew\nend\n")
        check(changed.insertedCount == 1 && changed.deletedCount == 1)
        check(changed.output.contains("- old") && changed.output.contains("+ new"))
        for (old, new) in [("", "new"), ("old", ""), ("你好\n世界", "你好\n新世界"),
                           ("one\r\ntwo\r\n", "one\ntwo\n"), ("line", "line\n"),
                           ("a\nb\na\n", "b\na\nb\n"), (" \n\n", "\n"), ("a\rb\r", "a\rb")] {
            let result = try TextComparison.compare(original: old, modified: new)
            check(result.rows.filter { $0.kind != .inserted }.map(\.text).joined() == old)
            check(result.rows.filter { $0.kind != .deleted }.map(\.text).joined() == new)
            check(!result.isIdentical)
        }
        check(try TextComparison.compare(original: "a", modified: "a\n").output.contains("[No final newline]"))
        check(try TextComparison.compare(original: "a\r\n", modified: "a\n").output.contains("[CRLF]"))
        check(try TextComparison.compare(original: "\u{2028}a\n", modified: "\u{2028}a\n").output == "  \u{2028}a")
        for seed in 0..<100 {
            let old = (0..<12).map { "\((seed + $0 * 7) % 5)\n" }.joined()
            let new = (0..<12).map { "\((seed * 3 + $0 * 11) % 7)\n" }.joined()
            let result = try TextComparison.compare(original: old, modified: new)
            check(result.rows.filter { $0.kind != .inserted }.map(\.text).joined() == old)
            check(result.rows.filter { $0.kind != .deleted }.map(\.text).joined() == new)
        }
        let old = String(repeating: "old\n", count: TextComparison.maximumLines)
        let new = String(repeating: "new\n", count: TextComparison.maximumLines)
        let boundary = try TextComparison.compare(original: old, modified: new)
        check(boundary.insertedCount == TextComparison.maximumLines && boundary.deletedCount == TextComparison.maximumLines)
        rejects { _ = try TextComparison.compare(original: old + "extra", modified: "") }
        let oversized = String(repeating: "x", count: TextComparison.maximumBytes + 1)
        rejects { _ = try TextComparison.compare(original: oversized, modified: "") }
    }

    @MainActor static func sessions() async throws {
        let session = DeveloperToolSession()
        session.input = "old"
        session.run(.hash(.sha256))
        session.input = "new"
        try await Task.sleep(for: .milliseconds(10))
        check(!session.isBusy && session.output.isEmpty)
        session.input = String(repeating: "x", count: TextHash.maximumBytes)
        session.run(.hash(.sha512))
        session.input = "foo"
        session.run(.encodeBase64(.standard))
        try await settled(session)
        check(session.output == "Zm9v")
        session.base64Alphabet = .urlSafe
        check(session.output.isEmpty)
        session.run(.encodeURL(.component))
        session.cancel()
        try await Task.sleep(for: .milliseconds(10))
        check(!session.isBusy && session.output.isEmpty && session.error.isEmpty)
        session.input = try token(#"{"exp":0}"#)
        session.run(.jwt(Date(timeIntervalSince1970: 1)))
        try await settled(session)
        check(session.jwt?.timeStatus == .expired)
        session.input = "bad"
        check(session.jwt == nil)
        session.run(.jwt(Date(timeIntervalSince1970: 1)))
        try await settled(session)
        check(!session.error.isEmpty)
        session.uuidCount = 3
        session.generateUUIDs()
        check(session.output.split(separator: "\n").count == 3)
        let cancelled = Task { try await DeveloperToolEngine.run("abc", operation: .hash(.sha256)) }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            preconditionFailure("Cancelled work published")
        } catch is CancellationError { }
    }

    @MainActor static func settled(_ session: DeveloperToolSession) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while session.isBusy, ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(1)) }
        check(!session.isBusy)
    }

    static func check(_ condition: Bool) { precondition(condition) }
    static func rejects(_ operation: () throws -> Void) {
        do { try operation(); preconditionFailure("Invalid input was accepted") } catch { }
    }
}
