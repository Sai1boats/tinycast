import SwiftUI

struct CurrencyToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    @FocusState private var inputFocused: Bool

    var body: some View {
        @Bindable var coordinator = coordinator
        UtilityToolLayout(error: coordinator.currencyMessage, isBusy: coordinator.rates.isRefreshing) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                HStack(spacing: Theme.Spacing.xxl) {
                    Picker("Default Currency", selection: $coordinator.sourceCurrency) {
                        ForEach(coordinator.currencyCodes, id: \.self) { Text($0).tag($0) }
                    }.fixedSize()
                    Picker("Show", selection: $coordinator.targetCurrency) {
                        Text("Popular Currencies").tag("")
                        ForEach(coordinator.currencyCodes, id: \.self) { Text($0).tag($0) }
                    }.fixedSize()
                }
                UtilityCard(title: Text("Amount and currency"), detail: String(localized: "Live conversion")) {
                    TextField("100￥ · $200 · CNY100", text: $coordinator.currencyInput)
                        .textFieldStyle(.plain)
                        .font(.title3.monospacedDigit())
                        .frame(minHeight: Theme.Size.dialogButtonHeight)
                        .focused($inputFocused)
                        .accessibilityLabel(String(localized: "Amount and currency"))
                    HStack(spacing: Theme.Spacing.md) {
                        Text("$ = USD · ￥ / ¥ = CNY · Specify a target: 100 CNY to JPY")
                        Spacer(minLength: 0)
                        if let query = coordinator.currencyQuery {
                            Text(query.amount + " " + query.source).monospacedDigit()
                        }
                    }
                    .font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                }
                ScrollView {
                    if coordinator.currencyQuery != nil {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.xl) {
                            ForEach(coordinator.currencyTargets, id: \.self) { code in
                                CurrencyResultCard(code: code, value: coordinator.currencyValue(for: code))
                            }
                        }
                    } else {
                        UtilityCard(title: Text("Result")) {
                            VStack(spacing: Theme.Spacing.xl) {
                                Text("Type an amount to see popular currencies").font(.callout)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                HStack(spacing: Theme.Spacing.md) {
                                    ForEach(["100￥", "$200", "CNY100 to EUR"], id: \.self) { example in
                                        Button(example) { coordinator.currencyInput = example }
                                            .buttonStyle(.utilityAction)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.xxl)
                        }
                    }
                }
                .overflowFade(includingTop: true)
            }
        } operations: {
            Button("Refresh Rates", action: coordinator.refreshRates)
                .disabled(coordinator.rates.isRefreshing)
        } actions: {
            EmptyView()
        } status: {
            VStack(spacing: Theme.Spacing.xs) {
                if let rates = coordinator.rates.rates {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let downloaded = rates.fetchedAt.formatted(date: .abbreviated, time: .shortened)
                        Text(String(localized: "Rates downloaded: \(downloaded)"))
                        if context.date.timeIntervalSince(rates.fetchedAt) >= 86_400 {
                            Text("Rates are over 24 hours old. Refresh for a newer snapshot.")
                                .foregroundStyle(Theme.Colors.warning)
                        }
                    }
                } else {
                    Text("No exchange rates yet. Connect to the internet and refresh.")
                }
                Text("Source: Raycast currency feed. Cached reference rates; excludes provider fees and spreads.")
            }
        }
        .onAppear { inputFocused = true }
    }
}
