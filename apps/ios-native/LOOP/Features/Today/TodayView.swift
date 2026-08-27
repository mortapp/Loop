import SwiftUI

/// LOOP's control centre: what needs attention, derived entirely from LOOP data.
struct TodayView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var viewModel: TodayViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                header

                if appState.isSampleMode { SampleModeBanner() }

                if let viewModel {
                    LoadableView(state: viewModel.state, loadingRows: 4, retry: {
                        Task { await viewModel.load() }
                    }) { digest in
                        digestContent(digest, viewModel: viewModel)
                    }
                } else {
                    LoopLoadingState(rows: 4)
                }
            }
            .loopGutter()
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Text("LOOP")
                    .font(LoopFont.display(17, weight: .bold))
                    .kerning(2.5)
                    .foregroundStyle(LoopColor.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    router.present(.search)
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search LOOP")

                Button {
                    router.push(.profile)
                } label: {
                    AvatarBadge(profile: appState.profile)
                }
                .accessibilityLabel("Profile and settings")
            }
        }
        .refreshable {
            await viewModel?.refresh()
        }
        .task {
            guard viewModel == nil, let accountID = appState.activeAccountID else { return }
            let model = TodayViewModel(
                service: loop.todayService,
                accountID: accountID,
                density: appState.preferences.actionDensity
            )
            viewModel = model
            await model.load()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: LoopSpacing.xs) {
            Text(LoopDate.fullWeekday(Date()).uppercased())
                .font(LoopFont.eyebrow)
                .kerning(1.1)
                .foregroundStyle(LoopColor.inkTertiary)
            Text(greeting)
                .font(LoopFont.display(34, weight: .semibold))
                .foregroundStyle(LoopColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, LoopSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var greeting: String {
        let name = appState.profile?.user.displayName.split(separator: " ").first.map(String.init) ?? "there"
        let hour = LoopDate.calendar.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning, \(name)"
        case 12..<18: return "Good afternoon, \(name)"
        default: return "Good evening, \(name)"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func digestContent(_ digest: TodayDigest, viewModel: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.xl) {
            summaryStrip(digest)

            if digest.isClear {
                clearState(digest)
            } else {
                section(
                    title: "Needs attention",
                    subtitle: "Money is on the line right now.",
                    actions: digest.needsAttention,
                    viewModel: viewModel
                )
                section(
                    title: "Due soon",
                    subtitle: "Deadlines approaching this week.",
                    actions: digest.dueSoon,
                    viewModel: viewModel
                )
                section(
                    title: "Opportunities",
                    subtitle: "Ways to make or save money.",
                    actions: digest.opportunities,
                    viewModel: viewModel
                )
                section(
                    title: "Updates",
                    subtitle: nil,
                    actions: digest.information,
                    viewModel: viewModel
                )
            }

            if !digest.recentlyCompleted.isEmpty {
                completedSection(digest.recentlyCompleted, viewModel: viewModel)
            }
        }
    }

    private func summaryStrip(_ digest: TodayDigest) -> some View {
        HStack(spacing: LoopSpacing.md) {
            LoopMetricCard(
                label: "At stake",
                value: MoneyFormatter.compactString(digest.moneyAtStake),
                detail: "Refunds still owed to you",
                symbol: "hourglass",
                valueColor: digest.moneyAtStake.isZero ? LoopColor.ink : LoopColor.caution,
                accessibilityValue: MoneyFormatter.accessibleString(digest.moneyAtStake, showsSign: false)
                    + " still owed to you"
            )
            LoopMetricCard(
                label: "Recovered",
                value: MoneyFormatter.compactString(digest.recoveredThisMonth),
                detail: "Back in your pocket this month",
                symbol: "arrow.down.left.circle",
                valueColor: digest.recoveredThisMonth.isZero ? LoopColor.ink : LoopColor.positive,
                accessibilityValue: MoneyFormatter.accessibleString(digest.recoveredThisMonth, showsSign: false)
                    + " recovered this month"
            )
        }
    }

    @ViewBuilder
    private func section(
        title: String,
        subtitle: String?,
        actions: [LoopAction],
        viewModel: TodayViewModel
    ) -> some View {
        if !actions.isEmpty {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                LoopSectionHeader(title: title, subtitle: subtitle, count: actions.count)
                VStack(spacing: LoopSpacing.md) {
                    ForEach(actions) { action in
                        ActionCard(action: action) {
                            router.open(action.source)
                        } onComplete: {
                            Task { await viewModel.complete(action) }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        ))
                    }
                }
            }
            .animation(LoopMotion.standard, value: actions)
        }
    }

    private func clearState(_ digest: TodayDigest) -> some View {
        LoopCard(padding: LoopSpacing.xl) {
            VStack(spacing: LoopSpacing.md) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(LoopColor.positive)
                    .frame(width: 70, height: 70)
                    .background(LoopColor.positiveSoft, in: .circle)
                Text("Your loop is clear")
                    .font(LoopFont.display(22, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                Text("No deadlines, refunds or follow-ups need you right now. LOOP will surface the next one here.")
                    .font(LoopFont.subheadline)
                    .foregroundStyle(LoopColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    private func completedSection(_ actions: [LoopAction], viewModel: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.md) {
            LoopSectionHeader(title: "Recently completed", count: actions.count)
            LoopRowGroup(items: actions) { action in
                HStack(spacing: LoopSpacing.md) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(LoopColor.positive)
                        .font(.system(size: LoopIconSize.lg))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(action.title)
                            .font(LoopFont.subheadline)
                            .foregroundStyle(LoopColor.inkSecondary)
                            .strikethrough(color: LoopColor.inkTertiary)
                            .lineLimit(2)
                        if let completedAt = action.completedAt {
                            Text(LoopDate.relative(completedAt))
                                .font(LoopFont.caption)
                                .foregroundStyle(LoopColor.inkTertiary)
                        }
                    }
                    Spacer(minLength: LoopSpacing.sm)
                    Button("Undo") {
                        Task { await viewModel.restore(action) }
                    }
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(LoopColor.accent)
                    .frame(minHeight: 44)
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}

/// A single Today action.
struct ActionCard: View {
    let action: LoopAction
    let onOpen: () -> Void
    let onComplete: () -> Void

    var body: some View {
        LoopCardButton(action: onOpen, padding: LoopSpacing.lg) {
            VStack(alignment: .leading, spacing: LoopSpacing.md) {
                HStack(alignment: .top, spacing: LoopSpacing.md) {
                    LoopGlyph(symbol: action.type.symbolName, tone: action.priority.tone, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(action.title)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(LoopColor.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle = action.subtitle {
                            Text(subtitle)
                                .font(LoopFont.footnote)
                                .foregroundStyle(LoopColor.inkSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                    if let amount = action.amount {
                        LoopMoneyText(amount: amount, size: 16, tone: .neutral)
                    }
                }

                HStack(spacing: LoopSpacing.sm) {
                    LoopPriorityBadge(priority: action.priority)
                    if let due = action.dueDate {
                        LoopDeadlineView(date: due, compact: true)
                    }
                    Spacer(minLength: 0)
                    Button {
                        onComplete()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LoopColor.positive)
                            .frame(width: 44, height: 34)
                            .background(LoopColor.positiveSoft, in: .rect(cornerRadius: LoopRadius.xs))
                    }
                    .buttonStyle(LoopPressStyle())
                    .accessibilityLabel("Mark done: \(action.title)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint("Opens the related record")
    }
}

/// Circular avatar shown in the Today toolbar and Profile.
struct AvatarBadge: View {
    let profile: LoopProfile?
    var size: CGFloat = 30

    var body: some View {
        Text(profile?.user.initials ?? "L")
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(LoopColor.ink, in: .circle)
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .environment(\.loop, .preview)
    .environment(AppState(environment: .preview))
    .environment(AppRouter())
}
