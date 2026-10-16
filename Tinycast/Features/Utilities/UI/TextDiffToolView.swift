import SwiftUI

struct TextDiffToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    @Environment(DeveloperToolSession.self) private var session

    var body: some View {
        @Bindable var session = session
        UtilityToolLayout(error: session.error, isBusy: session.isBusy) {
            VSplitView {
                HSplitView {
                    UtilityEditorPane(title: "Original Text", text: $session.input, editable: true)
                        .frame(minWidth: Theme.Size.utilityEditorMinimum)
                        .padding(.trailing, Theme.Spacing.sm)
                    UtilityEditorPane(title: "Modified Text", text: $session.comparisonInput, editable: true)
                        .frame(minWidth: Theme.Size.utilityEditorMinimum)
                        .padding(.leading, Theme.Spacing.sm)
                }
                .frame(minHeight: Theme.Size.utilityDiffPaneMinimum)
                .padding(.bottom, Theme.Spacing.sm)
                UtilityEditorPane(title: "Differences", text: .constant(session.output), editable: false, showsDiff: true)
                    .frame(minHeight: Theme.Size.utilityDiffPaneMinimum)
                    .padding(.top, Theme.Spacing.sm)
            }
        } operations: {
            Button("Compare Text") { coordinator.compareText() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Swap Texts") { coordinator.swapComparisonTexts() }
        } actions: {
            Button("Read Original") { coordinator.readClipboard(into: session) }
            Button("Read Modified") { coordinator.readClipboard(into: session, comparison: true) }
            Button("Copy Diff") { coordinator.copy(session.output) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(session.output.isEmpty)
        } status: {
            if let result = session.comparison {
                if result.isIdentical {
                    Text("The texts are identical.")
                } else {
                    Text("\(result.insertedCount) added, \(result.deletedCount) removed")
                }
            } else {
                Text("Compare exact lines, including whitespace and line endings.")
            }
        }
    }
}
