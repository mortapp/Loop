import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    private(set) var state: LoadState<TodayDigest> = .idle
    private(set) var isRefreshing = false

    private let service: any TodayService
    private let accountID: UUID
    private let density: LoopPreferences.ActionDensity

    init(service: any TodayService, accountID: UUID, density: LoopPreferences.ActionDensity) {
        self.service = service
        self.accountID = accountID
        self.density = density
    }

    func load() async {
        if state.value == nil { state = .loading }
        await fetch()
    }

    func refresh() async {
        isRefreshing = true
        await fetch()
        isRefreshing = false
    }

    private func fetch() async {
        do {
            let digest = try await service.digest(accountID: accountID)
            state = .loaded(filtered(digest))
        } catch {
            LoopLog.failure(LoopLog.data, "today digest", error)
            state = .failed(LoopError.map(error))
        }
    }

    func complete(_ action: LoopAction) async {
        LoopHaptics.success()
        do {
            try await service.complete(actionID: action.id, accountID: accountID)
            await fetch()
        } catch {
            LoopLog.failure(LoopLog.data, "complete action", error)
        }
    }

    func restore(_ action: LoopAction) async {
        do {
            try await service.restore(actionID: action.id, accountID: accountID)
            await fetch()
        } catch {
            LoopLog.failure(LoopLog.data, "restore action", error)
        }
    }

    /// Applies the user's Today density preference.
    private func filtered(_ digest: TodayDigest) -> TodayDigest {
        let allowed = density.includedPriorities
        var copy = digest
        if !allowed.contains(.normal) { copy.opportunities = [] }
        if !allowed.contains(.informational) { copy.information = [] }
        return copy
    }
}
