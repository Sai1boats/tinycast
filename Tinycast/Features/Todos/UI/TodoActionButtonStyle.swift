import SwiftUI

struct TodoActionButtonStyle: ButtonStyle {
    var isPrimary = false
    var isIconOnly = false

    func makeBody(configuration: Configuration) -> some View {
        ActionBody(configuration: configuration, isPrimary: isPrimary, isIconOnly: isIconOnly)
    }

    private struct ActionBody: View {
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovered = false
        let configuration: ButtonStyleConfiguration
        let isPrimary: Bool
        let isIconOnly: Bool

        var body: some View {
            configuration.label
                .font(Theme.Typography.todosControl)
                .foregroundStyle(isPrimary ? Theme.Colors.todosActionInk : Theme.Colors.textPrimary)
                .padding(.horizontal, isIconOnly ? 0 : Theme.Spacing.xl)
                .frame(width: isIconOnly ? Theme.Size.todosActionHeight : nil,
                       height: Theme.Size.todosActionHeight)
                .contentShape(Capsule())
                .background(Capsule().fill(fill))
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { hovered = $0 }
        }

        private var fill: Color {
            if isPrimary {
                return Theme.Colors.textPrimary.opacity(configuration.isPressed ? 0.8 : 1)
            }
            if configuration.isPressed { return Theme.Colors.controlPressed }
            return hovered ? Theme.Colors.controlHover : Theme.Colors.controlSurface
        }
    }
}
