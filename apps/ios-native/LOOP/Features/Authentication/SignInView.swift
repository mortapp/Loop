import SwiftUI

/// Signed-out state. Sign-in happens in the system browser via OAuth/PKCE.
struct SignInView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.loop) private var loop
    @State private var isWorking = false

    private let promises: [(String, String)] = [
        ("arrow.uturn.backward", "Never miss a return window again"),
        ("arrow.down.left.circle", "Chase refunds until the money lands"),
        ("tag", "Turn what you own back into money"),
        ("briefcase", "Quote work and record what you earn")
    ]

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: LoopSpacing.xl) {
                    Spacer(minLength: proxy.size.height * 0.08)

                    VStack(alignment: .leading, spacing: LoopSpacing.lg) {
                        LoopMark(size: 56)
                        VStack(alignment: .leading, spacing: LoopSpacing.sm) {
                            Text("LOOP")
                                .font(LoopFont.display(44, weight: .bold))
                                .kerning(4)
                                .foregroundStyle(LoopColor.ink)
                            Text("Make it. Buy it. Protect it.\nRecover it. Sell it. Repeat.")
                                .font(LoopFont.display(19, weight: .regular))
                                .foregroundStyle(LoopColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: LoopSpacing.md) {
                        ForEach(promises, id: \.1) { symbol, text in
                            HStack(spacing: LoopSpacing.md) {
                                LoopGlyph(symbol: symbol, tone: .accent, size: 34)
                                Text(text)
                                    .font(LoopFont.callout)
                                    .foregroundStyle(LoopColor.ink)
                                Spacer(minLength: 0)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.vertical, LoopSpacing.sm)

                    Spacer(minLength: LoopSpacing.xl)

                    VStack(spacing: LoopSpacing.md) {
                        LoopButton(
                            title: "Continue with Google",
                            symbol: "globe",
                            isLoading: isWorking
                        ) {
                            isWorking = true
                            Task {
                                await appState.signInWithGoogle()
                                isWorking = false
                            }
                        }
                        Text(loop.mode.isSample
                             ? "This build isn't connected to LOOP's authentication service. Continuing opens a sample account so you can explore every feature."
                             : "LOOP uses your browser to sign in. Your password is never entered inside the app.")
                            .font(LoopFont.caption)
                            .foregroundStyle(LoopColor.inkTertiary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, LoopSpacing.xl)
                }
                .loopGutter()
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        .background(
            LinearGradient(
                colors: [LoopColor.canvas, LoopColor.surfaceSunken],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    SignInView()
        .environment(AppState(environment: .preview))
        .environment(\.loop, .preview)
}
