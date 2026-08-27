import SwiftUI

/// The dependency container. Views receive it through the SwiftUI environment
/// and never construct services themselves.
@MainActor
struct AppEnvironment {
    let mode: Mode
    let authService: any AuthService
    let accountService: any AccountService
    let todayService: any TodayService
    let moneyService: any MoneyService
    let purchaseService: any PurchaseService
    let protectionService: any ProtectionService
    let returnService: any ReturnService
    let refundService: any RefundService
    let warrantyService: any WarrantyService
    let documentService: any DocumentService
    let resaleService: any ResaleService
    let businessService: any BusinessService
    let leadService: any LeadService
    let opportunityService: any OpportunityService
    let quoteService: any QuoteService
    let customerService: any CustomerService
    let askLoopService: any AskLoopService
    let searchService: any SearchService

    enum Mode {
        /// Real Supabase-backed services.
        case live
        /// Clearly-labelled sample data. Selected only when no backend is configured.
        case sample

        var isSample: Bool { self == .sample }
    }

    /// Builds the environment appropriate for this build's configuration.
    static func resolve() -> AppEnvironment {
        LoopConfiguration.isBackendConfigured ? .live() : .sample()
    }

    static func live() -> AppEnvironment {
        let client = SupabaseRESTClient()
        let purchases = LivePurchaseService(client: client)
        let returns = LiveReturnService(client: client)
        let refunds = LiveRefundService(client: client)
        let warranties = LiveWarrantyService(client: client)
        let documents = LiveDocumentService(client: client)
        let leads = LiveLeadService(client: client)
        let opportunities = LiveOpportunityService(client: client)
        let quotes = LiveQuoteService(client: client)

        return AppEnvironment(
            mode: .live,
            authService: LiveAuthService(client: client),
            accountService: LiveAccountService(client: client),
            todayService: LiveTodayService(client: client),
            moneyService: LiveMoneyService(client: client),
            purchaseService: purchases,
            protectionService: LiveProtectionService(
                client: client,
                purchases: purchases,
                returns: returns,
                refunds: refunds,
                warranties: warranties,
                documents: documents
            ),
            returnService: returns,
            refundService: refunds,
            warrantyService: warranties,
            documentService: documents,
            resaleService: LiveResaleService(client: client, purchases: purchases),
            businessService: LiveBusinessService(
                client: client,
                leads: leads,
                opportunities: opportunities,
                quotes: quotes
            ),
            leadService: leads,
            opportunityService: opportunities,
            quoteService: quotes,
            customerService: LiveCustomerService(client: client),
            askLoopService: LiveAskLoopService(accessTokenProvider: { client?.currentAccessToken }),
            searchService: LiveSearchService(client: client)
        )
    }

    static func sample(store: SampleDataStore = .shared) -> AppEnvironment {
        AppEnvironment(
            mode: .sample,
            authService: SampleAuthService(store: store),
            accountService: SampleAccountService(store: store),
            todayService: SampleTodayService(store: store),
            moneyService: SampleMoneyService(store: store),
            purchaseService: SamplePurchaseService(store: store),
            protectionService: SampleProtectionService(store: store),
            returnService: SampleReturnService(store: store),
            refundService: SampleRefundService(store: store),
            warrantyService: SampleWarrantyService(store: store),
            documentService: SampleDocumentService(store: store),
            resaleService: SampleResaleService(store: store),
            businessService: SampleBusinessService(store: store),
            leadService: SampleLeadService(store: store),
            opportunityService: SampleOpportunityService(store: store),
            quoteService: SampleQuoteService(store: store),
            customerService: SampleCustomerService(store: store),
            askLoopService: SampleAskLoopService(store: store),
            searchService: SampleSearchService(store: store)
        )
    }

    /// Preview convenience — an isolated sample store per preview.
    static var preview: AppEnvironment {
        .sample(store: SampleDataStore())
    }
}

private struct AppEnvironmentKey: @preconcurrency EnvironmentKey {
    @MainActor static let defaultValue: AppEnvironment = .preview
}

extension EnvironmentValues {
    var loop: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
