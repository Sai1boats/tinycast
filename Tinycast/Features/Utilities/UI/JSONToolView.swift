import SwiftUI

struct JSONToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            HStack(spacing: Theme.Spacing.md) {
                Button("Format JSON") { coordinator.runJSON(.format) }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Compress JSON") { coordinator.runJSON(.compact) }
                Button("Unescape Once") { coordinator.runJSON(.unescape) }
                Spacer()
                if coordinator.jsonBusy { ProgressView().controlSize(.small) }
                Button("Read Clipboard", action: coordinator.readJSONClipboard)
            }
            .buttonStyle(.modalAction(.standard, fillsWidth: false))
            HSplitView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Input").font(.headline)
                    UtilityTextEditor(text: $coordinator.jsonInput, editable: true, label: String(localized: "JSON Input"))
                        .background(Theme.Colors.cardFill,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
                .padding(.trailing, Theme.Spacing.xl)
                .frame(minWidth: Theme.Size.utilityEditorMinimum)
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Result").font(.headline)
                    UtilityTextEditor(
                        text: .constant(coordinator.jsonOutput), editable: false, label: String(localized: "JSON Result"))
                        .background(Theme.Colors.cardFill,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
                .padding(.leading, Theme.Spacing.xl)
                .frame(minWidth: Theme.Size.utilityEditorMinimum)
            }
            if !coordinator.jsonError.isEmpty {
                Text(coordinator.jsonError).foregroundStyle(Theme.Colors.destructive).textSelection(.enabled)
            }
            HStack {
                Text("Unescape removes one JSON string-encoding layer. Numbers and key order are preserved.")
                    .font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Button("Use Result as Input") { coordinator.jsonInput = coordinator.jsonOutput }
                    .disabled(coordinator.jsonOutput.isEmpty)
                Button("Copy Result") { coordinator.copy(coordinator.jsonOutput) }
                    .keyboardShortcut("c", modifiers: [.command, .shift])
                    .disabled(coordinator.jsonOutput.isEmpty)
            }
            .buttonStyle(.modalAction(.standard, fillsWidth: false))
        }
    }
}
