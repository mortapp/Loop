//
//  LOOPApp.swift
//  LOOP
//

import SwiftUI

@main
struct LOOPApp: App {
    @State private var environment: AppEnvironment
    @State private var appState: AppState
    @State private var router = AppRouter()

    init() {
        let resolved = AppEnvironment.resolve()
        _environment = State(initialValue: resolved)
        _appState = State(initialValue: AppState(environment: resolved))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.loop, environment)
                .environment(appState)
                .environment(router)
                .preferredColorScheme(appState.preferences.appearance.colorScheme)
                .tint(LoopColor.accent)
                .onOpenURL { url in
                    handle(url: url)
                }
        }
    }

    private func handle(url: URL) {
        if DeepLinkRouter.isAuthCallback(url) {
            Task { await appState.handleAuthCallback(url: url) }
            return
        }
        guard appState.isSignedIn, let link = DeepLinkRouter.parse(url) else { return }
        router.apply(link)
    }
}
