import Foundation

/// The lines the ad-hoc shell answers itself, because a child process cannot move its parent.
enum ShellBuiltin: Equatable, Sendable {
    /// Nil means home, as a bare `cd` does in every shell.
    case changeDirectory(String?)
    case changeToFinderFolder

    /// Only a lone `cd`: with `;`, `&&` or a pipe the line is real shell and runs as typed.
    init?(_ command: String) {
        let line = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if line == "cdf" {
            self = .changeToFinderFolder
            return
        }
        guard line == "cd" || line.hasPrefix("cd ") else { return nil }
        let argument = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        guard let word = ShellWords.single(argument) else { return nil }
        self = .changeDirectory(word.isEmpty ? nil : word)
    }
}

enum ShellWords {
    static let specialCharacters = Set(" \t\\'\"$`!&|;<>()*?[]{}#~=%")

    /// One word with its quoting removed, or nil when the text holds anything a shell would expand.
    static func single(_ text: String) -> String? {
        var word = ""
        var quote: Character?
        var escaped = false
        for character in text {
            if escaped {
                word.append(character)
                escaped = false
            } else if let open = quote {
                if character == open { quote = nil } else { word.append(character) }
            } else if character == "\\" {
                escaped = true
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character.isWhitespace || "$`;&|<>()*?{}".contains(character) {
                return nil
            } else {
                word.append(character)
            }
        }
        return quote == nil && !escaped ? word : nil
    }

    /// Backslash-escapes a file name so the completed line means that exact file.
    static func escaped(_ name: String) -> String {
        name.reduce(into: "") { result, character in
            if specialCharacters.contains(character) { result.append("\\") }
            result.append(character)
        }
    }

    /// The word the cursor sits on at the end of the line, and everything typed before it.
    static func lastWord(of line: String) -> (prefix: String, word: String) {
        var index = line.endIndex
        while index > line.startIndex {
            let previous = line.index(before: index)
            guard line[previous].isWhitespace else {
                index = previous
                continue
            }
            if previous > line.startIndex, line[line.index(before: previous)] == "\\" {
                index = line.index(before: previous)
                continue
            }
            break
        }
        return (String(line[..<index]), String(line[index...]))
    }

    /// A completed word is typed with escapes; matching compares the name it spells.
    static func unescaped(_ word: String) -> String {
        var result = ""
        var escaped = false
        for character in word {
            if escaped || character != "\\" {
                result.append(character)
                escaped = false
            } else {
                escaped = true
            }
        }
        return result
    }
}

enum ShellPath {
    /// The folder a `cd` argument names, before anyone checks that it exists.
    static func resolve(_ argument: String?, from directory: String, previous: String?, home: String) -> String? {
        guard let argument, !argument.isEmpty, argument != "~" else { return home }
        if argument == "-" { return previous }
        let expanded: String
        if argument.hasPrefix("~/") {
            expanded = home + argument.dropFirst()
        } else if argument.hasPrefix("/") {
            expanded = argument
        } else {
            expanded = directory + "/" + argument
        }
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }

    /// `~` for the home folder, so the header reads the way a prompt does.
    static func abbreviated(_ path: String, home: String) -> String {
        if path == home { return "~" }
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}
