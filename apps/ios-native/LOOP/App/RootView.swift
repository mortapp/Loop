import SwiftUI

/// Decides what LOOP shows at launch: session check, sign-in, onboarding or the
/// authenticated shell. The app is never revealed before bootstrapping settles.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            LoopColor.canvas.ignoresSafeArea()

            switch appState.authentication {
            case .checkingSession, .authenticating, .bootstrappingAccount:
                LaunchView(phase: appState.authentication)
                    .transition(.opacity)
            case .signedOut:
                SignInView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .onboarding(let profile):
                OnboardingView(profile: profile)
                    .transition(.opacity)
            case .signedIn:
                MainTabView()
                    .transition(.opacity)
            case .failed(let error):
                AuthFailureView(error: error)
                    .transition(.opacity)
            }
        }
        .animation(LoopMotion.gentle, value: appState.authentication)
        .task {
            if case .checkingSession = appState.authentication {
                await appState.bootstrap()
            }
        }
    }
}

/// Launch / bootstrap state with LOOP's mark.
struct LaunchView: View {
    let phase: AuthenticationState

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var message: String {
        switch phase {
        case .authenticating: return "Signing you in…"
        case .bootstrappingAccount: return "Preparing your LOOP…"
        default: return "Loading"
        }
    }

    var body: some View {
        VStack(spacing: LoopSpacing.xl) {
            Spacer()
            LoopMark(size: 76)
                .rotationEffect(.degrees(isAnimating && !reduceMotion ? 360 : 0))
                .animation(
                    reduceMotion ? nil : .linear(duration: 6).repeatForever(autoreverses: false),
                    value: isAnimating
                )
            VStack(spacing: LoopSpacing.xs) {
                Text("LOOP")
                    .font(LoopFont.display(28, weight: .bold))
                    .kerning(6)
                    .foregroundStyle(LoopColor.ink)
                Text(message)
                    .font(LoopFont.footnote)
                    .foregroundStyle(LoopColor.inkSecondary)
            }
            Spacer()
        }
        .onAppear { isAnimating = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("LOOP. \(message)")
    }
}

/// LOOP's mark: a continuous ring with a single crossing.
struct LoopMark: View {
    var size: CGFloat = 44
    var lineWidth: CGFloat?

    var body: some View {
        let stroke = lineWidth ?? size * 0.12
        ZStack {
            Circle()
                .trim(from: 0.02, to: 0.86)
                .stroke(
                    LoopColor.accent,
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(LoopColor.ink)
                .frame(width: stroke * 1.5, height: stroke * 1.5)
                .offset(y: -size / 2)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Authentication failure with a retry path.
struct AuthFailureView: View {
    let error: LoopError
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: LoopSpacing.xl) {
            Spacer()
            LoopErrorState(error: error) {
                Task { await appState.retry() }
            }
            LoopSecondaryButton(title: "Back to sign in") {
                Task { await appState.signOut() }
            }
            .frame(maxWidth: 300)
            Spacer()
        }
        .loopGutter()
    }
}

#Preview("Launch") {
    LaunchView(phase: .bootstrappingAccount)
        .environment(AppState(environment: .preview))
}
