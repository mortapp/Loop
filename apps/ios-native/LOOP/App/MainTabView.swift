import SwiftUI

/// LOOP's authenticated shell: five tabs, each with its own navigation stack.
struct MainTabView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var router = router

        TabView(selection: tabSelection) {
            ForEach(LoopTab.allCases) { tab in
                NavigationStack(path: router.path(for: tab)) {
                    rootView(for: tab)
                        .navigationDestination(for: AppDestination.self) { destination in
                            DestinationView(destination: destination)
                        }
                }
                .tabItem {
                    Label {
                        Text(tab.title)
                    } icon: {
                        Image(systemName: router.selectedTab == tab ? tab.selectedSymbolName : tab.symbolName)
                    }
                }
                .tag(tab)
            }
        }
        .sheet(item: $router.presentedSheet) { sheet in
            SheetView(sheet: sheet)
        }
    }

    /// Re-selecting the active tab pops that stack to its root.
    private var tabSelection: Binding<LoopTab> {
        Binding(
            get: { router.selectedTab },
            set: { newValue in
                if newValue == router.selectedTab {
                    router.popToRoot(newValue)
                } else {
                    LoopHaptics.selection()
                    router.selectedTab = newValue
                }
            }
        )
    }

    @ViewBuilder
    private func rootView(for tab: LoopTab) -> some View {
        switch tab {
        case .today: TodayView()
        case .money: MoneyView()
        case .sell: SellView()
        case .business: BusinessView()
        case .askLoop: AskLoopView()
        }
    }
}

/// One place that maps a destination to its screen.
struct DestinationView: View {
    let destination: AppDestination

    var body: some View {
        switch destination {
        case .transactions: TransactionListView()
        case .transaction(let id): TransactionDetailView(transactionID: id)
        case .purchases: PurchasesView()
        case .purchase(let id): PurchaseDetailView(purchaseID: id)

        case .protect: ProtectView()
        case .returns: ReturnsListView()
        case .returnDetail(let id): ReturnDetailView(returnID: id)
        case .refunds: RefundsListView()
        case .refund(let id): RefundDetailView(refundID: id)
        case .warranties: WarrantiesView()
        case .warranty(let id): WarrantyDetailView(warrantyID: id)
        case .documents: DocumentsView()
        case .ownedItem(let id): OwnedItemDetailView(itemID: id)

        case .sales: SalesListView()
        case .sale(let id): SaleDetailView(saleID: id)

        case .leads: LeadsView()
        case .lead(let id): LeadDetailView(leadID: id)
        case .customers: CustomersView()
        case .customer(let id): CustomerDetailView(customerID: id)
        case .opportunities: OpportunitiesView()
        case .opportunity(let id): OpportunityDetailView(opportunityID: id)
        case .quotes: QuotesView()
        case .quote(let id): QuoteDetailView(quoteID: id)
        case .earnings: EarningsView()

        case .profile: ProfileView()
        case .settings: SettingsView()
        case .personalization: PersonalizationView()
        case .help: HelpView()
        case .about: AboutView()
        }
    }
}

/// One place that maps a sheet case to its presented content.
struct SheetView: View {
    let sheet: AppSheet

    var body: some View {
        switch sheet {
        case .search:
            SearchView()
        case .newLead:
            LeadEditorView(lead: nil)
        case .newOpportunity(let leadID):
            OpportunityEditorView(opportunity: nil, leadID: leadID)
        case .newQuote(let customerID):
            QuoteEditorView(quote: nil, customerID: customerID)
        case .newCustomer:
            CustomerEditorView(customer: nil)
        case .newSale(let ownedItemID):
            SaleEditorView(sale: nil, ownedItemID: ownedItemID)
        case .editWarranty(let itemID, let warrantyID):
            WarrantyEditorView(ownedItemID: itemID, warrantyID: warrantyID)
        case .startReturn(let purchaseID):
            StartReturnView(purchaseID: purchaseID)
        case .attachDocument(let target):
            AttachDocumentView(target: target)
        }
    }
}

/// Shared screen scaffold: LOOP canvas, gutters and a serif title block.
struct LoopScreen<Content: View>: View {
    let title: String
    var subtitle: String?
    var showsSampleNotice: Bool = false
    @ViewBuilder var content: Content

    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                if appState.isSampleMode && showsSampleNotice {
                    SampleModeBanner()
                }
                content
            }
            .loopGutter()
            .padding(.top, LoopSpacing.sm)
            .padding(.bottom, LoopSpacing.xxxl)
        }
        .background(LoopColor.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// Honest, persistent notice that LOOP is not reading a live backend.
struct SampleModeBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: LoopSpacing.md) {
            Image(systemName: "flask")
                .font(.system(size: LoopIconSize.md, weight: .semibold))
                .foregroundStyle(LoopColor.info)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sample data")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(LoopColor.ink)
                Text("This build isn't connected to a LOOP backend, so records here are examples — not your real accounts.")
                    .font(LoopFont.caption)
                    .foregroundStyle(LoopColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LoopSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LoopColor.infoSoft, in: .rect(cornerRadius: LoopRadius.md))
        .accessibilityElement(children: .combine)
    }
}
