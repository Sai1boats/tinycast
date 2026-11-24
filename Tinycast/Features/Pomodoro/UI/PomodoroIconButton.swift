import SwiftUI

/// A glass pill glyph button; every one carries its own label.
struct PomodoroIconButton: View {
    var name: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            SymbolImage(name: name, size: 10, monochrome: true)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: label))
    }
}
