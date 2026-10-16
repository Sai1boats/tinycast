import SwiftUI

struct TranslationCredentialsView: View {
    @Environment(TranslationCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Baidu Translation Credentials").font(.headline)
            Text("Use the APP ID and secret for Baidu's General Translation API.")
                .foregroundStyle(Theme.Colors.textSecondary)
            Text("Baidu translates first. Without credentials, or when Baidu fails, Apple Translation answers on this Mac.")
                .font(.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
            TextField("APP ID", text: $coordinator.appID)
                .textFieldStyle(.roundedBorder)
            SecureField("Secret", text: $coordinator.secret)
                .textFieldStyle(.roundedBorder)
            Text("Credentials stay in this app's Keychain. Translating sends your text to Baidu.")
                .font(.callout)
                .foregroundStyle(Theme.Colors.textSecondary)
            HStack {
                Spacer()
                Button("Cancel") { coordinator.showsSettings = false }
                    .buttonStyle(.modalAction(.cancel, fillsWidth: false))
                Button("Save Credentials", action: coordinator.saveCredentials)
                    .buttonStyle(.modalAction(.primary, fillsWidth: false))
            }
            Spacer()
        }
        .padding(.top, Theme.Spacing.xxl)
        .disabled(coordinator.isLoading || coordinator.isSaving)
    }
}
