import Foundation

/// Public, non-secret client configuration for the production LOOP backend.
///
/// The Supabase URL and publishable key are intentionally safe to ship in a
/// client binary: RLS and authenticated RPCs are the authorization boundary.
/// Privileged credentials (service role, database password, AI provider key,
/// signing material) must never be added here.
nonisolated enum LoopConfiguration {
    private static let productionSupabaseURL = "https://zqalnvfwxmfrnyjcuehq.supabase.co"
    private static let productionSupabasePublishableKey = "sb_publishable_SvQrlpnXBlOPN1cyBL6dQg_lOMHF8Cm"
    private static let productionAPIBaseURL = "https://loop-teal-rho.vercel.app/api"

    /// Supabase project URL (public). A build setting may override this for a
    /// controlled test environment, but production is the safe default.
    static var supabaseURL: URL? {
        URL(string: value(for: "SUPABASE_URL", fallback: productionSupabaseURL))
    }

    /// Supabase publishable key (public, RLS-protected).
    static var supabaseAnonKey: String {
        value(for: "SUPABASE_ANON_KEY", fallback: productionSupabasePublishableKey)
    }

    /// LOOP's own server-side API host. Ask LOOP uses this server so provider
    /// credentials never enter the iOS app.
    static var apiBaseURL: URL? {
        URL(string: value(for: "LOOP_API_BASE_URL", fallback: productionAPIBaseURL))
    }

    /// OAuth callback for the native PKCE browser flow.
    static let oauthRedirectURL = URL(string: "com.loop.app.loop_mobile://login-callback")!
    static let oauthURLScheme = "com.loop.app.loop_mobile"
    static let urlScheme = "loop"

    static var isBackendConfigured: Bool {
        supabaseURL != nil && !supabaseAnonKey.isEmpty
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var versionDescription: String { "Version \(appVersion) (\(buildNumber))" }

    private static func value(for key: String, fallback: String) -> String {
        if let info = Bundle.main.infoDictionary?[key] as? String,
           !info.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return info
        }
        if let environment = ProcessInfo.processInfo.environment[key],
           !environment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return environment
        }
        return fallback
    }
}
