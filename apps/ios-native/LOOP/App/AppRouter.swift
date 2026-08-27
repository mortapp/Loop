import Foundation
import OSLog
import Observation
import SwiftUI

/// Owns the selected tab, one navigation path per tab, and sheet presentation.
@MainActor
@Observable
final class AppRouter {
    var selectedTab: LoopTab = .today
    var paths: [LoopTab: [AppDestination]] = [:]
    var presentedSheet: AppSheet?

    func path(for tab: LoopTab) -> Binding<[AppDestination]> {
        Binding(
            get: { self.paths[tab] ?? [] },
            set: { self.paths[tab] = $0 }
        )
    }

    /// Pushes onto the current tab's stack.
    func push(_ destination: AppDestination) {
        paths[selectedTab, default: []].append(destination)
        LoopLog.navigation.debug("push \(destination.analyticsName, privacy: .public)")
    }

    /// Switches tab if needed, then pushes.
    func navigate(to destination: AppDestination, in tab: LoopTab) {
        if selectedTab != tab { selectedTab = tab }
        paths[tab, default: []].append(destination)
    }

    /// Routes a Today action / Ask LOOP reference to its owning record.
    func open(_ source: ActionSource) {
        navigate(to: source.destination, in: source.owningTab)
    }

    func present(_ sheet: AppSheet) {
        presentedSheet = sheet
    }

    func dismissSheet() {
        presentedSheet = nil
    }

    func popToRoot(_ tab: LoopTab? = nil) {
        let target = tab ?? selectedTab
        paths[target] = []
    }

    func select(_ tab: LoopTab) {
        if selectedTab == tab {
            popToRoot(tab)
        } else {
            selectedTab = tab
        }
    }

    /// Applies a parsed deep link.
    func apply(_ link: LoopDeepLink) {
        switch link {
        case .tab(let tab):
            selectedTab = tab
            popToRoot(tab)
        case .destination(let destination, let tab):
            navigate(to: destination, in: tab)
        case .search:
            present(.search)
        }
    }
}
