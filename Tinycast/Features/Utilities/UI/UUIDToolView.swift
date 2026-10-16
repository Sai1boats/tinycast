import SwiftUI

struct UUIDToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    @Environment(DeveloperToolSession.self) private var session

    var body: some View {
        @Bindable var session = session
        UtilityToolLayout(error: session.error) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                HStack(spacing: Theme.Spacing.xl) {
                    Text("Count").foregroundStyle(Theme.Colors.textSecondary)
                    TextField("Count", value: $session.uuidCount, format: .number.grouping(.never))
                        .textFieldStyle(.roundedBorder).frame(width: Theme.Size.utilityCountWidth)
                    Stepper("Count", value: $session.uuidCount, in: 1...UUIDGenerator.maximumCount).labelsHidden()
                    Toggle("Uppercase", isOn: $session.uppercaseUUID).toggleStyle(.checkbox)
                    Toggle("Include Hyphens", isOn: $session.hyphenatedUUID).toggleStyle(.checkbox)
                }
                UtilityEditorPane(title: "UUIDs", text: .constant(session.output), editable: false, detail: "v4")
            }
        } operations: {
            Button("Generate UUIDs") { coordinator.generateUUIDs() }
                .keyboardShortcut(.return, modifiers: .command)
        } actions: {
            Button("Copy Result") { coordinator.copy(session.output) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(session.output.isEmpty)
        } status: {
            Text("Random version 4 UUIDs, one per line.")
        }
    }
}
