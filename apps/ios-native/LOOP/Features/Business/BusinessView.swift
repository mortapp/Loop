import SwiftUI

/// The MAKE side of LOOP: leads, opportunities, quotes and income.
struct BusinessView: View {
    @Environment(\.loop) private var loop
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var state: LoadState<BusinessSummary> = .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                if appState.isSampleMode { SampleModeBanner() }

                LoadableView(state: state, loadingRows: 4, retry: { Task { await load() } }) { summary in
                    VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                        pipeline(summary)
                        metrics(summary)
                        followUps(summary)
                        directory
                    }
                }
            }
            .loopGutter()
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle("Business")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { router.present(.newLead) } label: {
                        Label("New lead", systemImage: "person.badge.plus")
                    }
                    Button { router.present(.newOpportunity(leadID: nil)) } label: {
                        Label("New opportunity", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    Button { router.present(.newQuote(customerID: nil)) } label: {
                        Label("New quote", systemImage: "doc.badge.plus")
                    }
                    Button { router.present(.newCustomer) } label: {
                        Label("New customer", systemImage: "person.crop.circle.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create")
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func pipeline(_ summary: BusinessSummary) -> some View {
        LoopCard(padding: LoopSpacing.xl, isRaised: true) {
            VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                VStack(alignment: .leading, spacing: LoopSpacing.xs) {
                    Text("PIPELINE VALUE")
                        .font(LoopFont.eyebrow)
                        .kerning(0.9)
                        .foregroundStyle(LoopColor.inkTertiary)
                    Text(MoneyFormatter.compactString(summary.pipelineValue))
                        .font(LoopFont.amount(38, weight: .semibold))
                        .foregroundStyle(LoopColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .accessibilityLabel(
                            "Pipeline value " + MoneyFormatter.accessibleString(summary.pipelineValue, showsSign: false)
                        )
                    Text("\(summary.activeOpportunities) active opportunit\(summary.activeOpportunities == 1 ? "y" : "ies")")
                        .font(LoopFont.footnote)
                        .foregroundStyle(LoopColor.inkSecondary)
                }
                LoopDivider()
                HStack(spacing: LoopSpacing.xl) {
                    stat("Open leads", "\(summary.openLeads)")
                    stat("Quotes out", "\(summary.quotesAwaitingResponse)")
                    stat("Won", "\(summary.wonThisYear)")
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(LoopFont.amount(20, weight: .semibold))
                .foregroundStyle(LoopColor.ink)
            Text(label)
                .font(LoopFont.caption)
                .foregroundStyle(LoopColor.inkTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func metrics(_ summary: BusinessSummary) -> some View {
        HStack(spacing: LoopSpacing.md) {
            LoopMetricCard(
                label: "Quoted",
                value: MoneyFormatter.compactString(summary.quotedValue),
                detail: "Awaiting a response",
                symbol: "doc.plaintext",
                valueColor: LoopColor.caution
            )
            LoopMetricCard(
                label: "Earned",
                value: MoneyFormatter.compactString(summary.earningsThisYear),
                detail: "Income this year",
                symbol: "dollarsign.circle",
                valueColor: LoopColor.positive
            )
        }
    }

    @ViewBuilder
    private func followUps(_ summary: BusinessSummary) -> some View {
        VStack(alignment: .leading, spacing: LoopSpacing.md) {
            LoopSectionHeader(
                title: "Next follow-ups",
                subtitle: "Keep the pipeline moving",
                count: summary.nextFollowUps.count
            ) {
                LoopInlineAction(title: "Leads") { router.push(.leads) }
            }
            if summary.nextFollowUps.isEmpty {
                LoopCard {
                    LoopEmptyState(
                        symbol: "person.crop.circle.badge.checkmark",
                        title: "Nothing scheduled",
                        message: "Add a follow-up date to a lead and it will appear here and in Today.",
                        actionTitle: "New lead",
                        action: { router.present(.newLead) }
                    )
                }
            } else {
                LoopRowGroup(items: summary.nextFollowUps) { lead in
                    LoopNavigationRow {
                        router.push(.lead(lead.id))
                    } content: {
                        LeadRow(lead: lead)
                    }
                }
            }
        }
    }

    private var directory: some View {
        LoopCard(padding: 0) {
            VStack(spacing: 0) {
                row("Leads", "person.crop.circle.badge.clock", .leads)
                LoopDivider(inset: LoopSpacing.lg)
                row("Opportunities", "chart.line.uptrend.xyaxis", .opportunities)
                LoopDivider(inset: LoopSpacing.lg)
                row("Quotes", "doc.plaintext", .quotes)
                LoopDivider(inset: LoopSpacing.lg)
                row("Customers", "person.2", .customers)
                LoopDivider(inset: LoopSpacing.lg)
                row("Earnings", "dollarsign.circle", .earnings)
            }
        }
    }

    private func row(_ title: String, _ symbol: String, _ destination: AppDestination) -> some View {
        Button {
            router.push(destination)
        } label: {
            LoopListRow(title: title, symbol: symbol, tone: .accent)
                .padding(.horizontal, LoopSpacing.lg)
                .padding(.vertical, LoopSpacing.md)
        }
        .buttonStyle(LoopPressStyle())
    }

    private func load() async {
        guard let accountID = appState.activeAccountID else { return }
        if state.value == nil { state = .loading }
        do {
            state = .loaded(try await loop.businessService.summary(accountID: accountID))
        } catch {
            state = .failed(LoopError.map(error))
        }
    }
}

struct LeadRow: View {
    let lead: Lead

    var body: some View {
        HStack(spacing: LoopSpacing.md) {
            LoopGlyph(symbol: lead.status.symbolName, tone: lead.status.tone)
            VStack(alignment: .leading, spacing: 2) {
                Text(lead.name)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                    .lineLimit(1)
                HStack(spacing: LoopSpacing.xs) {
                    Text(lead.status.label)
                    if let followUp = lead.nextFollowUp {
                        Text("·")
                        Text(LoopDate.relative(followUp))
                            .foregroundStyle(lead.isFollowUpDue ? LoopColor.critical : LoopColor.inkSecondary)
                    }
                }
                .font(LoopFont.caption)
                .foregroundStyle(LoopColor.inkSecondary)
            }
            Spacer(minLength: LoopSpacing.sm)
            if let value = lead.estimatedValue {
                LoopMoneyText(amount: value, size: 15, tone: .muted)
            }
        }
        .frame(minHeight: 44)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
