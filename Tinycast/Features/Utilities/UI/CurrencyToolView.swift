import SwiftUI

struct CurrencyToolView: View {
    @Environment(UtilityCoordinator.self) private var coordinator
    @FocusState private var inputFocused: Bool

    var body: some View {
        @Bindable var coordinator = coordinator
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                TextField("100￥ · $200 · CNY100", text: $coordinator.currencyInput)
                    .textFieldStyle(.plain)
                    .font(.largeTitle.monospacedDigit())
                    .focused($inputFocused)
                    .accessibilityLabel(String(localized: "Amount and currency"))
                HStack {
                    Text("Live conversion").font(.caption).foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    if let query = coordinator.currencyQuery {
                        Text(query.amount + " " + query.source)
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(Theme.Spacing.xxl)
            .background(Theme.Colors.cardFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            HStack {
                Picker("Default Currency", selection: $coordinator.sourceCurrency) {
                    ForEach(coordinator.currencyCodes, id: \.self) { Text($0).tag($0) }
                }
                Picker("Show", selection: $coordinator.targetCurrency) {
                    Text("Popular Currencies").tag("")
                    ForEach(coordinator.currencyCodes, id: \.self) { Text($0).tag($0) }
                }
            }
            .font(.callout)
            Text("$ = USD · ￥ / ¥ = CNY · Specify a target: 100 CNY to JPY")
                .font(.caption).foregroundStyle(Theme.Colors.textTertiary)
            if !coordinator.currencyMessage.isEmpty {
                Text(coordinator.currencyMessage).font(.callout).foregroundStyle(Theme.Colors.destructive)
            }
            ScrollView {
                if coordinator.currencyQuery != nil {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.md) {
                        ForEach(coordinator.currencyTargets, id: \.self) { code in
                            CurrencyResultCard(code: code, value: coordinator.currencyValue(for: code))
                        }
                    }
                } else {
                    VStack(spacing: Theme.Spacing.xl) {
                        SymbolImage(name: "globe", size: Theme.Size.dialogSymbol)
                            .foregroundStyle(Theme.Colors.textTertiary)
                        Text("Type an amount to see popular currencies").font(.headline)
                        HStack(spacing: Theme.Spacing.md) {
                            ForEach(["100￥", "$200", "CNY100 to EUR"], id: \.self) { example in
                                Button(example) { coordinator.currencyInput = example }
                                    .buttonStyle(.modalAction(.standard, fillsWidth: false))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.xxxl)
                }
            }
            .overflowFade(includingTop: true)
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
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
                .font(.caption).foregroundStyle(Theme.Colors.textTertiary)
                Spacer()
                if coordinator.rates.isRefreshing { ProgressView().controlSize(.small) }
                Button("Refresh Rates", action: coordinator.refreshRates)
                    .buttonStyle(.modalAction(.standard, fillsWidth: false))
                    .disabled(coordinator.rates.isRefreshing)
            }
        }
        .onAppear { inputFocused = true }
    }
}
