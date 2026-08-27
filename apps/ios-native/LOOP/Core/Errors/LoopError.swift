import Foundation

/// Canonical error type surfaced to the LOOP UI layer.
/// Internal/transport errors are mapped into these safe cases before display.
nonisolated enum LoopError: LocalizedError, Equatable, Hashable, Sendable {
    case network
    case offline
    case unauthorized
    case forbidden
    case notFound
    case invalidResponse
    case invalidData
    case serviceUnavailable(String)
    case validation(String)
    case cancelled
    case server(message: String)
    case unknown

    var errorDescription: String? { title }

    /// Short, human title suitable for an error state headline.
    var title: String {
        switch self {
        case .network: return "Connection problem"
        case .offline: return "You're offline"
        case .unauthorized: return "Session expired"
        case .forbidden: return "Not allowed"
        case .notFound: return "Not found"
        case .invalidResponse, .invalidData: return "Unexpected data"
        case .serviceUnavailable: return "Service unavailable"
        case .validation: return "Check this form"
        case .cancelled: return "Cancelled"
        case .server: return "Something went wrong"
        case .unknown: return "Something went wrong"
        }
    }

    /// Longer explanation. Never contains tokens, SQL, or stack traces.
    var message: String {
        switch self {
        case .network:
            return "LOOP couldn't reach the server. Check your connection and try again."
        case .offline:
            return "You appear to be offline. LOOP will refresh once you're connected."
        case .unauthorized:
            return "Please sign in again to continue."
        case .forbidden:
            return "You don't have access to this record."
        case .notFound:
            return "This record no longer exists in your LOOP."
        case .invalidResponse, .invalidData:
            return "LOOP received data it couldn't read. Try again in a moment."
        case .serviceUnavailable(let detail):
            return detail
        case .validation(let detail):
            return detail
        case .cancelled:
            return "That request was cancelled."
        case .server(let message):
            return message
        case .unknown:
            return "An unexpected problem occurred. Please try again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .network, .offline, .server, .unknown, .invalidResponse, .serviceUnavailable:
            return true
        case .unauthorized, .forbidden, .notFound, .invalidData, .validation, .cancelled:
            return false
        }
    }

    var symbolName: String {
        switch self {
        case .network, .offline: return "wifi.exclamationmark"
        case .unauthorized: return "person.badge.key"
        case .forbidden: return "lock"
        case .notFound: return "questionmark.folder"
        case .validation: return "exclamationmark.bubble"
        case .serviceUnavailable: return "bolt.horizontal.circle"
        default: return "exclamationmark.triangle"
        }
    }

    /// Maps any thrown error into a display-safe `LoopError`.
    static func map(_ error: Error) -> LoopError {
        if let loop = error as? LoopError { return loop }
        if error is CancellationError { return .cancelled }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed:
                return .offline
            case NSURLErrorCancelled:
                return .cancelled
            default:
                return .network
            }
        }
        if error is DecodingError { return .invalidData }
        return .unknown
    }
}
