import SwiftUI

struct EncodingToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    @Environment(DeveloperToolSession.self) private var session
    let tool: UtilityTool

    private var explanation: String {
        tool == .urlCodec
            ? String(localized: "Encode a value, not a whole URL. Form mode uses + for spaces.")
            : String(localized: "UTF-8 text. Base64url uses - and _ and omits padding when encoding.")
    }

    var body: some View {
        @Bindable var session = session
        UtilityToolLayout(error: session.error, isBusy: session.isBusy) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if tool == .urlCodec {
                    Picker("Encoding Mode", selection: $session.urlMode) {
                        ForEach(URLCodec.Mode.allCases, id: \.self) { mode in
                            Text(NSLocalizedString(mode.title, comment: "URL encoding mode")).tag(mode)
                        }
                    }.fixedSize()
                } else {
                    Picker("Alphabet", selection: $session.base64Alphabet) {
                        ForEach(Base64Codec.Alphabet.allCases, id: \.self) { alphabet in
                            Text(NSLocalizedString(alphabet.title, comment: "Base64 alphabet")).tag(alphabet)
                        }
                    }.fixedSize()
                }
                VSplitView {
                    UtilityEditorPane(title: "Input", text: $session.input, editable: true, detail: "UTF-8")
                        .padding(.bottom, Theme.Spacing.sm)
                    UtilityEditorPane(title: "Result", text: .constant(session.output), editable: false)
                        .padding(.top, Theme.Spacing.sm)
                }
            }
        } operations: {
            Button("Encode") { coordinator.runEncoding(tool, decoding: false) }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Decode") { coordinator.runEncoding(tool, decoding: true) }
        } actions: {
            Button("Read Clipboard") { coordinator.readClipboard(into: session) }
            Button("Use Result as Input") { session.input = session.output }
                .disabled(session.output.isEmpty)
            Button("Copy Result") { coordinator.copy(session.output) }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(session.output.isEmpty)
        } status: {
            Text(explanation)
        }
    }
}
