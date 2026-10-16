import SwiftUI

struct HashToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    @Environment(DeveloperToolSession.self) private var session

    var body: some View {
        @Bindable var session = session
        UtilityToolLayout(error: session.error, isBusy: session.isBusy) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Picker("Algorithm", selection: $session.hashAlgorithm) {
                    ForEach(TextHash.Algorithm.allCases, id: \.self) { algorithm in
                        Text(algorithm.title).tag(algorithm)
                    }
                }.fixedSize()
                UtilityEditorPane(title: "Input", text: $session.input, editable: true, detail: "UTF-8")
                UtilityEditorPane(title: "Digest", text: .constant(session.output), editable: false,
                                  detail: session.hashAlgorithm.title)
                    .frame(height: Theme.Size.utilityFocusDigestHeight)
            }
        } operations: {
            Button("Compute Hash") { coordinator.computeHash() }
                .keyboardShortcut(.return, modifiers: .command)
        } actions: {
            Button("Read Clipboard") { coordinator.readClipboard(into: session) }
            Button("Copy Result") { coordinator.copy(session.output) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(session.output.isEmpty)
        } status: {
            Text("Hashes the exact UTF-8 text, including spaces and line endings.")
        }
    }
}
