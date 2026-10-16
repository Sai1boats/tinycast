import Foundation

/// The three surfaces stay reachable one way, and chat is skipped when off.
@main
@MainActor
struct PaletteTabTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ actual: PaletteTabAction, _ expected: PaletteTabAction, _ message: String) {
        if actual == expected {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message) — got \(actual), want \(expected)")
        }
    }

    static func main() {
        expect(
            PaletteTabAction.resolve(mode: .launcher, destination: .automatic, enabled: [.ai, .clipboard]),
            .ask,
            "the launcher hands the typed text to chat as the question, not as a draft")
        expect(
            PaletteTabAction.resolve(mode: .ai, destination: .automatic, enabled: [.ai, .clipboard]),
            .freshScreen(.clipboard),
            "chat hands on to the clipboard without carrying the unsent draft into the filter")
        expect(
            PaletteTabAction.resolve(mode: .clipboard, destination: .automatic, enabled: [.ai, .clipboard]),
            .carryQuery(.launcher),
            "the clipboard closes the ring, and one search narrows both lists")

        // Off, chat has no launcher command and no hotkey; the ring must not strand a reader there.
        expect(
            PaletteTabAction.resolve(mode: .launcher, destination: .automatic, enabled: [.clipboard]),
            .carryQuery(.clipboard),
            "turned off, chat is skipped and the launcher flips straight to the clipboard")
        expect(
            PaletteTabAction.resolve(mode: .clipboard, destination: .automatic, enabled: [.clipboard]),
            .carryQuery(.launcher),
            "turned off, the clipboard still returns to the launcher")

        // A sub-screen is reached by a command or a hotkey, so Tab leaves rather than ringing on.
        for mode in [
            PaletteMode.aiHistory, .emoji, .fileSearch, .calculatorHistory, .quicklinks, .snippets,
            .customCommands
        ] {
            expect(
                PaletteTabAction.resolve(mode: mode, destination: .automatic, enabled: [.ai, .clipboard]),
                .carryQuery(.launcher),
                "\(mode.rawValue) is a sub-screen, so Tab exits to the launcher")
        }

        expect(
            PaletteTabAction.resolve(
                mode: .extensionCommand, destination: .automatic, enabled: [.ai, .clipboard]),
            .carryQuery(.launcher),
            "an extension command exits to the launcher rather than joining the ring")

        // Both stops off, so Tab has nowhere to ring on to and must leave the launcher standing.
        expect(
            PaletteTabAction.resolve(
                mode: .launcher, destination: .automatic, enabled: []),
            .carryQuery(.launcher),
            "with the clipboard off too, the launcher rings back onto itself")
        expect(
            PaletteTabAction.resolve(mode: .ai, destination: .automatic, enabled: [.ai]),
            .carryQuery(.launcher),
            "turned off, the clipboard is skipped and chat returns to the launcher")

        for destination in LauncherTabDestination.allCases where destination != .automatic {
            expect(
                PaletteTabAction.resolve(mode: .launcher, destination: destination, enabled: []),
                .carryQuery(.launcher), "a disabled destination never opens: \(destination)")
            expect(
                PaletteTabAction.resolve(mode: .clipboard, destination: destination,
                    enabled: Set(LauncherTabDestination.allCases)),
                .carryQuery(.launcher), "a configured page returns to root search")
        }
        let destinations: [(LauncherTabDestination, PaletteTabAction)] = [
            (.none, .carryQuery(.launcher)), (.clipboard, .freshScreen(.clipboard)),
            (.ai, .ask), (.fileSearch, .carryQuery(.fileSearch)), (.emoji, .carryQuery(.emoji)),
            (.calculatorHistory, .carryQuery(.calculatorHistory)), (.quicklinks, .carryQuery(.quicklinks)),
            (.snippets, .carryQuery(.snippets)), (.customCommands, .carryQuery(.customCommands)),
            (.dictionary, .carryQuery(.dictionary))
        ]
        for (destination, expected) in destinations {
            expect(
                PaletteTabAction.resolve(mode: .launcher, destination: destination, enabled: [destination]),
                expected, "configured destination opens directly: \(destination)")
        }

        // Three presses from the launcher have to land back on it, or the ring is a dead end.
        var mode = PaletteMode.launcher
        var visited: [PaletteMode] = []
        for _ in 0..<3 {
            switch PaletteTabAction.resolve(mode: mode, destination: .automatic, enabled: [.ai, .clipboard]) {
            case .carryQuery(let next), .freshScreen(let next): mode = next
            // Asking opens chat, so the ring still steps onto it.
            case .ask: mode = .ai
            }
            visited.append(mode)
        }
        if visited == [.ai, .clipboard, .launcher] {
            passes += 1
        } else {
            failures += 1
            print("FAIL: three presses ring back to the launcher — got \(visited)")
        }

        var offMode = PaletteMode.launcher
        var offVisited: [PaletteMode] = []
        for _ in 0..<2 {
            switch PaletteTabAction.resolve(
                mode: offMode, destination: .automatic, enabled: [.clipboard])
            {
            case .carryQuery(let next), .freshScreen(let next): offMode = next
            case .ask: offMode = .ai
            }
            offVisited.append(offMode)
        }
        if offVisited == [.clipboard, .launcher] {
            passes += 1
        } else {
            failures += 1
            print("FAIL: turned off, two presses ring back to the launcher — got \(offVisited)")
        }

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
