import SwiftUI

struct TimestampToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    private var zones: [String] {
        Set([TimeZone.current.identifier, "UTC", "Asia/Shanghai", "Asia/Tokyo", "Asia/Kolkata",
             "America/New_York", "America/Los_Angeles", "Europe/London", "Europe/Berlin", "Australia/Sydney"]).sorted()
    }

    var body: some View {
        @Bindable var coordinator = coordinator
        UtilityToolLayout(error: coordinator.timestampError) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    Picker("Time Zone", selection: $coordinator.timeZoneID) {
                        ForEach(zones, id: \.self) { Text($0).tag($0) }
                    }.fixedSize()
                    UtilityCard(title: Text("Timestamp → Date")) {
                        HStack(spacing: Theme.Spacing.xl) {
                            TextField("Unix timestamp", text: $coordinator.timestampInput)
                                .textFieldStyle(.plain)
                                .font(Theme.Typography.code)
                                .frame(minHeight: Theme.Size.dialogButtonHeight)
                                .onSubmit { coordinator.convertTimestamp(fromDate: false) }
                                .accessibilityLabel(String(localized: "Unix timestamp"))
                            Picker("Unit", selection: $coordinator.timestampUnit) {
                                Text("Auto Detect").tag(TimestampConverter.Unit.automatic)
                                Text("Seconds").tag(TimestampConverter.Unit.seconds)
                                Text("Milliseconds").tag(TimestampConverter.Unit.milliseconds)
                            }.fixedSize()
                        }
                    }
                    UtilityCard(title: Text("Date → Timestamp")) {
                        TextField("yyyy-MM-dd HH:mm:ss.SSS", text: $coordinator.dateInput)
                            .textFieldStyle(.plain)
                            .font(Theme.Typography.code)
                            .frame(minHeight: Theme.Size.dialogButtonHeight)
                            .onSubmit { coordinator.convertTimestamp(fromDate: true) }
                            .accessibilityLabel(String(localized: "Date → Timestamp"))
                    }
                    UtilityCard(title: Text("Result")) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                            if let result = coordinator.timestampResult {
                                UtilityResultRow(title: "Date in Selected Zone", value: result.localDate)
                                UtilityResultRow(title: "UTC Date", value: result.utcDate)
                                UtilityResultRow(title: "Seconds", value: result.seconds)
                                UtilityResultRow(title: "Milliseconds", value: result.milliseconds)
                            } else {
                                Text("Enter a timestamp or date to convert.")
                                    .font(.callout).foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
            .overflowFade(includingTop: true)
        } operations: {
            Button("Timestamp → Date") { coordinator.convertTimestamp(fromDate: false) }
            Button("Date → Timestamp") { coordinator.convertTimestamp(fromDate: true) }
        } actions: {
            Button("Use Current Time", action: coordinator.useNow)
        } status: {
            Text("Auto detects milliseconds at magnitude ≥ 100000000000; choose a unit for smaller values.")
        }
    }
}
