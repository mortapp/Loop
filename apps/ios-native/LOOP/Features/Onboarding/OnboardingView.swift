import SwiftUI

/// Short, premium onboarding for accounts that haven't finished setup.
struct OnboardingView: View {
    let profile: LoopProfile

    @Environment(AppState.self) private var appState
    @State private var step: Step = .welcome
    @State private var displayName: String = ""
    @State private var accountName: String = "Personal"
    @State private var density: LoopPreferences.ActionDensity = .balanced
    @State private var isFinishing = false

    enum Step: Int, CaseIterable {
        case welcome, identity, howItWorks, preference

        var title: String {
            switch self {
            case .welcome: return "Welcome to LOOP"
            case .identity: return "Set up your account"
            case .howItWorks: return "One continuous loop"
            case .preference: return "How much should Today show?"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            progressBar

            ScrollView {
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    Text(step.title)
                        .font(LoopFont.display(32, weight: .semibold))
                        .foregroundStyle(LoopColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .id(step)

                    switch step {
                    case .welcome: welcomeStep
                    case .identity: identityStep
                    case .howItWorks: howItWorksStep
                    case .preference: preferenceStep
                    }
                }
                .loopGutter()
                .padding(.top, LoopSpacing.xl)
                .padding(.bottom, LoopSpacing.xxl)
            }

            footer
        }
        .background(LoopColor.canvas)
        .animation(LoopMotion.standard, value: step)
        .onAppear {
            displayName = profile.user.displayName
            accountName = profile.activeAccount.name
        }
    }

    private var progressBar: some View {
        HStack(spacing: LoopSpacing.xs) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? LoopColor.accent : LoopColor.hairline)
                    .frame(height: 3)
            }
        }
        .loopGutter()
        .padding(.top, LoopSpacing.md)
        .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count)")
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.lg) {
            LoopMark(size: 64)
            Text("LOOP keeps one thread running through everything you earn, buy, protect, recover and sell — so money doesn't quietly leak out of your life.")
                .font(LoopFont.body)
                .foregroundStyle(LoopColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var identityStep: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.lg) {
            LoopTextField(
                label: "Your name",
                text: $displayName,
                placeholder: "Avery Sinclair",
                capitalization: .words,
                contentType: .name,
                isRequired: true
            )
            LoopTextField(
                label: "Account name",
                text: $accountName,
                placeholder: "Personal",
                capitalization: .words
            )
            Text("You can add more accounts later — for example a separate one for your business.")
                .font(LoopFont.footnote)
                .foregroundStyle(LoopColor.inkTertiary)
        }
    }

    private var howItWorksStep: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.md) {
            ForEach(loopStages, id: \.title) { stage in
                LoopCard(padding: LoopSpacing.md) {
                    HStack(spacing: LoopSpacing.md) {
                        LoopGlyph(symbol: stage.symbol, tone: stage.tone, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(stage.title)
                                .font(.system(.subheadline, weight: .semibold))
                                .foregroundStyle(LoopColor.ink)
                            Text(stage.detail)
                                .font(LoopFont.caption)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var preferenceStep: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.md) {
            ForEach(LoopPreferences.ActionDensity.allCases) { option in
                Button {
                    LoopHaptics.selection()
                    density = option
                } label: {
                    LoopCard(padding: LoopSpacing.md, tint: density == option ? LoopColor.accentSoft : nil) {
                        HStack(spacing: LoopSpacing.md) {
                            Image(systemName: density == option ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: LoopIconSize.lg))
                                .foregroundStyle(density == option ? LoopColor.accent : LoopColor.inkTertiary)
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
                .accessibilityAddTraits(density == option ? [.isSelected] : [])
            }
        }
    }

    private var footer: some View {
        VStack(spacing: LoopSpacing.sm) {
            LoopButton(
                title: step == .preference ? "Enter LOOP" : "Continue",
                isLoading: isFinishing,
                isEnabled: step != .identity || !displayName.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                advance()
            }
            if step != .welcome {
                Button("Back") {
                    withAnimation(LoopMotion.standard) {
                        step = Step(rawValue: step.rawValue - 1) ?? .welcome
                    }
                }
                .font(LoopFont.subheadline)
                .foregroundStyle(LoopColor.inkSecondary)
                .frame(minHeight: 44)
            }
        }
        .loopGutter()
        .padding(.bottom, LoopSpacing.md)
        .background(LoopColor.canvas)
    }

    private func advance() {
        guard step == .preference else {
            withAnimation(LoopMotion.standard) {
                step = Step(rawValue: step.rawValue + 1) ?? .preference
            }
            return
        }
        isFinishing = true
        appState.update { $0.actionDensity = density }
        Task {
            await appState.completeOnboarding(displayName: displayName, accountName: accountName)
            isFinishing = false
        }
    }

    private var loopStages: [(title: String, detail: String, symbol: String, tone: LoopTone)] {
        [
            ("Make", "Track leads, quotes and the income you close.", "briefcase", .accent),
            ("Buy", "Every purchase carries its receipt, return window and warranty.", "bag", .info),
            ("Protect", "LOOP watches deadlines so nothing expires quietly.", "shield.lefthalf.filled", .caution),
            ("Recover", "Returns and refunds are chased until the money lands.", "arrow.uturn.backward", .positive),
            ("Sell", "What you no longer need becomes money again.", "tag", .accent)
        ]
    }
}

#Preview {
    OnboardingView(profile: LoopFixtures.profile)
        .environment(AppState(environment: .preview))
}
