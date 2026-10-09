import Foundation

enum JSONTool {
    enum Operation: Sendable { case format, compact, unescape }
    enum Failure: Error { case tooLarge, invalid(Int), nesting, notEscaped }

    @concurrent static func transform(_ source: String, operation: Operation) async throws -> String {
        try Task.checkCancellation()
        let result = try process(source, operation: operation)
        try Task.checkCancellation()
        return result
    }

    static func process(_ source: String, operation: Operation) throws -> String {
        guard source.utf8.count <= 1_048_576 else { throw Failure.tooLarge }
        if operation == .unescape {
            let input = source.trimmingCharacters(in: .whitespacesAndNewlines)
            let literal = input.hasPrefix("\"") ? input : "\"" + input + "\""
            guard let decoded = try? JSONDecoder().decode(String.self, from: Data(literal.utf8)) else {
                throw Failure.notEscaped
            }
            return decoded
        }
        var parser = Parser(bytes: Array(source.utf8))
        try parser.value(depth: 0)
        parser.whitespace()
        guard parser.offset == parser.bytes.count else { throw Failure.invalid(parser.offset + 1) }
        if operation == .compact { return parser.tokens.joined() }
        var output = ""
        var depth = 0
        for (index, token) in parser.tokens.enumerated() {
            switch token {
            case "{", "[":
                output += token
                depth += 1
                if parser.tokens[index + 1] != "}" && parser.tokens[index + 1] != "]" {
                    output += "\n" + String(repeating: "  ", count: depth)
                }
            case "}", "]":
                depth -= 1
                if parser.tokens[index - 1] != "{" && parser.tokens[index - 1] != "[" {
                    output += "\n" + String(repeating: "  ", count: depth)
                }
                output += token
            case ",": output += ",\n" + String(repeating: "  ", count: depth)
            case ":": output += ": "
            default: output += token
            }
            guard output.utf8.count <= 4_194_304 else { throw Failure.tooLarge }
        }
        return output
    }

    private struct Parser {
        let bytes: [UInt8]
        var offset = 0
        var tokens: [String] = []
        var current: UInt8? { offset < bytes.count ? bytes[offset] : nil }

        mutating func whitespace() {
            while let current, [9, 10, 13, 32].contains(current) { offset += 1 }
        }

        mutating func consume(_ byte: UInt8) throws {
            whitespace()
            guard current == byte else { throw Failure.invalid(offset + 1) }
            tokens.append(String(UnicodeScalar(byte)))
            offset += 1
        }

        mutating func value(depth: Int) throws {
            guard depth <= 128 else { throw Failure.nesting }
            whitespace()
            guard let byte = current else { throw Failure.invalid(offset + 1) }
            switch byte {
            case 123: try object(depth: depth)
            case 91: try array(depth: depth)
            case 34: try string()
            case 116: try literal("true")
            case 102: try literal("false")
            case 110: try literal("null")
            case 45, 48...57: try number()
            default: throw Failure.invalid(offset + 1)
            }
        }

        mutating func object(depth: Int) throws {
            try consume(123)
            whitespace()
            if current == 125 { try consume(125); return }
            while true {
                whitespace()
                try string()
                try consume(58)
                try value(depth: depth + 1)
                whitespace()
                if current == 125 { try consume(125); return }
                try consume(44)
            }
        }

        mutating func array(depth: Int) throws {
            try consume(91)
            whitespace()
            if current == 93 { try consume(93); return }
            while true {
                try value(depth: depth + 1)
                whitespace()
                if current == 93 { try consume(93); return }
                try consume(44)
            }
        }

        mutating func string() throws {
            guard current == 34 else { throw Failure.invalid(offset + 1) }
            let start = offset
            offset += 1
            while let byte = current {
                offset += 1
                if byte == 34 {
                    try record(from: start)
                    return
                }
                guard byte >= 32 else { throw Failure.invalid(offset) }
                if byte == 92 {
                    guard let escaped = current else { throw Failure.invalid(offset + 1) }
                    offset += 1
                    if escaped == 117 {
                        for _ in 0..<4 {
                            guard let hex = current, (48...57).contains(hex) || (65...70).contains(hex)
                                || (97...102).contains(hex) else { throw Failure.invalid(offset + 1) }
                            offset += 1
                        }
                    } else if ![34, 92, 47, 98, 102, 110, 114, 116].contains(escaped) {
                        throw Failure.invalid(offset)
                    }
                }
            }
            throw Failure.invalid(offset + 1)
        }

        mutating func literal(_ text: String) throws {
            for byte in text.utf8 {
                guard current == byte else { throw Failure.invalid(offset + 1) }
                offset += 1
            }
            tokens.append(text)
        }

        mutating func number() throws {
            let start = offset
            if current == 45 { offset += 1 }
            if current == 48 {
                offset += 1
            } else {
                guard let current, (49...57).contains(current) else { throw Failure.invalid(offset + 1) }
                digits()
            }
            if current == 46 { offset += 1; try requiredDigits() }
            if current == 101 || current == 69 {
                offset += 1
                if current == 43 || current == 45 { offset += 1 }
                try requiredDigits()
            }
            try record(from: start)
        }

        mutating func record(from start: Int) throws {
            guard let token = String(bytes: bytes[start..<offset], encoding: .utf8) else {
                throw Failure.invalid(start + 1)
            }
            tokens.append(token)
        }

        mutating func digits() {
            while let current, (48...57).contains(current) { offset += 1 }
        }

        mutating func requiredDigits() throws {
            let start = offset
            digits()
            guard offset > start else { throw Failure.invalid(offset + 1) }
        }
    }
}
