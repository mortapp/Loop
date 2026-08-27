import Foundation
import OSLog
import CryptoKit
import Security

/// Shared plumbing for every live, Supabase-backed service.
///
/// Live services never fall back to fixtures. When the backend is not configured
/// they surface `LoopError.serviceUnavailable`, which the UI renders as a real
/// error state. See `docs/BACKEND_INTEGRATION.md` for the table contract.
@MainActor
class LiveService {
    let client: SupabaseRESTClient?

    init(client: SupabaseRESTClient?) {
        self.client = client
    }

    func requireClient() throws -> SupabaseRESTClient {
        guard let client else {
            throw LoopError.serviceUnavailable(
                "LOOP's backend isn't configured on this build. Add SUPABASE_URL and SUPABASE_ANON_KEY to connect."
            )
        }
        return client
    }

    func accountFilter(_ accountID: UUID, select columns: String = "*") -> [URLQueryItem] {
        [
            URLQueryItem(name: "select", value: columns),
            URLQueryItem(name: "account_id", value: "eq.\(accountID.uuidString.lowercased())")
        ]
    }

    func idFilter(_ id: UUID, accountID: UUID) -> [URLQueryItem] {
        accountFilter(accountID) + [URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")]
    }

    func first<T>(_ values: [T]) throws -> T {
        guard let value = values.first else { throw LoopError.notFound }
        return value
    }
}

// MARK: - Authentication

/// Supabase Auth with browser-based OAuth and a native PKCE exchange.
///
/// The verifier is generated on-device, persisted only in Keychain while the
/// browser flow is in progress, and exchanged directly with Supabase Auth. No
/// Google client secret or Supabase privileged credential is present in the app.
@MainActor
final class LiveAuthService: LiveService, AuthService {
    private let sessionStore = SessionStore()
    private let verifierStore = PKCEVerifierStore()
    private let webSession: OAuthWebSession
    private let urlSession: URLSession

    init(
        client: SupabaseRESTClient?,
        webSession: OAuthWebSession? = nil,
        urlSession: URLSession = .shared
    ) {
        self.webSession = webSession ?? OAuthWebSession()
        self.urlSession = urlSession
        super.init(client: client)
    }

    func restoreSession() async throws -> LoopSession? {
        guard let stored = sessionStore.load() else { return nil }
        if stored.expiresAt.timeIntervalSinceNow <= 60 {
            do {
                let refreshed = try await refreshSession(stored.refreshToken)
                try sessionStore.save(refreshed)
                client?.setAccessToken(refreshed.accessToken)
                return refreshed
            } catch {
                sessionStore.clear()
                client?.setAccessToken(nil)
                return nil
            }
        }
        client?.setAccessToken(stored.accessToken)
        return stored
    }

    func signInWithGoogle() async throws -> LoopSession {
        guard let baseURL = LoopConfiguration.supabaseURL else {
            throw LoopError.serviceUnavailable("LOOP authentication isn't configured on this build.")
        }

        let verifier = Self.makeVerifier()
        let challenge = Self.challenge(for: verifier)
        try verifierStore.save(verifier)

        var components = URLComponents(
            url: baseURL.appending(path: "auth/v1/authorize"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: LoopConfiguration.oauthRedirectURL.absoluteString),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "s256")
        ]
        guard let authorizeURL = components?.url else {
            verifierStore.clear()
            throw LoopError.invalidResponse
        }

        do {
            let callback = try await webSession.start(
                url: authorizeURL,
                callbackScheme: LoopConfiguration.oauthURLScheme
            )
            return try await handleCallback(url: callback)
        } catch {
            verifierStore.clear()
            throw error
        }
    }

    func handleCallback(url: URL) async throws -> LoopSession {
        guard DeepLinkRouter.isAuthCallback(url) else {
            throw LoopError.unauthorized
        }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.queryItems?.contains(where: {
            ["access_token", "refresh_token", "provider_token"].contains($0.name.lowercased())
        }) == true || url.fragment?.contains("access_token=") == true {
            verifierStore.clear()
            throw LoopError.unauthorized
        }
        if let error = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
            ?? components?.queryItems?.first(where: { $0.name == "error" })?.value {
            verifierStore.clear()
            throw LoopError.server(message: Self.safeAuthMessage(error))
        }
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty,
              let verifier = verifierStore.load(),
              !verifier.isEmpty else {
            verifierStore.clear()
            throw LoopError.unauthorized
        }

        defer { verifierStore.clear() }
        let response = try await tokenRequest(
            grantType: "pkce",
            body: ["auth_code": code, "code_verifier": verifier]
        )
        let session = Self.session(from: response)
        try sessionStore.save(session)
        client?.setAccessToken(session.accessToken)
        LoopLog.auth.info("Session established")
        return session
    }

    func signOut() async throws {
        if let stored = sessionStore.load(), let baseURL = LoopConfiguration.supabaseURL {
            var request = URLRequest(url: baseURL.appending(path: "auth/v1/logout"))
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue(LoopConfiguration.supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(stored.accessToken)", forHTTPHeaderField: "Authorization")
            _ = try? await urlSession.data(for: request)
        }
        verifierStore.clear()
        sessionStore.clear()
        client?.setAccessToken(nil)
    }

    private func refreshSession(_ refreshToken: String) async throws -> LoopSession {
        let response = try await tokenRequest(
            grantType: "refresh_token",
            body: ["refresh_token": refreshToken]
        )
        return Self.session(from: response)
    }

    private func tokenRequest(grantType: String, body: [String: String]) async throws -> TokenResponse {
        guard let baseURL = LoopConfiguration.supabaseURL else { throw LoopError.serviceUnavailable("Authentication unavailable.") }
        var components = URLComponents(
            url: baseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "grant_type", value: grantType)]
        guard let url = components?.url else { throw LoopError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue(LoopConfiguration.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw LoopError.map(error)
        }
        guard let http = response as? HTTPURLResponse else { throw LoopError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 400 || http.statusCode == 401 { throw LoopError.unauthorized }
            throw LoopError.server(message: "LOOP couldn't complete sign-in. Please try again.")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let decoded = try? decoder.decode(TokenResponse.self, from: data) else {
            throw LoopError.invalidData
        }
        return decoded
    }

    private static func session(from response: TokenResponse) -> LoopSession {
        LoopSession(
            userID: response.user.id,
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(response.expiresIn)
        )
    }

    private static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess)
        return Data(bytes).base64URLEncodedString()
    }

    private static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func safeAuthMessage(_ raw: String) -> String {
        let lowered = raw.lowercased()
        if lowered.contains("cancel") { return "Google sign-in was cancelled." }
        if lowered.contains("access_denied") || lowered.contains("denied") { return "Google sign-in wasn't approved." }
        return "Google sign-in couldn't be completed. Please try again."
    }

    private nonisolated struct TokenResponse: Decodable, Sendable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: TimeInterval
        let user: AuthUser
    }

    private nonisolated struct AuthUser: Decodable, Sendable {
        let id: UUID
    }
}

private extension Data {
    nonisolated func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

@MainActor
final class LiveAccountService: LiveService, AccountService {
    func loadProfile(session: LoopSession) async throws -> LoopProfile {
        let client = try requireClient()
        let profileRows: [SupabaseBackend.ProfileRow] = try await client.select(
            [SupabaseBackend.ProfileRow].self,
            from: "profiles",
            query: [
                URLQueryItem(name: "select", value: "id,email,display_name,avatar_url,default_mode,created_at,username"),
                URLQueryItem(name: "id", value: "eq.\(session.userID.uuidString.lowercased())")
            ]
        )
        let row = try first(profileRows)
        let accountRows: [SupabaseBackend.AccountRow] = try await client.select(
            [SupabaseBackend.AccountRow].self,
            from: "accounts",
            query: [URLQueryItem(name: "select", value: "id,type,owner_profile_id,business_id,created_at")]
        )
        guard !accountRows.isEmpty else {
            throw LoopError.serviceUnavailable("Your LOOP account hasn't finished server setup yet. Please sign in once from the current LOOP app, then try iOS again.")
        }

        var businessNames: [UUID: String] = [:]
        let businessIDs = accountRows.compactMap(\.businessId)
        if !businessIDs.isEmpty {
            let filter = businessIDs.map { $0.uuidString.lowercased() }.joined(separator: ",")
            let rows: [SupabaseBackend.BusinessRow] = try await client.select(
                [SupabaseBackend.BusinessRow].self,
                from: "businesses",
                query: [
                    URLQueryItem(name: "select", value: "id,name"),
                    URLQueryItem(name: "id", value: "in.(\(filter))")
                ]
            )
            businessNames = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.name) })
        }

        let accounts = accountRows.map { account in
            let kind = LoopAccount.Kind(rawValue: account.type) ?? .personal
            let name: String = if let businessID = account.businessId {
                businessNames[businessID] ?? "Business"
            } else {
                "Personal"
            }
            return LoopAccount(
                id: account.id,
                name: name,
                kind: kind,
                currencyCode: "USD",
                createdAt: SupabaseBackend.date(account.createdAt) ?? Date()
            )
        }

        let activeAccountID = accounts.first(where: { $0.kind == .personal })?.id ?? accounts[0].id
        let user = LoopUser(
            id: row.id,
            displayName: row.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? row.displayName!
                : row.email.split(separator: "@").first.map(String.init) ?? "LOOP User",
            email: row.email,
            username: row.username,
            avatarURL: row.avatarUrl.flatMap(URL.init(string:)),
            createdAt: SupabaseBackend.date(row.createdAt) ?? Date()
        )
        return LoopProfile(
            user: user,
            accounts: accounts,
            activeAccountID: activeAccountID,
            hasCompletedOnboarding: row.displayName?.isEmpty == false && row.username?.isEmpty == false
        )
    }

    func completeOnboarding(
        profile: LoopProfile,
        displayName: String,
        username: String,
        password: String,
        accountName: String
    ) async throws -> LoopProfile {
        let client = try requireClient()
        let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { throw LoopError.validation("Enter your name.") }
        guard cleanedUsername.range(of: #"^[a-z0-9_]{3,20}$"#, options: .regularExpression) != nil else {
            throw LoopError.validation("Username must be 3–20 lowercase letters, numbers, or underscores.")
        }
        guard Self.validPassword(password) else {
            throw LoopError.validation("Password must be at least 12 characters and include uppercase, lowercase, a number, and a symbol.")
        }
        let available: Bool = try await client.rpc(
            "is_username_available",
            body: ["candidate": cleanedUsername],
            returning: Bool.self
        )
        if profile.user.username?.lowercased() != cleanedUsername && !available {
            throw LoopError.validation("That username is already taken.")
        }

        // Auth password first: profile completion must not claim success if Auth
        // did not accept the required credential update.
        try await client.updateCurrentUserPassword(password)

        struct ProfilePatch: Encodable { let displayName: String; let username: String }
        let rows: [SupabaseBackend.ProfileRow] = try await client.patch(
            ProfilePatch(displayName: cleanedName, username: cleanedUsername),
            table: "profiles",
            query: [URLQueryItem(name: "id", value: "eq.\(profile.user.id.uuidString.lowercased())")],
            returning: [SupabaseBackend.ProfileRow].self
        )
        _ = try first(rows)

        var updated = profile
        updated.user.displayName = cleanedName
        updated.user.username = cleanedUsername
        if let index = updated.accounts.firstIndex(where: { $0.id == updated.activeAccountID }),
           updated.accounts[index].kind == .business,
           !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Account rows intentionally have no mutable name. Business names
            // live on public.businesses and are managed by business-owner flows.
            updated.accounts[index].name = accountName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        updated.hasCompletedOnboarding = true
        return updated
    }

    func switchAccount(profile: LoopProfile, to accountID: UUID) async throws -> LoopProfile {
        guard profile.accounts.contains(where: { $0.id == accountID }) else {
            throw LoopError.forbidden
        }
        // Account selection is local UI state. Server authorization remains RLS
        // and every request carries the selected account_id explicitly.
        var updated = profile
        updated.activeAccountID = accountID
        return updated
    }

    private static func validPassword(_ password: String) -> Bool {
        guard password.count >= 12 else { return false }
        let hasLower = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSymbol = password.range(of: #"[^A-Za-z0-9]"#, options: .regularExpression) != nil
        return hasLower && hasUpper && hasDigit && hasSymbol
    }
}

// MARK: - Money

@MainActor
final class LiveMoneyService: LiveService, MoneyService {
    func summary(accountID: UUID) async throws -> MoneySummary {
        let client = try requireClient()
        let totals: [SupabaseBackend.MoneyTotalsRow] = try await client.rpc(
            "account_money_totals",
            body: ["p_account_id": accountID.uuidString.lowercased()],
            returning: [SupabaseBackend.MoneyTotalsRow].self
        )
        let row = try first(totals)
        let transactions = try await transactions(accountID: accountID)
        return MoneySummary(
            netMovement: SupabaseBackend.cents(row.netCents),
            incoming: SupabaseBackend.cents(row.madeCents + row.protectedCents + row.recoveredCents),
            outgoing: SupabaseBackend.cents(row.spentCents + row.feesCents),
            recovered: SupabaseBackend.cents(row.protectedCents),
            businessEarnings: SupabaseBackend.cents(row.madeCents),
            resaleProceeds: SupabaseBackend.cents(row.recoveredCents),
            pendingIncoming: MoneyAmount.sum(
                transactions.filter { $0.status == .pending && $0.direction == .incoming }.map(\.amount)
            ),
            periodLabel: "All time"
        )
    }

    func transactions(accountID: UUID) async throws -> [MoneyTransaction] {
        let rows: [SupabaseBackend.MoneyEventRow] = try await requireClient().select(
            [SupabaseBackend.MoneyEventRow].self,
            from: "money_events",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "occurred_at.desc")]
        )
        return rows.map(Self.map)
    }

    func transaction(id: UUID, accountID: UUID) async throws -> MoneyTransaction {
        let rows: [SupabaseBackend.MoneyEventRow] = try await requireClient().select(
            [SupabaseBackend.MoneyEventRow].self,
            from: "money_events",
            query: idFilter(id, accountID: accountID)
        )
        return Self.map(try first(rows))
    }

    static func map(_ row: SupabaseBackend.MoneyEventRow) -> MoneyTransaction {
        let direction: TransactionDirection = ["spend", "fee"].contains(row.kind) ? .outgoing : .incoming
        let type: MoneyTransactionType
        switch row.kind {
        case "spend": type = .purchase
        case "refund": type = .refund
        case "recovered": type = .resale
        case "fee": type = .fee
        case "earn": type = row.sourceType == "quote" ? .businessIncome : .income
        default: type = .other
        }
        let related: RelatedRecordReference?
        if let sourceID = row.sourceId {
            switch row.sourceType {
            case "purchase": related = .purchase(sourceID)
            case "return": related = .refund(sourceID)
            case "sale": related = .sale(sourceID)
            case "quote": related = .quote(sourceID)
            default: related = nil
            }
        } else {
            related = nil
        }
        return MoneyTransaction(
            id: row.id,
            accountID: row.accountId,
            amount: SupabaseBackend.cents(row.amountCents, currency: row.currency),
            direction: direction,
            type: type,
            title: row.description ?? type.label,
            merchantOrSource: row.sourceType,
            category: row.kind,
            occurredAt: SupabaseBackend.date(row.occurredAt) ?? Date(),
            status: .cleared,
            relatedRecord: related,
            note: nil
        )
    }
}

// MARK: - Purchases

@MainActor
final class LivePurchaseService: LiveService, PurchaseService {
    func purchases(accountID: UUID) async throws -> [Purchase] {
        let client = try requireClient()
        async let purchaseRows: [SupabaseBackend.PurchaseRow] = client.select(
            [SupabaseBackend.PurchaseRow].self,
            from: "purchases",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "purchase_date.desc.nullslast,created_at.desc")]
        )
        async let itemRows: [SupabaseBackend.ItemRow] = client.select(
            [SupabaseBackend.ItemRow].self,
            from: "items",
            query: accountFilter(accountID)
        )
        let (rows, items) = try await (purchaseRows, itemRows)
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return rows.map { Self.mapPurchase($0, item: $0.itemId.flatMap { byID[$0] }) }
    }

    func purchase(id: UUID, accountID: UUID) async throws -> Purchase {
        let client = try requireClient()
        let rows: [SupabaseBackend.PurchaseRow] = try await client.select(
            [SupabaseBackend.PurchaseRow].self,
            from: "purchases",
            query: idFilter(id, accountID: accountID)
        )
        let row = try first(rows)
        let item: SupabaseBackend.ItemRow?
        if let itemID = row.itemId {
            let itemRows: [SupabaseBackend.ItemRow] = try await client.select(
                [SupabaseBackend.ItemRow].self,
                from: "items",
                query: idFilter(itemID, accountID: accountID)
            )
            item = itemRows.first
        } else { item = nil }
        return Self.mapPurchase(row, item: item)
    }

    func create(purchase: Purchase) async throws -> Purchase {
        let cents = try SupabaseBackend.intCents(purchase.amount)
        guard cents >= 0 else { throw LoopError.validation("Purchase amount can't be negative.") }
        struct Body: Encodable {
            let pAccountId: UUID
            let pItemId: UUID?
            let pVendorName: String
            let pPurchaseDate: String
            let pPriceCents: Int64
            let pReturnWindowExpiresAt: String?
            let pWarrantyExpiresAt: String?
        }
        let purchaseID: UUID = try await requireClient().rpc(
            "create_purchase_with_money_event",
            body: Body(
                pAccountId: purchase.accountID,
                pItemId: purchase.ownedItemID,
                pVendorName: purchase.merchant,
                pPurchaseDate: SupabaseBackend.dateOnly.string(from: purchase.purchasedAt),
                pPriceCents: cents,
                pReturnWindowExpiresAt: purchase.returnWindow.map { SupabaseBackend.dateOnly.string(from: $0.deadline) },
                pWarrantyExpiresAt: nil
            ),
            returning: UUID.self
        )
        return try await self.purchase(id: purchaseID, accountID: purchase.accountID)
    }

    func ownedItems(accountID: UUID) async throws -> [OwnedItem] {
        let client = try requireClient()
        async let itemRows: [SupabaseBackend.ItemRow] = client.select([SupabaseBackend.ItemRow].self, from: "items", query: accountFilter(accountID))
        async let purchaseRows: [SupabaseBackend.PurchaseRow] = client.select([SupabaseBackend.PurchaseRow].self, from: "purchases", query: accountFilter(accountID))
        async let valuationRows: [SupabaseBackend.ValuationRow] = client.select([SupabaseBackend.ValuationRow].self, from: "valuations", query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "valued_at.desc")])
        async let returnRows: [SupabaseBackend.ReturnRow] = client.select([SupabaseBackend.ReturnRow].self, from: "returns", query: accountFilter(accountID))
        async let warrantyRows: [SupabaseBackend.WarrantyRow] = client.select([SupabaseBackend.WarrantyRow].self, from: "warranties", query: accountFilter(accountID))
        async let saleRows: [SupabaseBackend.SaleRow] = client.select([SupabaseBackend.SaleRow].self, from: "sales", query: accountFilter(accountID))
        let (items, purchases, valuations, returns, warranties, sales) = try await (itemRows, purchaseRows, valuationRows, returnRows, warrantyRows, saleRows)
        let purchaseByItem = Dictionary(uniqueKeysWithValues: purchases.compactMap { row in row.itemId.map { ($0, row) } })
        let valuationByItem = Dictionary(grouping: valuations, by: \.itemId).compactMapValues(\.first)
        let returnByItem = Dictionary(grouping: returns, by: \.itemId).compactMapValues(\.first)
        let warrantyByItem = Dictionary(grouping: warranties, by: \.itemId).compactMapValues(\.first)
        let saleByItem = Dictionary(grouping: sales, by: \.itemId).compactMapValues(\.first)
        return items.map { row in
            Self.mapItem(
                row,
                purchase: purchaseByItem[row.id],
                valuation: valuationByItem[row.id],
                returnRow: returnByItem[row.id],
                warranty: warrantyByItem[row.id],
                sale: saleByItem[row.id]
            )
        }
    }

    func ownedItem(id: UUID, accountID: UUID) async throws -> OwnedItem {
        guard let item = try await ownedItems(accountID: accountID).first(where: { $0.id == id }) else { throw LoopError.notFound }
        return item
    }

    func update(purchase: Purchase) async throws -> Purchase {
        struct Patch: Encodable {
            let vendorName: String
            let purchaseDate: String
            let returnWindowExpiresAt: String?
        }
        let deadline = purchase.returnWindow.map { SupabaseBackend.dateOnly.string(from: $0.deadline) }
        let patch = Patch(
            vendorName: purchase.merchant,
            purchaseDate: SupabaseBackend.dateOnly.string(from: purchase.purchasedAt),
            returnWindowExpiresAt: deadline
        )
        let rows: [SupabaseBackend.PurchaseRow] = try await requireClient().patch(
            patch,
            table: "purchases",
            query: idFilter(purchase.id, accountID: purchase.accountID),
            returning: [SupabaseBackend.PurchaseRow].self
        )
        let row = try first(rows)
        return Self.mapPurchase(row, item: nil, fallbackName: purchase.itemName)
    }

    func update(ownedItem: OwnedItem) async throws -> OwnedItem {
        struct Patch: Encodable { let name: String; let condition: String }
        let rows: [SupabaseBackend.ItemRow] = try await requireClient().patch(
            Patch(name: ownedItem.name, condition: Self.backendCondition(ownedItem.condition)),
            table: "items",
            query: idFilter(ownedItem.id, accountID: ownedItem.accountID),
            returning: [SupabaseBackend.ItemRow].self
        )
        let row = try first(rows)
        return Self.mapItem(row, purchase: nil, valuation: ownedItem.estimatedResaleValue.map {
            SupabaseBackend.ValuationRow(id: UUID(), accountId: ownedItem.accountID, itemId: ownedItem.id, source: ownedItem.estimateIsUserProvided ? "manual" : "ai", estimatedValueCents: (try? SupabaseBackend.intCents($0)) ?? 0, confidence: nil, valuedAt: ISO8601DateFormatter().string(from: Date()))
        }, returnRow: ownedItem.returnRecordID.map { SupabaseBackend.ReturnRow(id: $0, accountId: ownedItem.accountID, itemId: ownedItem.id, purchaseId: ownedItem.purchaseID, reason: nil, status: "initiated", refundAmountCents: nil, initiatedAt: ISO8601DateFormatter().string(from: Date()), resolvedAt: nil, createdAt: ISO8601DateFormatter().string(from: Date())) }, warranty: ownedItem.warrantyID.map { SupabaseBackend.WarrantyRow(id: $0, accountId: ownedItem.accountID, itemId: ownedItem.id, provider: nil, coverageSummary: nil, startsAt: nil, expiresAt: nil, claimStatus: nil, createdAt: ISO8601DateFormatter().string(from: Date())) }, sale: ownedItem.saleID.map { SupabaseBackend.SaleRow(id: $0, accountId: ownedItem.accountID, itemId: ownedItem.id, listingId: nil, salePriceCents: 0, feesCents: 0, netAmountCents: 0, soldAt: ISO8601DateFormatter().string(from: Date()), createdAt: ISO8601DateFormatter().string(from: Date())) })
    }

    static func mapPurchase(_ row: SupabaseBackend.PurchaseRow, item: SupabaseBackend.ItemRow?, fallbackName: String? = nil) -> Purchase {
        let purchasedAt = SupabaseBackend.date(row.purchaseDate) ?? SupabaseBackend.date(row.createdAt) ?? Date()
        let returnWindow: ReturnWindow?
        if let deadline = SupabaseBackend.date(row.returnWindowExpiresAt) {
            let days = max(Calendar.current.dateComponents([.day], from: purchasedAt, to: deadline).day ?? 0, 0)
            returnWindow = ReturnWindow(purchasedAt: purchasedAt, policyDays: days, policyNote: nil, extendedDeadline: deadline)
        } else { returnWindow = nil }
        return Purchase(
            id: row.id,
            accountID: row.accountId,
            itemName: item?.name ?? fallbackName ?? "Purchase",
            merchant: row.vendorName ?? "Merchant",
            amount: SupabaseBackend.cents(row.priceCents),
            purchasedAt: purchasedAt,
            category: item?.category,
            orderNumber: nil,
            returnWindow: returnWindow,
            note: item?.description,
            transactionID: nil,
            ownedItemID: row.itemId
        )
    }

    static func mapItem(
        _ row: SupabaseBackend.ItemRow,
        purchase: SupabaseBackend.PurchaseRow?,
        valuation: SupabaseBackend.ValuationRow?,
        returnRow: SupabaseBackend.ReturnRow?,
        warranty: SupabaseBackend.WarrantyRow?,
        sale: SupabaseBackend.SaleRow?
    ) -> OwnedItem {
        let purchasedAt = SupabaseBackend.date(purchase?.purchaseDate ?? row.purchaseDate) ?? SupabaseBackend.date(row.createdAt) ?? Date()
        return OwnedItem(
            id: row.id,
            accountID: row.accountId,
            name: row.name,
            merchant: purchase?.vendorName ?? "Merchant",
            purchaseID: purchase?.id,
            purchasedAt: purchasedAt,
            originalPrice: SupabaseBackend.cents(purchase?.priceCents ?? row.purchasePriceCents),
            condition: itemCondition(row.condition),
            estimatedResaleValue: valuation.map { SupabaseBackend.cents($0.estimatedValueCents) },
            estimateIsUserProvided: valuation?.source == "manual",
            warrantyID: warranty?.id,
            returnRecordID: returnRow?.id,
            saleID: sale?.id,
            isMarkedForSale: row.status == "listed",
            note: row.description
        )
    }

    static func itemCondition(_ raw: String?) -> ItemCondition {
        switch raw?.lowercased().replacingOccurrences(of: "_", with: "") {
        case "new": return .new
        case "likenew": return .likeNew
        case "fair": return .fair
        case "poor", "worn": return .poor
        default: return .good
        }
    }

    static func backendCondition(_ condition: ItemCondition) -> String {
        switch condition {
        case .new: return "new"
        case .likeNew: return "like_new"
        case .good: return "good"
        case .fair: return "fair"
        case .poor: return "poor"
        }
    }
}

// MARK: - Protect

@MainActor
final class LiveReturnService: LiveService, ReturnService {
    func returns(accountID: UUID) async throws -> [ReturnRecord] {
        let client = try requireClient()
        async let returnRows: [SupabaseBackend.ReturnRow] = client.select(
            [SupabaseBackend.ReturnRow].self,
            from: "returns",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "initiated_at.desc")]
        )
        async let purchaseRows: [SupabaseBackend.PurchaseRow] = client.select([SupabaseBackend.PurchaseRow].self, from: "purchases", query: accountFilter(accountID))
        async let itemRows: [SupabaseBackend.ItemRow] = client.select([SupabaseBackend.ItemRow].self, from: "items", query: accountFilter(accountID))
        let (rows, purchases, items) = try await (returnRows, purchaseRows, itemRows)
        let purchaseByID = Dictionary(uniqueKeysWithValues: purchases.map { ($0.id, $0) })
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return rows.map { row in Self.map(row, purchase: row.purchaseId.flatMap { purchaseByID[$0] }, item: itemByID[row.itemId]) }
    }

    func returnRecord(id: UUID, accountID: UUID) async throws -> ReturnRecord {
        guard let record = try await returns(accountID: accountID).first(where: { $0.id == id }) else { throw LoopError.notFound }
        return record
    }

    func startReturn(purchaseID: UUID, reason: String, accountID: UUID) async throws -> ReturnRecord {
        let client = try requireClient()
        let purchaseRows: [SupabaseBackend.PurchaseRow] = try await client.select(
            [SupabaseBackend.PurchaseRow].self,
            from: "purchases",
            query: idFilter(purchaseID, accountID: accountID)
        )
        let purchase = try first(purchaseRows)
        guard let itemID = purchase.itemId else {
            throw LoopError.validation("This purchase isn't linked to an owned item yet.")
        }
        struct Body: Encodable {
            let id: UUID
            let accountId: UUID
            let itemId: UUID
            let purchaseId: UUID
            let reason: String?
            let status: String
        }
        let body = Body(
            id: UUID(), accountId: accountID, itemId: itemID, purchaseId: purchaseID,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason,
            status: "initiated"
        )
        let rows: [SupabaseBackend.ReturnRow] = try await client.upsert(body, into: "returns", returning: [SupabaseBackend.ReturnRow].self)
        let itemRows: [SupabaseBackend.ItemRow] = try await client.select([SupabaseBackend.ItemRow].self, from: "items", query: idFilter(itemID, accountID: accountID))
        return Self.map(try first(rows), purchase: purchase, item: itemRows.first)
    }

    func advance(returnID: UUID, to status: ReturnStatus, accountID: UUID) async throws -> ReturnRecord {
        let current = try await returnRecord(id: returnID, accountID: accountID)
        let backendStatus: String
        switch status {
        case .started: backendStatus = "initiated"
        case .shipped: backendStatus = "shipped"
        case .merchantReceived, .refundPending: backendStatus = "received"
        case .rejected: backendStatus = "denied"
        case .refunded:
            throw LoopError.validation("Record the refund amount from the Refund screen so Money stays in sync.")
        case .packaged:
            throw LoopError.validation("LOOP's server doesn't store a separate packaged state. Mark it shipped when it leaves you.")
        case .eligible, .expired, .cancelled:
            throw LoopError.validation("That return state isn't a server-backed transition.")
        }
        struct Patch: Encodable { let status: String }
        let rows: [SupabaseBackend.ReturnRow] = try await requireClient().patch(
            Patch(status: backendStatus),
            table: "returns",
            query: idFilter(returnID, accountID: accountID),
            returning: [SupabaseBackend.ReturnRow].self
        )
        let row = try first(rows)
        var mapped = current
        mapped.status = Self.domainStatus(row.status)
        return mapped
    }

    func update(returnRecord: ReturnRecord) async throws -> ReturnRecord {
        struct Patch: Encodable { let reason: String? }
        let rows: [SupabaseBackend.ReturnRow] = try await requireClient().patch(
            Patch(reason: returnRecord.reason),
            table: "returns",
            query: idFilter(returnRecord.id, accountID: returnRecord.accountID),
            returning: [SupabaseBackend.ReturnRow].self
        )
        let row = try first(rows)
        var updated = returnRecord
        updated.reason = row.reason
        updated.status = Self.domainStatus(row.status)
        return updated
    }

    static func map(_ row: SupabaseBackend.ReturnRow, purchase: SupabaseBackend.PurchaseRow?, item: SupabaseBackend.ItemRow?) -> ReturnRecord {
        let started = SupabaseBackend.date(row.initiatedAt) ?? SupabaseBackend.date(row.createdAt) ?? Date()
        return ReturnRecord(
            id: row.id,
            accountID: row.accountId,
            purchaseID: row.purchaseId ?? purchase?.id ?? UUID(),
            itemName: item?.name ?? "Item",
            merchant: purchase?.vendorName ?? "Merchant",
            status: domainStatus(row.status),
            reason: row.reason,
            startedAt: started,
            deadline: purchase?.returnWindowExpiresAt.flatMap { SupabaseBackend.date($0) },
            carrier: nil,
            trackingNumber: nil,
            shippedAt: row.status == "shipped" ? SupabaseBackend.date(row.initiatedAt) : nil,
            merchantReceivedAt: ["received", "refunded"].contains(row.status) ? (SupabaseBackend.date(row.resolvedAt) ?? Date()) : nil,
            expectedRefund: SupabaseBackend.cents(row.refundAmountCents ?? purchase?.priceCents),
            refundID: row.status == "refunded" ? row.id : nil,
            documentIDs: [],
            note: nil
        )
    }

    static func domainStatus(_ raw: String) -> ReturnStatus {
        switch raw {
        case "initiated": return .started
        case "shipped": return .shipped
        case "received": return .merchantReceived
        case "refunded": return .refunded
        case "denied": return .rejected
        default: return .started
        }
    }
}

@MainActor
final class LiveRefundService: LiveService, RefundService {
    func refunds(accountID: UUID) async throws -> [Refund] {
        let client = try requireClient()
        async let returnRows: [SupabaseBackend.ReturnRow] = client.select([SupabaseBackend.ReturnRow].self, from: "returns", query: accountFilter(accountID))
        async let purchaseRows: [SupabaseBackend.PurchaseRow] = client.select([SupabaseBackend.PurchaseRow].self, from: "purchases", query: accountFilter(accountID))
        async let itemRows: [SupabaseBackend.ItemRow] = client.select([SupabaseBackend.ItemRow].self, from: "items", query: accountFilter(accountID))
        let (returns, purchases, items) = try await (returnRows, purchaseRows, itemRows)
        let purchaseByID = Dictionary(uniqueKeysWithValues: purchases.map { ($0.id, $0) })
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return returns
            .filter { ["received", "refunded"].contains($0.status) || $0.refundAmountCents != nil }
            .map { row in Self.map(row, purchase: row.purchaseId.flatMap { purchaseByID[$0] }, item: itemByID[row.itemId]) }
    }

    func refund(id: UUID, accountID: UUID) async throws -> Refund {
        guard let value = try await refunds(accountID: accountID).first(where: { $0.id == id }) else { throw LoopError.notFound }
        return value
    }

    func markReceived(refundID: UUID, amount: MoneyAmount, accountID: UUID) async throws -> Refund {
        let client = try requireClient()
        let rows: [SupabaseBackend.ReturnRow] = try await client.select(
            [SupabaseBackend.ReturnRow].self,
            from: "returns",
            query: idFilter(refundID, accountID: accountID)
        )
        let row = try first(rows)
        let cents = try SupabaseBackend.intCents(amount)
        guard cents > 0 else { throw LoopError.validation("Refund amount must be greater than zero.") }
        struct Body: Encodable {
            let pAccountId: UUID
            let pReturnId: UUID
            let pItemId: UUID
            let pRefundAmountCents: Int64
        }
        try await client.rpcEmpty(
            "refund_return_with_money_event",
            body: Body(pAccountId: accountID, pReturnId: refundID, pItemId: row.itemId, pRefundAmountCents: cents)
        )
        return try await refund(id: refundID, accountID: accountID)
    }

    func update(refund: Refund) async throws -> Refund {
        if refund.status == .received, let amount = refund.receivedAmount {
            return try await markReceived(refundID: refund.id, amount: amount, accountID: refund.accountID)
        }
        throw LoopError.serviceUnavailable("Refund lifecycle changes are server-controlled. Record the received amount when the refund settles.")
    }

    static func map(_ row: SupabaseBackend.ReturnRow, purchase: SupabaseBackend.PurchaseRow?, item: SupabaseBackend.ItemRow?) -> Refund {
        let expected = SupabaseBackend.cents(row.refundAmountCents ?? purchase?.priceCents)
        return Refund(
            id: row.id,
            accountID: row.accountId,
            merchant: purchase?.vendorName ?? "Merchant",
            itemName: item?.name ?? "Item",
            purchaseID: row.purchaseId,
            returnRecordID: row.id,
            expectedAmount: expected,
            receivedAmount: row.status == "refunded" ? expected : nil,
            status: row.status == "refunded" ? .received : .processing,
            expectedDate: nil,
            receivedDate: SupabaseBackend.date(row.resolvedAt),
            openedAt: SupabaseBackend.date(row.initiatedAt) ?? Date(),
            transactionID: nil,
            note: row.reason
        )
    }
}

@MainActor
final class LiveWarrantyService: LiveService, WarrantyService {
    func warranties(accountID: UUID) async throws -> [Warranty] {
        let client = try requireClient()
        async let warrantyRows: [SupabaseBackend.WarrantyRow] = client.select([SupabaseBackend.WarrantyRow].self, from: "warranties", query: accountFilter(accountID))
        async let itemRows: [SupabaseBackend.ItemRow] = client.select([SupabaseBackend.ItemRow].self, from: "items", query: accountFilter(accountID))
        let (rows, items) = try await (warrantyRows, itemRows)
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        return rows.map { Self.map($0, item: byID[$0.itemId]) }
    }

    func warranty(id: UUID, accountID: UUID) async throws -> Warranty {
        guard let value = try await warranties(accountID: accountID).first(where: { $0.id == id }) else { throw LoopError.notFound }
        return value
    }

    func save(warranty: Warranty) async throws -> Warranty {
        guard let itemID = warranty.ownedItemID else { throw LoopError.validation("Choose an owned item for this warranty.") }
        struct Body: Encodable {
            let id: UUID
            let accountId: UUID
            let itemId: UUID
            let provider: String?
            let coverageSummary: String?
            let startsAt: String?
            let expiresAt: String?
            let claimStatus: String?
        }
        let body = Body(
            id: warranty.id,
            accountId: warranty.accountID,
            itemId: itemID,
            provider: warranty.provider,
            coverageSummary: warranty.note,
            startsAt: SupabaseBackend.dateOnly.string(from: warranty.coverageStart),
            expiresAt: warranty.coverageEnd.map { SupabaseBackend.dateOnly.string(from: $0) },
            claimStatus: nil
        )
        let rows: [SupabaseBackend.WarrantyRow] = try await requireClient().upsert(body, into: "warranties", returning: [SupabaseBackend.WarrantyRow].self)
        return Self.map(try first(rows), item: nil, fallbackName: warranty.itemName)
    }

    func archive(warrantyID: UUID, accountID: UUID) async throws {
        try await requireClient().delete(from: "warranties", query: idFilter(warrantyID, accountID: accountID))
    }

    static func map(_ row: SupabaseBackend.WarrantyRow, item: SupabaseBackend.ItemRow?, fallbackName: String? = nil) -> Warranty {
        let start = SupabaseBackend.date(row.startsAt) ?? SupabaseBackend.date(row.createdAt) ?? Date()
        return Warranty(
            id: row.id,
            accountID: row.accountId,
            ownedItemID: row.itemId,
            itemName: item?.name ?? fallbackName ?? "Item",
            provider: row.provider ?? "Provider",
            kind: .manufacturer,
            coverageStart: start,
            coverageEnd: SupabaseBackend.date(row.expiresAt),
            referenceNumber: nil,
            documentIDs: [],
            note: row.coverageSummary ?? row.claimStatus
        )
    }
}

@MainActor
final class LiveProtectionService: LiveService, ProtectionService {
    private let purchases: PurchaseService
    private let returns: ReturnService
    private let refunds: RefundService
    private let warranties: WarrantyService
    private let documents: DocumentService

    init(
        client: SupabaseRESTClient?,
        purchases: PurchaseService,
        returns: ReturnService,
        refunds: RefundService,
        warranties: WarrantyService,
        documents: DocumentService
    ) {
        self.purchases = purchases
        self.returns = returns
        self.refunds = refunds
        self.warranties = warranties
        self.documents = documents
        super.init(client: client)
    }

    func overview(accountID: UUID) async throws -> ProtectOverview {
        async let purchaseList = purchases.purchases(accountID: accountID)
        async let returnList = returns.returns(accountID: accountID)
        async let refundList = refunds.refunds(accountID: accountID)
        async let warrantyList = warranties.warranties(accountID: accountID)
        async let documentList = documents.documents(accountID: accountID)
        let (allPurchases, allReturns, allRefunds, allWarranties, allDocuments) = try await (purchaseList, returnList, refundList, warrantyList, documentList)
        let receiptTargets = Set(allDocuments.filter { $0.type == .receipt }.map(\.target.id))
        let activeWindows = allPurchases.filter { $0.returnWindow?.isExpired == false }
        let outstanding = allRefunds.filter(\.status.isOutstanding)
        return ProtectOverview(
            activeReturnWindows: activeWindows,
            openReturns: allReturns.filter(\.status.isOpen),
            outstandingRefunds: outstanding,
            expiringWarranties: allWarranties.filter { $0.status == .expiring },
            missingReceipts: activeWindows.filter { !receiptTargets.contains(DocumentAttachmentTarget.purchase($0.id).id) },
            recentlyProtected: allReturns.filter { $0.status == .refunded },
            moneyAtStake: MoneyAmount.sum(outstanding.map(\.expectedAmount)),
            recoveredAllTime: MoneyAmount.sum(allRefunds.filter { $0.status == .received }.map(\.settledAmount))
        )
    }
}

@MainActor
final class LiveDocumentService: LiveService, DocumentService {
    func documents(accountID: UUID) async throws -> [LoopDocument] {
        let rows: [SupabaseBackend.DocumentRow] = try await requireClient().select(
            [SupabaseBackend.DocumentRow].self,
            from: "documents",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "created_at.desc")]
        )
        return rows.compactMap(Self.map)
    }

    func documents(for target: DocumentAttachmentTarget, accountID: UUID) async throws -> [LoopDocument] {
        try await documents(accountID: accountID).filter { $0.target == target }
    }

    func attach(document: LoopDocument) async throws -> LoopDocument {
        guard let storagePath = document.storagePath, !storagePath.isEmpty else {
            throw LoopError.validation("Upload the file before attaching its document record.")
        }
        let relation = Self.relation(document.target)
        struct Body: Encodable {
            let id: UUID
            let accountId: UUID
            let kind: String
            let relatedType: String
            let relatedId: UUID
            let storagePath: String
            let fileName: String
            let sizeBytes: Int?
        }
        let body = Body(
            id: document.id,
            accountId: document.accountID,
            kind: Self.backendKind(document.type),
            relatedType: relation.0,
            relatedId: relation.1,
            storagePath: storagePath,
            fileName: document.filename,
            sizeBytes: document.byteSize
        )
        let rows: [SupabaseBackend.DocumentRow] = try await requireClient().upsert(body, into: "documents", returning: [SupabaseBackend.DocumentRow].self)
        guard let mapped = Self.map(try first(rows)) else { throw LoopError.invalidData }
        return mapped
    }

    func remove(documentID: UUID, accountID: UUID) async throws {
        try await requireClient().delete(from: "documents", query: idFilter(documentID, accountID: accountID))
    }

    func downloadURL(for documentID: UUID, accountID: UUID) async throws -> URL {
        let rows: [SupabaseBackend.DocumentRow] = try await requireClient().select(
            [SupabaseBackend.DocumentRow].self,
            from: "documents",
            query: idFilter(documentID, accountID: accountID)
        )
        let row = try first(rows)
        return try await requireClient().signedStorageURL(bucket: "documents", path: row.storagePath)
    }

    static func map(_ row: SupabaseBackend.DocumentRow) -> LoopDocument? {
        guard let type = domainKind(row.kind),
              let relatedType = row.relatedType,
              let relatedID = row.relatedId,
              let target = target(type: relatedType, id: relatedID) else { return nil }
        return LoopDocument(
            id: row.id,
            accountID: row.accountId,
            type: type,
            filename: row.fileName,
            byteSize: row.sizeBytes.flatMap(Int.init(exactly:)),
            createdAt: SupabaseBackend.date(row.createdAt) ?? Date(),
            target: target,
            storagePath: row.storagePath,
            note: nil
        )
    }

    static func target(type: String, id: UUID) -> DocumentAttachmentTarget? {
        switch type {
        case "purchase": return .purchase(id)
        case "return": return .returnRecord(id)
        case "refund": return .refund(id)
        case "warranty": return .warranty(id)
        case "sale", "listing": return .sale(id)
        case "quote": return .quote(id)
        default: return nil
        }
    }

    static func relation(_ target: DocumentAttachmentTarget) -> (String, UUID) {
        switch target {
        case .purchase(let id): return ("purchase", id)
        case .returnRecord(let id): return ("return", id)
        case .refund(let id): return ("refund", id)
        case .warranty(let id): return ("warranty", id)
        case .sale(let id): return ("sale", id)
        case .quote(let id): return ("quote", id)
        }
    }

    static func domainKind(_ raw: String) -> DocumentType? {
        switch raw {
        case "receipt": return .receipt
        case "invoice": return .invoice
        case "warranty": return .warranty
        case "quote": return .quote
        case "listing", "other": return .other
        default: return .other
        }
    }

    static func backendKind(_ type: DocumentType) -> String {
        switch type {
        case .receipt: return "receipt"
        case .invoice: return "invoice"
        case .warranty: return "warranty"
        case .quote: return "quote"
        default: return "other"
        }
    }
}

// MARK: - Sell

@MainActor
final class LiveResaleService: LiveService, ResaleService {
    private let purchases: PurchaseService

    init(client: SupabaseRESTClient?, purchases: PurchaseService) {
        self.purchases = purchases
        super.init(client: client)
    }

    func summary(accountID: UUID) async throws -> ResaleSummary {
        async let saleList = sales(accountID: accountID)
        async let itemList = purchases.ownedItems(accountID: accountID)
        let (allSales, allItems) = try await (saleList, itemList)
        let saleItemIDs = Set(allSales.filter { $0.status != .cancelled }.map(\.ownedItemID))
        let candidates = allItems
            .filter { !$0.isSold && !saleItemIDs.contains($0.id) && $0.estimatedResaleValue != nil }
            .map {
                ResaleCandidate(
                    item: $0,
                    reason: "Owned for \($0.ageInDays) days",
                    estimate: $0.estimatedResaleValue,
                    estimateIsUserProvided: $0.estimateIsUserProvided
                )
            }
        let sold = allSales.filter { $0.status == .sold }
        return ResaleSummary(
            readyToSell: candidates,
            drafts: allSales.filter { $0.status == .draft },
            listed: allSales.filter { $0.status == .listed },
            pending: allSales.filter { $0.status == .pending },
            sold: sold,
            proceedsThisYear: MoneyAmount.sum(sold.map(\.netProceeds)),
            estimatedPotential: MoneyAmount.sum(candidates.compactMap(\.estimate))
        )
    }

    func sales(accountID: UUID) async throws -> [SaleRecord] {
        let client = try requireClient()
        async let listingRows: [SupabaseBackend.ListingRow] = client.select(
            [SupabaseBackend.ListingRow].self,
            from: "listings",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "created_at.desc")]
        )
        async let saleRows: [SupabaseBackend.SaleRow] = client.select(
            [SupabaseBackend.SaleRow].self,
            from: "sales",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "sold_at.desc")]
        )
        async let itemRows: [SupabaseBackend.ItemRow] = client.select([SupabaseBackend.ItemRow].self, from: "items", query: accountFilter(accountID))
        let (listings, sales, items) = try await (listingRows, saleRows, itemRows)
        let itemByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let completedListingIDs = Set(sales.compactMap(\.listingId))
        let open = listings
            .filter { !completedListingIDs.contains($0.id) && $0.status != "removed" && $0.status != "sold" }
            .map { Self.mapListing($0, item: itemByID[$0.itemId]) }
        let completed = sales.map { Self.mapSale($0, item: itemByID[$0.itemId], listing: $0.listingId.flatMap { id in listings.first(where: { $0.id == id }) }) }
        return (open + completed).sorted { ($0.soldDate ?? $0.listedDate ?? .distantPast) > ($1.soldDate ?? $1.listedDate ?? .distantPast) }
    }

    func sale(id: UUID, accountID: UUID) async throws -> SaleRecord {
        guard let value = try await sales(accountID: accountID).first(where: { $0.id == id }) else { throw LoopError.notFound }
        return value
    }

    func save(sale: SaleRecord) async throws -> SaleRecord {
        let client = try requireClient()
        switch sale.status {
        case .listed, .pending:
            let cents = try SupabaseBackend.intCents(sale.grossAmount)
            struct Body: Encodable {
                let pAccountId: UUID
                let pItemId: UUID
                let pMarketplace: String
                let pListPriceCents: Int64
            }
            let listingID: UUID = try await client.rpc(
                "create_listing_and_mark_item",
                body: Body(
                    pAccountId: sale.accountID,
                    pItemId: sale.ownedItemID,
                    pMarketplace: sale.platform ?? "Manual listing",
                    pListPriceCents: cents
                ),
                returning: UUID.self
            )
            return try await self.sale(id: listingID, accountID: sale.accountID)
        case .sold:
            let gross = try SupabaseBackend.intCents(sale.grossAmount)
            let fees = try SupabaseBackend.intCents(MoneyAmount(sale.fees.value + sale.shippingCost.value, currencyCode: sale.fees.currencyCode))
            struct Body: Encodable {
                let pAccountId: UUID
                let pItemId: UUID
                let pListingId: UUID?
                let pSalePriceCents: Int64
                let pFeesCents: Int64
            }
            let saleID: UUID = try await client.rpc(
                "record_item_sale",
                body: Body(pAccountId: sale.accountID, pItemId: sale.ownedItemID, pListingId: nil, pSalePriceCents: gross, pFeesCents: fees),
                returning: UUID.self
            )
            return try await self.sale(id: saleID, accountID: sale.accountID)
        case .draft:
            throw LoopError.validation("Add a list price and mark this item listed when you're ready. LOOP doesn't fake a marketplace draft publish.")
        case .cancelled:
            throw LoopError.validation("Remove the listing from its detail screen instead of saving a cancelled sale.")
        }
    }

    func markSold(saleID: UUID, accountID: UUID) async throws -> SaleRecord {
        let current = try await sale(id: saleID, accountID: accountID)
        if current.status == .sold { return current }
        guard current.status == .listed || current.status == .pending else {
            throw LoopError.validation("Only a listed item can be recorded as sold.")
        }
        let client = try requireClient()
        let gross = try SupabaseBackend.intCents(current.grossAmount)
        struct Body: Encodable {
            let pAccountId: UUID
            let pItemId: UUID
            let pListingId: UUID?
            let pSalePriceCents: Int64
            let pFeesCents: Int64
        }
        let newID: UUID = try await client.rpc(
            "record_item_sale",
            body: Body(pAccountId: accountID, pItemId: current.ownedItemID, pListingId: saleID, pSalePriceCents: gross, pFeesCents: 0),
            returning: UUID.self
        )
        return try await sale(id: newID, accountID: accountID)
    }

    func markForSale(ownedItemID: UUID, accountID: UUID) async throws -> OwnedItem {
        let item = try await purchases.ownedItem(id: ownedItemID, accountID: accountID)
        guard !item.isSold else { throw LoopError.validation("Sold items can't be listed again.") }
        throw LoopError.validation("Choose a list price before creating a real listing. LOOP won't mark an item listed without one.")
    }

    static func mapListing(_ row: SupabaseBackend.ListingRow, item: SupabaseBackend.ItemRow?) -> SaleRecord {
        SaleRecord(
            id: row.id,
            accountID: row.accountId,
            ownedItemID: row.itemId,
            itemName: item?.name ?? "Item",
            platform: row.marketplace,
            grossAmount: SupabaseBackend.cents(row.listPriceCents),
            fees: .zero,
            shippingCost: .zero,
            listedDate: SupabaseBackend.date(row.publishedAt ?? row.createdAt),
            soldDate: nil,
            status: row.status == "draft" ? .draft : .listed,
            transactionID: nil,
            note: row.listingUrl
        )
    }

    static func mapSale(_ row: SupabaseBackend.SaleRow, item: SupabaseBackend.ItemRow?, listing: SupabaseBackend.ListingRow?) -> SaleRecord {
        SaleRecord(
            id: row.id,
            accountID: row.accountId,
            ownedItemID: row.itemId,
            itemName: item?.name ?? "Item",
            platform: listing?.marketplace,
            grossAmount: SupabaseBackend.cents(row.salePriceCents),
            fees: SupabaseBackend.cents(row.feesCents),
            shippingCost: .zero,
            listedDate: SupabaseBackend.date(listing?.publishedAt ?? listing?.createdAt),
            soldDate: SupabaseBackend.date(row.soldAt),
            status: .sold,
            transactionID: nil,
            note: listing?.listingUrl
        )
    }
}

// MARK: - Business

@MainActor
final class LiveBusinessService: LiveService, BusinessService {
    private let leads: LeadService
    private let opportunities: OpportunityService
    private let quotes: QuoteService

    init(client: SupabaseRESTClient?, leads: LeadService, opportunities: OpportunityService, quotes: QuoteService) {
        self.leads = leads
        self.opportunities = opportunities
        self.quotes = quotes
        super.init(client: client)
    }

    func summary(accountID: UUID) async throws -> BusinessSummary {
        async let leadList = leads.leads(accountID: accountID)
        async let opportunityList = opportunities.opportunities(accountID: accountID)
        async let quoteList = quotes.quotes(accountID: accountID)
        async let earningList = earnings(accountID: accountID)
        let (allLeads, allOpportunities, allQuotes, allEarnings) = try await (leadList, opportunityList, quoteList, earningList)
        let awaiting = allQuotes.filter(\.status.isAwaitingResponse)
        return BusinessSummary(
            newLeads: allLeads.filter { $0.status == .new }.count,
            openLeads: allLeads.filter(\.status.isOpen).count,
            activeOpportunities: allOpportunities.filter(\.stage.isActive).count,
            pipelineValue: MoneyAmount.sum(allOpportunities.filter(\.stage.isActive).map(\.estimatedValue)),
            quotesAwaitingResponse: awaiting.count,
            quotedValue: MoneyAmount.sum(awaiting.map(\.total)),
            wonThisYear: allOpportunities.filter { $0.stage == .won }.count,
            earningsThisYear: MoneyAmount.sum(allEarnings.map(\.amount)),
            nextFollowUps: allLeads.filter { $0.status.isOpen && $0.nextFollowUp != nil }.sorted { ($0.nextFollowUp ?? .distantFuture) < ($1.nextFollowUp ?? .distantFuture) }
        )
    }

    func earnings(accountID: UUID) async throws -> [BusinessEarning] {
        let rows: [SupabaseBackend.MoneyEventRow] = try await requireClient().select(
            [SupabaseBackend.MoneyEventRow].self,
            from: "money_events",
            query: accountFilter(accountID) + [
                URLQueryItem(name: "kind", value: "eq.earn"),
                URLQueryItem(name: "order", value: "occurred_at.desc")
            ]
        )
        return rows.map { row in
            BusinessEarning(
                id: row.id,
                accountID: row.accountId,
                title: row.description ?? "Earning",
                customerID: nil,
                opportunityID: nil,
                quoteID: row.sourceType == "quote" ? row.sourceId : nil,
                amount: SupabaseBackend.cents(row.amountCents, currency: row.currency),
                receivedAt: SupabaseBackend.date(row.occurredAt) ?? Date(),
                source: row.sourceType == "quote" ? .quote : .manual,
                transactionID: row.id,
                note: nil
            )
        }
    }

    func recordEarning(_ earning: BusinessEarning) async throws -> BusinessEarning {
        throw LoopError.serviceUnavailable("Manual earnings are intentionally disabled on this iOS build. Accept a quote so the server creates exactly one Money event.")
    }
}

@MainActor
final class LiveLeadService: LiveService, LeadService {
    func leads(accountID: UUID) async throws -> [Lead] {
        let client = try requireClient()
        async let leadRows: [SupabaseBackend.LeadRow] = client.select([SupabaseBackend.LeadRow].self, from: "leads", query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "created_at.desc")])
        async let contacts: [SupabaseBackend.ContactRow] = client.select([SupabaseBackend.ContactRow].self, from: "contacts", query: accountFilter(accountID))
        let (rows, people) = try await (leadRows, contacts)
        let byID = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0) })
        return rows.map { Self.map($0, contact: $0.contactId.flatMap { byID[$0] }) }
    }

    func lead(id: UUID, accountID: UUID) async throws -> Lead {
        guard let value = try await leads(accountID: accountID).first(where: { $0.id == id }) else { throw LoopError.notFound }
        return value
    }

    func save(lead: Lead) async throws -> Lead {
        struct Body: Encodable {
            let id: UUID
            let accountId: UUID
            let contactId: UUID?
            let source: String
            let status: String
            let notes: String?
        }
        let body = Body(
            id: lead.id,
            accountId: lead.accountID,
            contactId: lead.customerID,
            source: Self.backendSource(lead.source),
            status: Self.backendStatus(lead.status),
            notes: lead.note
        )
        let rows: [SupabaseBackend.LeadRow] = try await requireClient().upsert(body, into: "leads", returning: [SupabaseBackend.LeadRow].self)
        let row = try first(rows)
        return Self.map(row, contact: nil, fallbackName: lead.name)
    }

    func archive(leadID: UUID, accountID: UUID) async throws {
        struct Patch: Encodable { let status: String }
        let _: [SupabaseBackend.LeadRow] = try await requireClient().patch(
            Patch(status: "disqualified"), table: "leads", query: idFilter(leadID, accountID: accountID), returning: [SupabaseBackend.LeadRow].self
        )
    }

    func convertToOpportunity(leadID: UUID, accountID: UUID) async throws -> Opportunity {
        let lead = try await lead(id: leadID, accountID: accountID)
        struct OpportunityBody: Encodable {
            let id: UUID
            let accountId: UUID
            let contactId: UUID?
            let leadId: UUID
            let title: String
            let stage: String
            let estimatedValueCents: Int64?
        }
        let opportunityID = UUID()
        let cents = try lead.estimatedValue.map(SupabaseBackend.intCents)
        let rows: [SupabaseBackend.OpportunityRow] = try await requireClient().upsert(
            OpportunityBody(id: opportunityID, accountId: accountID, contactId: lead.customerID, leadId: leadID, title: lead.name, stage: "new", estimatedValueCents: cents),
            into: "opportunities",
            returning: [SupabaseBackend.OpportunityRow].self
        )
        struct LeadPatch: Encodable { let status: String }
        let _: [SupabaseBackend.LeadRow] = try await requireClient().patch(
            LeadPatch(status: "converted"), table: "leads", query: idFilter(leadID, accountID: accountID), returning: [SupabaseBackend.LeadRow].self
        )
        return LiveOpportunityService.map(try first(rows))
    }

    static func map(_ row: SupabaseBackend.LeadRow, contact: SupabaseBackend.ContactRow?, fallbackName: String? = nil) -> Lead {
        Lead(
            id: row.id,
            accountID: row.accountId,
            name: contact?.displayName ?? fallbackName ?? "Lead",
            contactLabel: contact?.company,
            source: domainSource(row.source),
            status: domainStatus(row.status),
            estimatedValue: nil,
            note: row.notes,
            createdAt: SupabaseBackend.date(row.createdAt) ?? Date(),
            nextFollowUp: nil,
            customerID: row.contactId,
            opportunityID: nil,
            isArchived: row.status == "disqualified"
        )
    }

    static func domainStatus(_ raw: String) -> LeadStatus {
        switch raw {
        case "new": return .new
        case "contacted": return .contacted
        case "qualified": return .qualified
        case "converted": return .converted
        case "disqualified": return .unqualified
        default: return .lost
        }
    }

    static func backendStatus(_ status: LeadStatus) -> String {
        switch status {
        case .new: return "new"
        case .contacted: return "contacted"
        case .qualified: return "qualified"
        case .converted: return "converted"
        case .unqualified, .lost: return "disqualified"
        }
    }

    static func domainSource(_ raw: String?) -> LeadSource {
        switch raw?.lowercased() {
        case "referral": return .referral
        case "website": return .website
        case "social", "social_media", "socialmedia": return .socialMedia
        case "repeat", "repeat_customer": return .repeatCustomer
        case "walk_in", "walk-in": return .walkIn
        default: return .other
        }
    }

    static func backendSource(_ source: LeadSource) -> String { source.rawValue }
}

@MainActor
final class LiveOpportunityService: LiveService, OpportunityService {
    func opportunities(accountID: UUID) async throws -> [Opportunity] {
        let rows: [SupabaseBackend.OpportunityRow] = try await requireClient().select(
            [SupabaseBackend.OpportunityRow].self,
            from: "opportunities",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "created_at.desc")]
        )
        return rows.map(Self.map)
    }

    func opportunity(id: UUID, accountID: UUID) async throws -> Opportunity {
        let rows: [SupabaseBackend.OpportunityRow] = try await requireClient().select([SupabaseBackend.OpportunityRow].self, from: "opportunities", query: idFilter(id, accountID: accountID))
        return Self.map(try first(rows))
    }

    func save(opportunity: Opportunity) async throws -> Opportunity {
        struct Body: Encodable {
            let id: UUID
            let accountId: UUID
            let contactId: UUID?
            let leadId: UUID?
            let title: String
            let stage: String
            let estimatedValueCents: Int64
        }
        let rows: [SupabaseBackend.OpportunityRow] = try await requireClient().upsert(
            Body(id: opportunity.id, accountId: opportunity.accountID, contactId: opportunity.customerID, leadId: opportunity.leadID, title: opportunity.title, stage: Self.backendStage(opportunity.stage), estimatedValueCents: try SupabaseBackend.intCents(opportunity.estimatedValue)),
            into: "opportunities",
            returning: [SupabaseBackend.OpportunityRow].self
        )
        return Self.map(try first(rows))
    }

    func setStage(opportunityID: UUID, stage: OpportunityStage, accountID: UUID) async throws -> Opportunity {
        struct Patch: Encodable { let stage: String }
        let rows: [SupabaseBackend.OpportunityRow] = try await requireClient().patch(
            Patch(stage: Self.backendStage(stage)), table: "opportunities", query: idFilter(opportunityID, accountID: accountID), returning: [SupabaseBackend.OpportunityRow].self
        )
        return Self.map(try first(rows))
    }

    func archive(opportunityID: UUID, accountID: UUID) async throws {
        throw LoopError.serviceUnavailable("LOOP's production schema has no opportunity archive flag. Mark the opportunity Lost instead.")
    }

    static func map(_ row: SupabaseBackend.OpportunityRow) -> Opportunity {
        Opportunity(
            id: row.id,
            accountID: row.accountId,
            title: row.title,
            detail: nil,
            customerID: row.contactId,
            leadID: row.leadId,
            estimatedValue: SupabaseBackend.cents(row.estimatedValueCents),
            stage: domainStage(row.stage),
            expectedCloseDate: nil,
            quoteIDs: [],
            note: nil,
            createdAt: SupabaseBackend.date(row.createdAt) ?? Date(),
            isArchived: false
        )
    }

    static func domainStage(_ raw: String) -> OpportunityStage {
        switch raw {
        case "quoted": return .proposal
        case "negotiating": return .negotiation
        case "won": return .won
        case "lost": return .lost
        default: return .open
        }
    }

    static func backendStage(_ stage: OpportunityStage) -> String {
        switch stage {
        case .open: return "new"
        case .proposal: return "quoted"
        case .negotiation: return "negotiating"
        case .won: return "won"
        case .lost, .cancelled: return "lost"
        }
    }
}

@MainActor
final class LiveQuoteService: LiveService, QuoteService {
    func quotes(accountID: UUID) async throws -> [Quote] {
        let client = try requireClient()
        async let quoteRows: [SupabaseBackend.QuoteRow] = client.select([SupabaseBackend.QuoteRow].self, from: "quotes", query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "created_at.desc")])
        async let lineRows: [SupabaseBackend.QuoteLineRow] = client.select([SupabaseBackend.QuoteLineRow].self, from: "quote_line_items", query: [URLQueryItem(name: "select", value: "*")])
        let (rows, lines) = try await (quoteRows, lineRows)
        let byQuote = Dictionary(grouping: lines, by: \.quoteId)
        return rows.map { Self.map($0, lines: byQuote[$0.id] ?? []) }
    }

    func quote(id: UUID, accountID: UUID) async throws -> Quote {
        guard let value = try await quotes(accountID: accountID).first(where: { $0.id == id }) else { throw LoopError.notFound }
        return value
    }

    func save(quote: Quote) async throws -> Quote {
        guard let contactID = quote.customerID else { throw LoopError.validation("Choose a customer before creating a quote.") }
        guard !quote.lineItems.isEmpty else { throw LoopError.validation("Add at least one quote line.") }
        let subtotal = try SupabaseBackend.intCents(quote.subtotal)
        let tax = try SupabaseBackend.intCents(quote.taxAmount)
        let total = try SupabaseBackend.intCents(quote.total)
        struct Line: Encodable { let description: String; let quantity: Decimal; let unitPriceCents: Int64 }
        struct Body: Encodable {
            let pAccountId: UUID
            let pContactId: UUID
            let pOpportunityId: UUID?
            let pQuoteNumber: String
            let pSubtotalCents: Int64
            let pTaxCents: Int64
            let pTotalCents: Int64
            let pCreatedBy: UUID
            let pLineItems: [Line]
        }
        let lines = try quote.lineItems.map { Line(description: $0.name, quantity: $0.quantity, unitPriceCents: try SupabaseBackend.intCents(MoneyAmount($0.unitPrice, currencyCode: quote.currencyCode))) }
        let profileID = try await currentProfileID(accountID: quote.accountID)
        let newID: UUID = try await requireClient().rpc(
            "create_quote_with_line_items",
            body: Body(pAccountId: quote.accountID, pContactId: contactID, pOpportunityId: quote.opportunityID, pQuoteNumber: quote.reference, pSubtotalCents: subtotal, pTaxCents: tax, pTotalCents: total, pCreatedBy: profileID, pLineItems: lines),
            returning: UUID.self
        )
        return try await self.quote(id: newID, accountID: quote.accountID)
    }

    func setStatus(quoteID: UUID, status: QuoteStatus, accountID: UUID) async throws -> Quote {
        guard status != .cancelled else { throw LoopError.validation("Cancelled isn't a server quote status. Use Declined or Expired.") }
        struct Body: Encodable { let pQuoteId: UUID; let pStatus: String }
        try await requireClient().rpcEmpty(
            "set_quote_status_with_money_event",
            body: Body(pQuoteId: quoteID, pStatus: status.rawValue)
        )
        return try await quote(id: quoteID, accountID: accountID)
    }

    func duplicate(quoteID: UUID, accountID: UUID) async throws -> Quote {
        var original = try await quote(id: quoteID, accountID: accountID)
        original = Quote(
            id: UUID(), accountID: original.accountID, reference: try await nextReference(accountID: accountID), title: original.title,
            customerID: original.customerID, opportunityID: original.opportunityID, lineItems: original.lineItems.map { QuoteLineItem(name: $0.name, detail: $0.detail, quantity: $0.quantity, unitPrice: $0.unitPrice) },
            discount: original.discount, taxRate: original.taxRate, currencyCode: original.currencyCode, status: .draft, issuedAt: Date(), expiresAt: original.expiresAt, respondedAt: nil, note: original.note, isArchived: false
        )
        return try await save(quote: original)
    }

    func archive(quoteID: UUID, accountID: UUID) async throws {
        throw LoopError.serviceUnavailable("LOOP's production quote table has no archive flag. Keep the quote history intact.")
    }

    func nextReference(accountID: UUID) async throws -> String {
        let existing = try await quotes(accountID: accountID)
        let numbers = existing.compactMap { Int($0.reference.split(separator: "-").last.map(String.init) ?? "") }
        return "Q-\((numbers.max() ?? 1000) + 1)"
    }

    private func currentProfileID(accountID: UUID) async throws -> UUID {
        let accounts: [SupabaseBackend.AccountRow] = try await requireClient().select(
            [SupabaseBackend.AccountRow].self,
            from: "accounts",
            query: [URLQueryItem(name: "select", value: "id,type,owner_profile_id,business_id,created_at"), URLQueryItem(name: "id", value: "eq.\(accountID.uuidString.lowercased())")]
        )
        guard let account = accounts.first, let owner = account.ownerProfileId else {
            // Business accounts do not necessarily expose owner_profile_id. The
            // RPC stamps auth.uid() itself, so this argument is compatibility-only.
            return UUID()
        }
        return owner
    }

    static func map(_ row: SupabaseBackend.QuoteRow, lines: [SupabaseBackend.QuoteLineRow]) -> Quote {
        let subtotal = Decimal(row.subtotalCents) / 100
        let tax = Decimal(row.taxCents) / 100
        let taxRate = subtotal > 0 ? tax / subtotal : 0
        let mappedLines = lines.sorted { $0.position < $1.position }.map {
            QuoteLineItem(id: $0.id, name: $0.description, quantity: $0.quantity, unitPrice: Decimal($0.unitPriceCents) / 100)
        }
        return Quote(
            id: row.id,
            accountID: row.accountId,
            reference: row.quoteNumber,
            title: "Quote \(row.quoteNumber)",
            customerID: row.contactId,
            opportunityID: row.opportunityId,
            lineItems: mappedLines,
            discount: 0,
            taxRate: taxRate,
            currencyCode: row.currency,
            status: QuoteStatus(rawValue: row.status) ?? .draft,
            issuedAt: SupabaseBackend.date(row.createdAt) ?? Date(),
            expiresAt: SupabaseBackend.date(row.validUntil),
            respondedAt: SupabaseBackend.date(row.acceptedAt),
            note: nil,
            isArchived: false
        )
    }
}

@MainActor
final class LiveCustomerService: LiveService, CustomerService {
    func customers(accountID: UUID) async throws -> [Customer] {
        let rows: [SupabaseBackend.ContactRow] = try await requireClient().select(
            [SupabaseBackend.ContactRow].self,
            from: "contacts",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "created_at.desc")]
        )
        return rows.map(Self.map)
    }

    func customer(id: UUID, accountID: UUID) async throws -> Customer {
        let rows: [SupabaseBackend.ContactRow] = try await requireClient().select([SupabaseBackend.ContactRow].self, from: "contacts", query: idFilter(id, accountID: accountID))
        return Self.map(try first(rows))
    }

    func save(customer: Customer) async throws -> Customer {
        struct Body: Encodable {
            let id: UUID
            let accountId: UUID
            let displayName: String
            let email: String?
            let phone: String?
            let company: String?
            let notes: String?
        }
        let rows: [SupabaseBackend.ContactRow] = try await requireClient().upsert(
            Body(id: customer.id, accountId: customer.accountID, displayName: customer.name, email: customer.email, phone: customer.phone, company: customer.company, notes: customer.note),
            into: "contacts",
            returning: [SupabaseBackend.ContactRow].self
        )
        return Self.map(try first(rows))
    }

    func archive(customerID: UUID, accountID: UUID) async throws {
        throw LoopError.serviceUnavailable("Contacts are retained because leads, opportunities, quotes, and purchases can reference them.")
    }

    static func map(_ row: SupabaseBackend.ContactRow) -> Customer {
        Customer(
            id: row.id,
            accountID: row.accountId,
            name: row.displayName,
            company: row.company,
            email: row.email,
            phone: row.phone,
            note: row.notes,
            createdAt: SupabaseBackend.date(row.createdAt) ?? Date(),
            isArchived: false
        )
    }
}

// MARK: - Ask LOOP & search

/// Ask LOOP talks only to LOOP's server-side AI routes. Provider credentials
/// remain on Vercel; the iOS client sends the current Supabase user token.
@MainActor
final class LiveAskLoopService: AskLoopService {
    private let session: URLSession
    private let baseURL: URL?
    private var accessTokenProvider: () -> String?

    init(session: URLSession = .shared, accessTokenProvider: @escaping () -> String? = { nil }) {
        self.session = session
        self.baseURL = LoopConfiguration.apiBaseURL
        self.accessTokenProvider = accessTokenProvider
    }

    var isLiveIntelligenceAvailable: Bool { baseURL != nil && accessTokenProvider() != nil }

    func send(message: String, accountID: UUID) async throws -> AskLoopResponse {
        guard let baseURL else {
            throw LoopError.serviceUnavailable("Ask LOOP's server isn't configured on this build.")
        }
        guard let token = accessTokenProvider(), !token.isEmpty else { throw LoopError.unauthorized }
        var request = URLRequest(url: baseURL.appending(path: "ai/chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "accountId": accountID.uuidString.lowercased(),
            "messages": [["role": "user", "content": message]]
        ])

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw LoopError.map(error) }
        guard let http = response as? HTTPURLResponse else { throw LoopError.invalidResponse }
        if http.statusCode == 401 { throw LoopError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = object["error"] as? String,
               !error.isEmpty {
                throw LoopError.server(message: error)
            }
            throw LoopError.server(message: "Ask LOOP couldn't answer that right now.")
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else { throw LoopError.invalidData }
        switch type {
        case "text":
            guard let text = object["text"] as? String else { throw LoopError.invalidData }
            return AskLoopResponse(text: text, references: [], isLiveIntelligence: true)
        case "tool_confirmation", "confirmation":
            return AskLoopResponse(
                text: "LOOP prepared an action that requires explicit confirmation. Use LOOP on the web to review and approve it before anything changes.",
                references: [],
                isLiveIntelligence: true
            )
        case "error":
            throw LoopError.server(message: (object["error"] as? String) ?? "Ask LOOP couldn't answer that right now.")
        default:
            throw LoopError.invalidData
        }
    }
}

@MainActor
final class LiveSearchService: LiveService, SearchService {
    func search(query: String, category: SearchCategory, accountID: UUID) async throws -> [SearchResult] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }
        let client = try requireClient()
        let safeQuery = cleaned
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
        let pattern = "*\(safeQuery)*"
        var results: [SearchResult] = []

        if category == .all || category == .money || category == .protect || category == .sell {
            let items: [SupabaseBackend.ItemRow] = try await client.select(
                [SupabaseBackend.ItemRow].self,
                from: "items",
                query: accountFilter(accountID) + [URLQueryItem(name: "name", value: "ilike.\(pattern)"), URLQueryItem(name: "limit", value: "20")]
            )
            results += items.map {
                SearchResult(id: $0.id, title: $0.name, subtitle: $0.status.capitalized, symbolName: "tag", tone: .neutral, category: .sell, source: .ownedItem($0.id), amount: $0.purchasePriceCents.map { SupabaseBackend.cents($0) })
            }
        }

        if category == .all || category == .business {
            let contacts: [SupabaseBackend.ContactRow] = try await client.select(
                [SupabaseBackend.ContactRow].self,
                from: "contacts",
                query: accountFilter(accountID) + [
                    URLQueryItem(name: "or", value: "(display_name.ilike.\(pattern),company.ilike.\(pattern),email.ilike.\(pattern))"),
                    URLQueryItem(name: "limit", value: "20")
                ]
            )
            let contactResults = contacts.map {
                SearchResult(
                    id: $0.id,
                    title: $0.displayName,
                    subtitle: $0.company ?? $0.email ?? "Contact",
                    symbolName: "person",
                    tone: .neutral,
                    category: .business,
                    source: .customer($0.id),
                    amount: nil
                )
            }
            results += contactResults

            let leads: [SupabaseBackend.LeadRow] = try await client.select(
                [SupabaseBackend.LeadRow].self,
                from: "leads",
                query: accountFilter(accountID) + [
                    URLQueryItem(name: "or", value: "(source.ilike.\(pattern),notes.ilike.\(pattern))"),
                    URLQueryItem(name: "limit", value: "20")
                ]
            )
            let leadResults = leads.map {
                SearchResult(
                    id: $0.id,
                    title: $0.source?.capitalized ?? "Lead",
                    subtitle: $0.status.capitalized,
                    symbolName: "person.badge.plus",
                    tone: .neutral,
                    category: .business,
                    source: .lead($0.id),
                    amount: nil
                )
            }
            results += leadResults

            let opportunities: [SupabaseBackend.OpportunityRow] = try await client.select(
                [SupabaseBackend.OpportunityRow].self,
                from: "opportunities",
                query: accountFilter(accountID) + [URLQueryItem(name: "title", value: "ilike.\(pattern)"), URLQueryItem(name: "limit", value: "20")]
            )
            results += opportunities.map {
                SearchResult(id: $0.id, title: $0.title, subtitle: $0.stage.capitalized, symbolName: "briefcase", tone: .neutral, category: .business, source: .opportunity($0.id), amount: $0.estimatedValueCents.map { SupabaseBackend.cents($0) })
            }
            let quotes: [SupabaseBackend.QuoteRow] = try await client.select(
                [SupabaseBackend.QuoteRow].self,
                from: "quotes",
                query: accountFilter(accountID) + [URLQueryItem(name: "quote_number", value: "ilike.\(pattern)"), URLQueryItem(name: "limit", value: "20")]
            )
            results += quotes.map {
                SearchResult(id: $0.id, title: "Quote \($0.quoteNumber)", subtitle: $0.status.capitalized, symbolName: "doc.plaintext", tone: .neutral, category: .business, source: .quote($0.id), amount: SupabaseBackend.cents($0.totalCents, currency: $0.currency))
            }
        }
        return Array(results.prefix(50))
    }
}

/// Today reads the same server-generated action records used by the Flutter/web
/// clients. The generator is idempotent and RLS-scoped by account.
@MainActor
final class LiveTodayService: LiveService, TodayService {
    func digest(accountID: UUID) async throws -> TodayDigest {
        let client = try requireClient()
        let _: [SupabaseBackend.ActionRow] = try await client.rpc(
            "generate_today_actions",
            body: ["p_account_id": accountID.uuidString.lowercased()],
            returning: [SupabaseBackend.ActionRow].self
        )
        let rows: [SupabaseBackend.ActionRow] = try await client.select(
            [SupabaseBackend.ActionRow].self,
            from: "actions",
            query: accountFilter(accountID) + [URLQueryItem(name: "order", value: "due_at.asc.nullslast,created_at.desc")]
        )
        let actions = rows.compactMap(Self.map)
        let open = actions.filter { !$0.isCompleted }

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let moneyRows: [SupabaseBackend.MoneyEventRow] = try await client.select(
            [SupabaseBackend.MoneyEventRow].self,
            from: "money_events",
            query: accountFilter(accountID) + [
                URLQueryItem(name: "kind", value: "in.(refund,recovered)"),
                URLQueryItem(name: "occurred_at", value: "gte.\(ISO8601DateFormatter().string(from: start))")
            ]
        )
        let recovered = MoneyAmount.sum(moneyRows.map { SupabaseBackend.cents($0.amountCents, currency: $0.currency) })
        return TodayDigest(
            date: Date(),
            needsAttention: open.filter { $0.priority == .urgent },
            dueSoon: open.filter { $0.priority == .high },
            opportunities: open.filter { $0.priority == .normal },
            information: open.filter { $0.priority == .informational },
            recentlyCompleted: actions.filter(\.isCompleted),
            moneyAtStake: .zero,
            recoveredThisMonth: recovered
        )
    }

    func complete(actionID: UUID, accountID: UUID) async throws {
        struct Patch: Encodable { let status: String; let completedAt: Date }
        let _: [SupabaseBackend.ActionRow] = try await requireClient().patch(
            Patch(status: "done", completedAt: Date()),
            table: "actions",
            query: idFilter(actionID, accountID: accountID),
            returning: [SupabaseBackend.ActionRow].self
        )
    }

    func restore(actionID: UUID, accountID: UUID) async throws {
        struct Patch: Encodable { let status: String; let completedAt: Date? }
        let _: [SupabaseBackend.ActionRow] = try await requireClient().patch(
            Patch(status: "open", completedAt: nil),
            table: "actions",
            query: idFilter(actionID, accountID: accountID),
            returning: [SupabaseBackend.ActionRow].self
        )
    }

    static func map(_ row: SupabaseBackend.ActionRow) -> LoopAction? {
        guard let relatedID = row.relatedId else { return nil }
        let type: LoopActionType
        let source: ActionSource
        switch row.type {
        case "quote_follow_up":
            type = .quoteAwaitingResponse; source = .quote(relatedID)
        case "quote_expiring":
            type = .quoteExpiringSoon; source = .quote(relatedID)
        case "return_window_expiring":
            type = .returnWindowClosing; source = .purchase(relatedID)
        case "warranty_expiring":
            type = .warrantyExpiring; source = .warranty(relatedID)
        default:
            switch row.relatedType {
            case "quote": type = .quoteAwaitingResponse; source = .quote(relatedID)
            case "purchase": type = .returnWindowClosing; source = .purchase(relatedID)
            case "warranty": type = .warrantyExpiring; source = .warranty(relatedID)
            default: return nil
            }
        }
        let due = SupabaseBackend.date(row.dueAt)
        let priority: ActionPriority
        if let due {
            let days = LoopDate.daysRemaining(until: due)
            priority = days < 0 ? .urgent : (days <= 2 ? .high : .normal)
        } else { priority = .informational }
        return LoopAction(
            id: row.id,
            accountID: row.accountId,
            type: type,
            title: row.title,
            subtitle: row.description,
            priority: priority,
            dueDate: due,
            amount: nil,
            source: source,
            createdAt: SupabaseBackend.date(row.createdAt) ?? Date(),
            completedAt: row.status == "done" ? (SupabaseBackend.date(row.completedAt) ?? Date()) : nil
        )
    }
}
