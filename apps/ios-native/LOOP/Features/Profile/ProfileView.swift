import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var showsSignOutConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                if let profile = appState.profile {
                    identityCard(profile)
                    accountsSection(profile)
                }
                links
                signOut
            }
            .loopGutter()
            .padding(.vertical, LoopSpacing.md)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Sign out of LOOP?", isPresented: $showsSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await appState.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func identityCard(_ profile: LoopProfile) -> some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            HStack(spacing: LoopSpacing.lg) {
                AvatarBadge(profile: profile, size: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.user.displayName)
                        .font(LoopFont.display(22, weight: .semibold))
                        .foregroundStyle(LoopColor.ink)
                    Text(profile.user.email)
                        .font(LoopFont.footnote)
                        .foregroundStyle(LoopColor.inkSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("In LOOP since \(LoopDate.medium(profile.user.createdAt))")
                        .font(LoopFont.caption)
                        .foregroundStyle(LoopColor.inkTertiary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func accountsSection(_ profile: LoopProfile) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
            LoopEyebrow(text: "Accounts")
            LoopCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(profile.accounts.enumerated()), id: \.element.id) { index, account in
                        Button {
                            Task { await appState.switchAccount(to: account.id) }
                        } label: {
                            HStack(spacing: LoopSpacing.md) {
                                LoopGlyph(
                                    symbol: account.kind.symbolName,
                                    tone: account.id == profile.activeAccountID ? .accent : .neutral
                                )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(account.name)
                                        .font(.system(.body, weight: .semibold))
                                        .foregroundStyle(LoopColor.ink)
                                    Text(account.kind.label)
                                        .font(LoopFont.caption)
                                        .foregroundStyle(LoopColor.inkSecondary)
                                }
                                Spacer(minLength: LoopSpacing.sm)
                                if account.id == profile.activeAccountID {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(LoopColor.accent)
                                }
                            }
                            .frame(minHeight: 44)
                            .padding(.horizontal, LoopSpacing.lg)
                            .padding(.vertical, LoopSpacing.md)
                            .contentShape(.rect)
                        }
                        .buttonStyle(LoopPressStyle())
                        .accessibilityAddTraits(account.id == profile.activeAccountID ? [.isSelected] : [])
                        if index < profile.accounts.count - 1 { LoopDivider(inset: LoopSpacing.lg) }
                    }
                }
            }
        }
    }

    private var links: some View {
        LoopCard(padding: 0) {
            VStack(spacing: 0) {
                link("Settings", "gearshape", .settings)
                LoopDivider(inset: LoopSpacing.lg)
                link("Personalization", "slider.horizontal.3", .personalization)
                LoopDivider(inset: LoopSpacing.lg)
                link("Help & support", "questionmark.circle", .help)
                LoopDivider(inset: LoopSpacing.lg)
                link("About LOOP", "info.circle", .about)
            }
        }
    }

    private func link(_ title: String, _ symbol: String, _ destination: AppDestination) -> some View {
        Button {
            router.push(destination)
        } label: {
            LoopListRow(title: title, symbol: symbol, tone: .neutral)
                .padding(.horizontal, LoopSpacing.lg)
                .padding(.vertical, LoopSpacing.md)
        }
        .buttonStyle(LoopPressStyle())
    }

    private var signOut: some View {
        LoopDestructiveButton(title: "Sign out", symbol: "rectangle.portrait.and.arrow.right") {
            showsSignOutConfirmation = true
        }
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var appState = appState

        return ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                group("Account") {
                    settingsLink("Profile", "person.crop.circle", .profile)
                    LoopDivider(inset: LoopSpacing.lg)
                    settingsLink("Personalization", "slider.horizontal.3", .personalization)
                }

                group("App") {
                    VStack(alignment: .leading, spacing: LoopSpacing.md) {
                        Picker("Appearance", selection: Binding(
                            get: { appState.preferences.appearance },
                            set: { value in appState.update { $0.appearance = value } }
                        )) {
                            ForEach(LoopPreferences.Appearance.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Haptics", isOn: Binding(
                            get: { appState.preferences.hapticsEnabled },
                            set: { value in appState.update { $0.hapticsEnabled = value } }
                        ))
                        .font(LoopFont.body)

                        Toggle("Show cents in summaries", isOn: Binding(
                            get: { appState.preferences.showsCentsInSummaries },
                            set: { value in appState.update { $0.showsCentsInSummaries = value } }
                        ))
                        .font(LoopFont.body)
                    }
                    .padding(LoopSpacing.lg)
                }

                group("Notifications") {
                    VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                        Text("LOOP will ask permission the first time you set a deadline reminder — never before that.")
                            .font(LoopFont.footnote)
                            .foregroundStyle(LoopColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Reminders for return windows, overdue refunds, expiring warranties, quote responses and lead follow-ups will be delivered once LOOP's notification service is connected.")
                            .font(LoopFont.caption)
                            .foregroundStyle(LoopColor.inkTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(LoopSpacing.lg)
                }

                group("Support") {
                    settingsLink("Help", "questionmark.circle", .help)
                    LoopDivider(inset: LoopSpacing.lg)
                    settingsLink("About LOOP", "info.circle", .about)
                }

                Text(LoopConfiguration.versionDescription)
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.inkTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .loopGutter()
            .padding(.vertical, LoopSpacing.md)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func group<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
            LoopEyebrow(text: title)
            LoopCard(padding: 0) {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private func settingsLink(_ title: String, _ symbol: String, _ destination: AppDestination) -> some View {
        Button {
            router.push(destination)
        } label: {
            LoopListRow(title: title, symbol: symbol)
                .padding(.horizontal, LoopSpacing.lg)
                .padding(.vertical, LoopSpacing.md)
        }
        .buttonStyle(LoopPressStyle())
    }
}

struct PersonalizationView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                    LoopEyebrow(text: "Today density")
                    VStack(spacing: LoopSpacing.sm) {
                        ForEach(LoopPreferences.ActionDensity.allCases) { option in
                            Button {
                                LoopHaptics.selection()
                                appState.update { $0.actionDensity = option }
                            } label: {
                                LoopCard(
                                    padding: LoopSpacing.md,
                                    tint: appState.preferences.actionDensity == option ? LoopColor.accentSoft : nil
                                ) {
                                    HStack(spacing: LoopSpacing.md) {
                                        Image(systemName: appState.preferences.actionDensity == option
                                              ? "largecircle.fill.circle" : "circle")
                                            .font(.system(size: LoopIconSize.lg))
                                            .foregroundStyle(
                                                appState.preferences.actionDensity == option
                                                    ? LoopColor.accent : LoopColor.inkTertiary
                                            )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.label)
                                                .font(.system(.body, weight: .semibold))
                                                .foregroundStyle(LoopColor.ink)
                                            Text(option.detail)
                                                .font(LoopFont.caption)
                                                .foregroundStyle(LoopColor.inkSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                            .buttonStyle(LoopPressStyle())
                            .accessibilityAddTraits(
                                appState.preferences.actionDensity == option ? [.isSelected] : []
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                    LoopEyebrow(text: "Money")
                    LoopCard {
                        VStack(alignment: .leading, spacing: LoopSpacing.md) {
                            Text("Default ledger filter")
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(LoopColor.ink)
                            Picker("Default filter", selection: Binding(
                                get: { appState.preferences.defaultMoneyFilter },
                                set: { value in appState.update { $0.defaultMoneyFilter = value } }
                            )) {
                                ForEach(MoneyFilter.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(LoopColor.accent)
                        }
                    }
                }

                Text("Personalization changes what LOOP shows you. It never changes your records.")
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .loopGutter()
            .padding(.vertical, LoopSpacing.md)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
    }
}
