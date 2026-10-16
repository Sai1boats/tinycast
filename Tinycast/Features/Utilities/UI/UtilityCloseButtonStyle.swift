import SwiftUI

struct UtilityCloseButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CloseBody(configuration: configuration)
    }

    private struct CloseBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovered = false

        var body: some View {
            configuration.label
                .foregroundStyle(hovered ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .frame(width: Theme.Size.barButtonHeight, height: Theme.Size.barButtonHeight)
                .background(fill, in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous))
                .onHover { hovered = $0 }
        }

        private var fill: Color {
            if configuration.isPressed { return Theme.Colors.controlPressed }
            return hovered ? Theme.Colors.controlHover : .clear
        }
    }
}
