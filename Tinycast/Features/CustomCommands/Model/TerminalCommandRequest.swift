import Foundation

struct TerminalCommandRequest: Sendable {
    let command: String
    let homeDirectory: String

    var input: String {
        let directory = "'" + homeDirectory.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "cd -- \(directory) && \(command)"
    }

    var itermURL: URL? {
        var components = URLComponents()
        components.scheme = "iterm2"
        components.path = "/command"
        components.queryItems = [
            URLQueryItem(name: "c", value: command),
            URLQueryItem(name: "d", value: homeDirectory)
        ]
        return components.url
    }

    static func script(for destination: ShellCommandDestination) -> String? {
        switch destination {
        case .tinycast, .iterm: nil
        case .terminal:
            """
            on run arguments
                set commandText to item 1 of arguments
                tell application id "com.apple.Terminal"
                    do script commandText
                    activate
                end tell
            end run
            """
        case .cmux:
            """
            on run arguments
                set commandText to item 1 of arguments
                tell application id "com.cmuxterm.app"
                    set commandWindow to new window
                    set commandTerminal to focused terminal of selected tab of commandWindow
                    input text commandText to commandTerminal
                    if not (perform action ("text:" & (ASCII character 92) & "x0d") on commandTerminal) then error number -2701
                    activate window commandWindow
                end tell
            end run
            """
        }
    }
}
