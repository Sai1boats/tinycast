import SwiftUI

/// The phase chip: a tinted dot and the phase name, the only place the hue leads.
struct PomodoroBadge: View {
    var phase: PomodoroPhase

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(phase.tint)
                .frame(width: 7, height: 7)
            Text(phase.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs + Theme.Spacing.xxs)
        .background(Theme.Colors.controlSurface, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
