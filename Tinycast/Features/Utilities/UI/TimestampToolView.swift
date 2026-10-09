import SwiftUI

struct TimestampToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    private var zones: [String] {
        Set([TimeZone.current.identifier, "UTC", "Asia/Shanghai", "Asia/Tokyo", "Asia/Kolkata",
             "America/New_York", "America/Los_Angeles", "Europe/London", "Europe/Berlin", "Australia/Sydney"]).sorted()
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
            HStack {
                Picker("Time Zone", selection: $coordinator.timeZoneID) {
                    ForEach(zones, id: \.self) { Text($0).tag($0) }
                }
                Spacer()
                Button("Use Current Time", action: coordinator.useNow)
                    .buttonStyle(.modalAction(.standard, fillsWidth: false))
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Timestamp → Date").font(.headline)
                HStack {
                    TextField("Unix timestamp", text: $coordinator.timestampInput)
                        .textFieldStyle(.plain)
                        .font(.title3.monospacedDigit())
                        .padding(.vertical, Theme.Spacing.md)
                        .onSubmit { coordinator.convertTimestamp(fromDate: false) }
                    Picker("Unit", selection: $coordinator.timestampUnit) {
                        Text("Auto Detect").tag(TimestampConverter.Unit.automatic)
                        Text("Seconds").tag(TimestampConverter.Unit.seconds)
                        Text("Milliseconds").tag(TimestampConverter.Unit.milliseconds)
                    }
                    .fixedSize()
                    Button("Convert") { coordinator.convertTimestamp(fromDate: false) }
                        .buttonStyle(.modalAction(.primary, fillsWidth: false))
                }
                Text("Auto detects milliseconds at magnitude ≥ 100000000000; choose a unit for smaller values.")
                    .font(.caption).foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.cardFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("Date → Timestamp").font(.headline)
                HStack {
                    TextField("yyyy-MM-dd HH:mm:ss.SSS", text: $coordinator.dateInput)
                        .textFieldStyle(.plain)
                        .font(.title3.monospacedDigit())
                        .padding(.vertical, Theme.Spacing.md)
                        .onSubmit { coordinator.convertTimestamp(fromDate: true) }
                    Button("Convert") { coordinator.convertTimestamp(fromDate: true) }
                        .buttonStyle(.modalAction(.primary, fillsWidth: false))
                }
            }
            .padding(Theme.Spacing.xl)
            .background(Theme.Colors.cardFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            if let result = coordinator.timestampResult {
                VStack(spacing: Theme.Spacing.md) {
                    UtilityResultRow(title: "Date in Selected Zone", value: result.localDate)
                    UtilityResultRow(title: "UTC Date", value: result.utcDate)
                    UtilityResultRow(title: "Seconds", value: result.seconds)
                    UtilityResultRow(title: "Milliseconds", value: result.milliseconds)
                }
                .padding(Theme.Spacing.xl)
                .background(Theme.Colors.cardFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }
            if !coordinator.timestampError.isEmpty {
                Text(coordinator.timestampError).foregroundStyle(Theme.Colors.destructive)
            }
            }
        }
        .overflowFade(includingTop: true)
    }
}
