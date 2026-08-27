import Foundation
import OSLog

/// Structured, privacy-safe logging.
/// Never pass tokens, session data, or raw financial detail into these APIs.
nonisolated enum LoopLog {
    private static let subsystem = "app.rork.loop"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let auth = Logger(subsystem: subsystem, category: "auth")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let data = Logger(subsystem: subsystem, category: "data")
    static let navigation = Logger(subsystem: subsystem, category: "navigation")

    /// Logs a failure with a redacted, developer-facing summary.
    static func failure(_ logger: Logger, _ context: String, _ error: Error) {
        let mapped = LoopError.map(error)
        logger.error("\(context, privacy: .public) failed: \(mapped.title, privacy: .public)")
    }
}
