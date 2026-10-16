import SwiftUI

struct UtilityToolLayout<Content: View, Operations: View, Actions: View, Status: View>: View {
    var error = ""
    var isBusy = false
    var suggestionTool: UtilityTool?
    @ViewBuilder let content: Content
    @ViewBuilder let operations: Operations
    @ViewBuilder let actions: Actions
    @ViewBuilder let status: Status

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            if let suggestionTool { UtilityClipboardBanner(tool: suggestionTool) }
            if !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.destructive)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            UtilityActionBar { operations } actions: { actions }
            HStack(spacing: Theme.Spacing.md) {
                if isBusy { ProgressView().controlSize(.mini) }
                status
            }
            .font(.caption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("utility-status")
        }
    }
}
