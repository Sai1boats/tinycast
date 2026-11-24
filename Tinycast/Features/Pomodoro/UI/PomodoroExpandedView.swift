import SwiftUI

/// The expanded face: the full mini console — title, countdown, task, stats and actions.
struct PomodoroExpandedView: View {
    @Environment(PomodoroCoordinator.self) private var coordinator
    @State private var hoveringClose = false
    @State private var hoveringHide = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, Theme.Spacing.xl)
            Text(coordinator.remainingText)
                .font(Theme.Typography.pomodoroTime)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
                .allowsHitTesting(false)
                .accessibilityLabel(Text(coordinator.titleText))
            Text(captionText)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.top, Theme.Spacing.sm)
                .allowsHitTesting(false)
            PomodoroRail(
                progress: coordinator.progress, tint: coordinator.state.phase.tint, height: 3)
            .padding(.top, Theme.Spacing.xl)
            .allowsHitTesting(false)
            timesRow
                .padding(.top, Theme.Spacing.md)
            taskField
                .padding(.top, Theme.Spacing.xl)
            statsRow
                .padding(.top, Theme.Spacing.xl)
            actions
                .padding(.top, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.dialogInset)
        .frame(
            width: Theme.Size.pomodoroExpanded.width,
            height: Theme.Size.pomodoroExpanded.height)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Text(coordinator.titleText)
                .font(Theme.Typography.pomodoroTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .allowsHitTesting(false)
            Spacer()
            headerButton("eye.slash", label: "Hide", hovering: $hoveringHide) {
                coordinator.hideWidget()
            }
            headerButton("xmark", label: "Close", hovering: $hoveringClose) {
                coordinator.collapseWidget()
            }
        }
    }

    private func headerButton(
        _ name: String, label: LocalizedStringKey, hovering: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SymbolImage(name: name, size: 12, monochrome: true)
                .foregroundStyle(Theme.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    hovering.wrappedValue ? Theme.Colors.controlHover : Color.clear,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.barControl, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering.wrappedValue = $0 }
        .accessibilityLabel(Text(label))
    }

    private var timesRow: some View {
        HStack {
            Text(String(localized: "Focused \(coordinator.elapsedText)"))
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
            Spacer()
            Text(endText)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .allowsHitTesting(false)
    }

    private var taskField: some View {
        HStack(spacing: Theme.Spacing.md) {
            SymbolImage(name: "checklist", size: 12, monochrome: true)
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("Task")
                .font(.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
            TextField(
                "",
                text: Binding(
                    get: { coordinator.state.taskName },
                    set: { coordinator.setTaskName($0) }),
                prompt: Text("Add a task")
            )
            .textFieldStyle(.plain)
            .font(.callout)
            .foregroundStyle(Theme.Colors.textPrimary)
            if coordinator.activeTaskID != nil || !coordinator.state.taskName.isEmpty {
                Button {
                    coordinator.unbindTask()
                } label: {
                    SymbolImage(name: "xmark.circle.fill", size: 12, monochrome: true)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Clear task")
                .accessibilityLabel("Clear task")
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .frame(height: 36)
        .background(Theme.Colors.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
    }

    private var statsRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            stat(value: "\(coordinator.stats.completedFocusCount)", label: "Pomodoros today")
            stat(
                value: PomodoroTimeText.hoursMinutes(
                    TimeInterval(coordinator.stats.focusSeconds)),
                label: "Focused today")
            stat(value: durationsText, label: "Durations")
        }
        .allowsHitTesting(false)
    }

    private var durationsText: String {
        "\(coordinator.configuration.focusMinutes) · \(coordinator.configuration.shortBreakMinutes)"
    }

    private var actions: some View {
        HStack(spacing: Theme.Spacing.sm) {
            action(
                name: coordinator.primaryActionSymbol,
                label: coordinator.primaryActionLabel,
                primary: true
            ) {
                coordinator.toggleRunning()
            }
            action(label: String(localized: "Skip")) {
                coordinator.skip()
            }
            action(label: String(localized: "Reset")) {
                coordinator.reset()
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.controlSurface)
        .clipShape(
            RoundedRectangle(cornerRadius: Theme.Radius.utilityActions, style: .continuous))
    }

    private var captionText: String {
        let minutes = Int(coordinator.configuration.duration(of: coordinator.state.phase) / 60)
        return String(localized: "Remaining · \(minutes) min total")
    }

    private var endText: String {
        if let endsAt = coordinator.state.endsAt {
            let time = endsAt.formatted(date: .omitted, time: .shortened)
            return String(localized: "Ends \(time)")
        }
        return coordinator.progress == 0
            ? String(localized: "Not started") : String(localized: "Paused")
    }

    private func stat(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text(value)
                .font(Theme.Typography.pomodoroStatValue)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Colors.controlSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
    }

    private func action(
        name: String? = nil, label: String, primary: Bool = false, run: @escaping () -> Void
    ) -> some View {
        Button(action: run) {
            HStack(spacing: Theme.Spacing.sm) {
                if let name {
                    SymbolImage(name: name, size: 10, monochrome: true)
                }
                Text(verbatim: label)
                    .font(.callout.weight(.semibold))
            }
            .foregroundStyle(
                primary ? Theme.Colors.composerSendInk : Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(primary ? Theme.Colors.textPrimary : Color.clear)
            .clipShape(
                RoundedRectangle(cornerRadius: Theme.Radius.formField, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: label))
    }
}
