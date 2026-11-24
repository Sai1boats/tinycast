import SwiftUI

/// The resting face: badge, countdown, today's count, and one hairline of progress.
struct PomodoroCollapsedView: View {
    @Environment(PomodoroCoordinator.self) private var coordinator
    @State private var hovering = false

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.lg) {
                PomodoroBadge(phase: coordinator.state.phase)
                    .allowsHitTesting(false)
                Text(coordinator.remainingText)
                    .font(Theme.Typography.pomodoroCompactTime)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .monospacedDigit()
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                if hovering {
                    controls
                } else {
                    Text("\(coordinator.stats.completedFocusCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .monospacedDigit()
                        .allowsHitTesting(false)
                        .accessibilityLabel(Text("Pomodoros today"))
                }
            }
            PomodoroRail(progress: coordinator.progress, tint: coordinator.state.phase.tint)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, Theme.Spacing.xl + Theme.Spacing.xxs)
        .padding(.vertical, Theme.Spacing.lg)
        .frame(
            width: Theme.Size.pomodoroCollapsed.width,
            height: Theme.Size.pomodoroCollapsed.height)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(coordinator.titleText))
    }

    private var controls: some View {
        HStack(spacing: Theme.Spacing.xs) {
            PomodoroIconButton(
                name: coordinator.primaryActionSymbol, label: coordinator.primaryActionLabel
            ) {
                coordinator.toggleRunning()
            }
            PomodoroIconButton(name: "forward.fill", label: String(localized: "Skip")) {
                coordinator.skip()
            }
        }
        .padding(Theme.Spacing.xxs)
        .background(Theme.Colors.controlSurface, in: Capsule())
    }
}
