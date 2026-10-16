import SwiftUI

struct JWTToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    @Environment(DeveloperToolSession.self) private var session

    private var timeStatus: String {
        switch session.jwt?.timeStatus {
        case .expired: String(localized: "Expired according to exp")
        case .notYetActive: String(localized: "Not yet active according to nbf")
        case .withinWindow: String(localized: "Within the claimed time window")
        case .unspecified, nil: ""
        }
    }

    var body: some View {
        @Bindable var session = session
        UtilityToolLayout(error: session.error, isBusy: session.isBusy) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                UtilityEditorPane(title: "Token", text: $session.input, editable: true, detail: "JWT")
                    .frame(height: Theme.Size.utilityFocusTokenHeight)
                HSplitView {
                    UtilityEditorPane(title: "JWT Header", text: .constant(session.jwt?.header ?? ""),
                                      editable: false, detail: "JSON")
                        .frame(minWidth: Theme.Size.utilityEditorMinimum)
                        .padding(.trailing, Theme.Spacing.sm)
                    UtilityEditorPane(title: "Payload", text: .constant(session.jwt?.payload ?? ""),
                                      editable: false, detail: "JSON")
                        .frame(minWidth: Theme.Size.utilityEditorMinimum)
                        .padding(.leading, Theme.Spacing.sm)
                }
                if let result = session.jwt, !result.claims.isEmpty {
                    HStack(alignment: .top, spacing: Theme.Spacing.xxl) {
                        ForEach(result.claims, id: \.name) { claim in
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text(claim.name).font(Theme.Typography.utilityPaneTitle)
                                Text(claim.date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
                                    .font(.caption).monospaced().textSelection(.enabled)
                            }
                        }
                    }
                    .foregroundStyle(Theme.Colors.textSecondary)
                }
            }
        } operations: {
            Button("Inspect JWT") { coordinator.inspectJWT() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Read Clipboard") { coordinator.readClipboard(into: session) }
        } actions: {
            Button("Copy Header") { coordinator.copy(session.jwt?.header ?? "") }
                .disabled(session.jwt == nil)
            Button("Copy Payload") { coordinator.copy(session.jwt?.payload ?? "") }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(session.jwt == nil)
            Button("Copy Signature") { coordinator.copy(session.jwt?.signature ?? "") }
                .disabled(session.jwt?.signature.isEmpty != false)
        } status: {
            VStack(spacing: Theme.Spacing.xxs) {
                Text("Contents only. Signature has not been verified.")
                if !timeStatus.isEmpty { Text(timeStatus) }
            }
        }
    }
}
