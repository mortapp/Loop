import SwiftUI

struct HelpView: View {
    @Environment(AppRouter.self) private var router
    @State private var expanded: Set<String> = []

    private let questions: [(id: String, question: String, answer: String)] = [
        (
            "loop",
            "What does LOOP actually do?",
            "LOOP keeps one thread running through the money in your life: work you quote and win, things you buy, the receipts and deadlines that protect them, the refunds you're owed, and the items you can sell again. Every module writes back into the same ledger."
        ),
        (
            "today",
            "Where do Today's actions come from?",
            "They're generated from your own records — return deadlines, refund age, warranty end dates, missing receipts, quote and lead follow-ups. Nothing in Today is invented; tapping an action opens the record behind it."
        ),
        (
            "returns",
            "Does LOOP contact merchants for me?",
            "No. LOOP prepares, organises and tracks a return, keeps your evidence together and chases the deadline. You still ship the item and talk to the merchant yourself."
        ),
        (
            "refunds",
            "When is a refund counted as recovered?",
            "Only when you mark it received. LOOP then clears the pending transaction in Money and counts the amount toward recovered money."
        ),
        (
            "estimates",
            "Are resale estimates real market prices?",
            "No. Estimates are the numbers you enter. LOOP does not price items against a live marketplace, and always labels an estimate as an estimate."
        ),
        (
            "business",
            "How does business income reach Money?",
            "Accepting a quote moves its opportunity to Won. When you record the income, LOOP writes a single business-income transaction into the Money ledger. Business never keeps a separate balance."
        ),
        (
            "ask",
            "Does Ask LOOP send my data to an AI company?",
            "Ask LOOP talks only to LOOP's own server, which is responsible for any model access. No AI provider credential exists inside this app."
        ),
        (
            "privacy",
            "What does LOOP store on my device?",
            "Your session is held in the iOS keychain. Preferences are stored locally. Financial records live in your LOOP account behind row-level security."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                LoopCard(padding: LoopSpacing.xl) {
                    VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                        Text("How LOOP works")
                            .font(LoopFont.display(22, weight: .semibold))
                            .foregroundStyle(LoopColor.ink)
                        Text("Make → Buy → Protect → Recover → Sell → Money → Repeat.")
                            .font(LoopFont.subheadline)
                            .foregroundStyle(LoopColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                    LoopEyebrow(text: "Common questions")
                    LoopCard(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(questions.enumerated()), id: \.element.id) { index, item in
                                DisclosureRow(
                                    question: item.question,
                                    answer: item.answer,
                                    isExpanded: expanded.contains(item.id)
                                ) {
                                    withAnimation(LoopMotion.quick) {
                                        if expanded.contains(item.id) {
                                            expanded.remove(item.id)
                                        } else {
                                            expanded.insert(item.id)
                                        }
                                    }
                                }
                                if index < questions.count - 1 { LoopDivider(inset: LoopSpacing.lg) }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                    LoopEyebrow(text: "Still stuck?")
                    LoopCard {
                        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                            Text("Support is handled by the LOOP team by email. Response times depend on the team, so LOOP won't promise instant help.")
                                .font(LoopFont.subheadline)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Include your app version so issues can be traced: \(LoopConfiguration.versionDescription).")
                                .font(LoopFont.caption)
                                .foregroundStyle(LoopColor.inkTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                LoopSecondaryButton(title: "About LOOP", symbol: "info.circle") {
                    router.push(.about)
                }
            }
            .loopGutter()
            .padding(.vertical, LoopSpacing.md)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Help")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DisclosureRow: View {
    let question: String
    let answer: String
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
            Button(action: toggle) {
                HStack(alignment: .top, spacing: LoopSpacing.md) {
                    Text(question)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(LoopColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: LoopSpacing.sm)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LoopColor.inkTertiary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(LoopPressStyle())
            .accessibilityHint(isExpanded ? "Collapse answer" : "Expand answer")

            if isExpanded {
                Text(answer)
                    .font(LoopFont.footnote)
                    .foregroundStyle(LoopColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, LoopSpacing.lg)
        .padding(.vertical, LoopSpacing.sm)
    }
}

struct AboutView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                VStack(alignment: .leading, spacing: LoopSpacing.md) {
                    LoopMark(size: 54)
                    Text("LOOP")
                        .font(LoopFont.display(34, weight: .bold))
                        .kerning(4)
                        .foregroundStyle(LoopColor.ink)
                    Text("One operating system for your economic life.")
                        .font(LoopFont.display(17, weight: .regular))
                        .foregroundStyle(LoopColor.inkSecondary)
                }

                LoopCard {
                    VStack(spacing: LoopSpacing.sm) {
                        LoopDetailRow(label: "Version", value: LoopConfiguration.appVersion)
                        LoopDivider()
                        LoopDetailRow(label: "Build", value: LoopConfiguration.buildNumber)
                        LoopDivider()
                        LoopDetailRow(
                            label: "Data source",
                            value: appState.isSampleMode ? "Sample data" : "Live account",
                            valueColor: appState.isSampleMode ? LoopColor.caution : LoopColor.positive
                        )
                    }
                }

                VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                    LoopEyebrow(text: "Privacy")
                    LoopCard {
                        Text("LOOP asks for the minimum it needs. It requests no contacts, location or photo library access. Your session lives in the iOS keychain, and your records are protected by row-level security in your own account.")
                            .font(LoopFont.subheadline)
                            .foregroundStyle(LoopColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                    LoopEyebrow(text: "Legal")
                    LoopCard {
                        Text("The published privacy policy and terms of service are maintained by the LOOP team and are not bundled with this build.")
                            .font(LoopFont.subheadline)
                            .foregroundStyle(LoopColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .loopGutter()
            .padding(.vertical, LoopSpacing.md)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
