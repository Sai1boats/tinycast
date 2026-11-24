import SwiftUI

struct PomodoroSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section {
                Toggle(isOn: $settings.pomodoroEnabled) {
                    SettingsFeatureToggleLabel(
                        anchor: .pomodoroPomodoro, title: "Enable Pomodoro",
                        subtitle: enableSubtitle)
                }
            }
            .settingsAnchor(.pomodoroPomodoro)

            Section {
                LabeledContent {
                    minutesStepper(
                        value: $settings.pomodoroFocusMinutes,
                        range: PomodoroConfiguration.focusRange,
                        label: "Focus")
                } label: {
                    SettingsRowTitle(.pomodoroDurations, "Focus")
                    Text("One pomodoro in minutes.")
                }
                LabeledContent {
                    minutesStepper(
                        value: $settings.pomodoroShortBreakMinutes,
                        range: PomodoroConfiguration.breakRange,
                        label: "Short Break")
                } label: {
                    SettingsRowTitle(.pomodoroDurations, "Short Break")
                    Text("After each pomodoro.")
                }
                LabeledContent {
                    minutesStepper(
                        value: $settings.pomodoroLongBreakMinutes,
                        range: PomodoroConfiguration.breakRange,
                        label: "Long Break")
                } label: {
                    SettingsRowTitle(.pomodoroDurations, "Long Break")
                    Text("After a full cycle.")
                }
                LabeledContent {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("\(settings.pomodoroLongBreakEvery)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Stepper(
                            "Pomodoros per cycle", value: $settings.pomodoroLongBreakEvery,
                            in: PomodoroConfiguration.cycleRange)
                            .labelsHidden()
                    }
                } label: {
                    SettingsRowTitle(.pomodoroDurations, "Pomodoros per cycle")
                    Text("Focus sessions before a long break.")
                }
            } header: {
                SettingsSectionHeader(.pomodoroDurations)
            }
            .settingsEnabled(settings.pomodoroEnabled)

            FeatureCommandsSection(owner: .pomodoro, anchor: .pomodoroCommands)
                .settingsEnabled(settings.pomodoroEnabled)
        }
        .formStyle(.grouped)
        .settingsScrollTarget(.pomodoro)
    }

    private var enableSubtitle: LocalizedStringResource {
        "A desktop widget with an always-on-top countdown."
    }

    private func minutesStepper(
        value: Binding<Int>, range: ClosedRange<Int>, label: LocalizedStringKey
    ) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("\(value.wrappedValue) min")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper(label, value: value, in: range)
                .labelsHidden()
        }
    }
}
