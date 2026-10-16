import SwiftUI

struct JSONToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        UtilityToolLayout(error: coordinator.jsonError, isBusy: coordinator.jsonBusy, suggestionTool: .json) {
            VSplitView {
                UtilityEditorPane(title: "Input", text: $coordinator.jsonInput, editable: true,
                                  label: String(localized: "JSON Input"), detail: "JSON")
                    .padding(.bottom, Theme.Spacing.sm)
                UtilityEditorPane(title: "Result", text: .constant(coordinator.jsonOutput), editable: false,
                                  label: String(localized: "JSON Result"), detail: "JSON")
                    .padding(.top, Theme.Spacing.sm)
            }
        } operations: {
            Button("Format JSON") { coordinator.runJSON(.format) }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Compress JSON") { coordinator.runJSON(.compact) }
            Button("Unescape Once") { coordinator.runJSON(.unescape) }
        } actions: {
            Button("Read Clipboard", action: coordinator.readJSONClipboard)
            Button("Use Result as Input") { coordinator.jsonInput = coordinator.jsonOutput }
                .disabled(coordinator.jsonOutput.isEmpty)
            Button("Copy Result") { coordinator.copy(coordinator.jsonOutput) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(coordinator.jsonOutput.isEmpty)
        } status: {
            Text("Unescape removes one JSON string-encoding layer. Numbers and key order are preserved.")
        }
    }
}
