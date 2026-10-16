import Foundation
import Observation

@MainActor
@Observable
final class DeveloperToolSession {
    var input = "" { didSet { if oldValue != input { cancel() } } }
    var comparisonInput = "" { didSet { if oldValue != comparisonInput { cancel() } } }
    var urlMode = URLCodec.Mode.component { didSet { if oldValue != urlMode { cancel() } } }
    var base64Alphabet = Base64Codec.Alphabet.standard { didSet { if oldValue != base64Alphabet { cancel() } } }
    var hashAlgorithm = TextHash.Algorithm.sha256 { didSet { if oldValue != hashAlgorithm { cancel() } } }
    var uuidCount = 1 { didSet { if oldValue != uuidCount { cancel() } } }
    var uppercaseUUID = false { didSet { if oldValue != uppercaseUUID { cancel() } } }
    var hyphenatedUUID = true { didSet { if oldValue != hyphenatedUUID { cancel() } } }
    private(set) var output = ""
    private(set) var error = ""
    private(set) var isBusy = false
    private(set) var jwt: JWTContents.Result?
    private(set) var comparison: TextComparison.Result?
    @ObservationIgnored private var task: Task<Void, Never>?
    private var generation = 0

    isolated deinit { task?.cancel() }

    func run(_ operation: DeveloperToolEngine.Operation) {
        cancel()
        let version = generation
        let source = input
        isBusy = true
        task = Task { [weak self] in
            do {
                let result = try await DeveloperToolEngine.run(source, operation: operation)
                guard let self, !Task.isCancelled, self.generation == version else { return }
                switch result {
                case .text(let value): self.output = value
                case .jwt(let value): self.jwt = value
                case .diff(let value): self.comparison = value; self.output = value.output
                }
                self.isBusy = false
                self.task = nil
            } catch {
                guard let self, !Task.isCancelled, self.generation == version else { return }
                self.isBusy = false
                self.task = nil
                self.report(error)
            }
        }
    }

    func generateUUIDs() {
        cancel()
        do {
            output = try UUIDGenerator.generate(
                count: uuidCount, uppercase: uppercaseUUID, hyphenated: hyphenatedUUID, makeUUID: { UUID() })
        } catch { report(error) }
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        isBusy = false
        output = ""
        error = ""
        jwt = nil
        comparison = nil
    }

    func clipboardUnavailable() {
        error = String(localized: "The clipboard contains no text.")
    }

    private func report(_ failure: Error) {
        error = switch failure {
        case URLCodec.Failure.tooLarge, Base64Codec.Failure.tooLarge, TextHash.Failure.tooLarge, JWTContents.Failure.tooLarge:
            String(localized: "Input is too large. The maximum is 1 MB of UTF-8 text.")
        case URLCodec.Failure.invalidEncoding:
            String(localized: "Enter valid percent-encoded UTF-8 text. Each % must be followed by two hexadecimal digits.")
        case Base64Codec.Failure.invalidEncoding:
            String(localized: "Enter valid Base64 using the selected alphabet and correct padding.")
        case Base64Codec.Failure.nonUTF8:
            String(localized: "The decoded bytes are not UTF-8 text.")
        case JWTContents.Failure.encrypted:
            String(localized: "This is an encrypted five-part token. JWT Viewer supports three-part tokens.")
        case JWTContents.Failure.invalidToken:
            String(localized: "Enter a three-part JWT with Base64url header, payload and signature.")
        case JWTContents.Failure.invalidJSON:
            String(localized: "The JWT header and payload must be valid JSON objects.")
        case UUIDGenerator.Failure.invalidCount:
            String(localized: "Generate between 1 and 1,000 UUIDs.")
        case TextComparison.Failure.tooLarge:
            String(localized: "Each text must be at most 128 KB of UTF-8 text.")
        case TextComparison.Failure.tooManyLines:
            String(localized: "Each text must contain at most 1,000 lines.")
        default: failure.localizedDescription
        }
    }
}
