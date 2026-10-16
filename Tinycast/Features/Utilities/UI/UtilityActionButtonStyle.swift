import SwiftUI

struct UtilityActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ActionBody(configuration: configuration)
    }

    private struct ActionBody: View {
        @Environment(\.isEnabled) private var isEnabled
        let configuration: ButtonStyleConfiguration
        @State private var hovered = false

        var body: some View {
            configuration.label
                .font(Theme.Typography.bar)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.horizontal, Theme.Spacing.xl)
                .frame(height: Theme.Size.dialogButtonHeight)
                .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { hovered = $0 }
        }

        private var fill: Color {
            if configuration.isPressed { return Theme.Colors.controlPressed }
            return hovered ? Theme.Colors.controlHover : .clear
        }
    }
}

extension ButtonStyle where Self == UtilityActionButtonStyle {
    static var utilityAction: UtilityActionButtonStyle { UtilityActionButtonStyle() }
}
