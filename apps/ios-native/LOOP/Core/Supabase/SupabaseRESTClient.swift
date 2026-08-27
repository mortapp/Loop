import Foundation
import OSLog

/// Minimal PostgREST client for Supabase.
///
/// Only the publishable anon key and the caller's user access token are ever
/// sent. Row Level Security on the server is the authorization boundary — the
/// client never assumes it can read another account's rows.
@MainActor
final class SupabaseRESTClient {
    private let baseURL: URL
    private let anonKey: String
    private let session: URLSession
    private var accessToken: String?

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init?(session: URLSession = .shared) {
        guard let url = LoopConfiguration.supabaseURL,
              !LoopConfiguration.supabaseAnonKey.isEmpty else { return nil }
        self.baseURL = url
        self.anonKey = LoopConfiguration.supabaseAnonKey
        self.session = session
    }

    func setAccessToken(_ token: String?) {
        accessToken = token
    }

    var currentAccessToken: String? { accessToken }

    /// GET /rest/v1/{table} with PostgREST query items.
    func select<T: Decodable>(
        _ type: T.Type,
        from table: String,
        query: [URLQueryItem]
    ) async throws -> T {
        var components = URLComponents(
            url: baseURL.appending(path: "rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query
        guard let url = components?.url else { throw LoopError.invalidResponse }
        return try await perform(request(url: url, method: "GET"))
    }

    /// Upsert one row and return the stored representation.
    func upsert<Body: Encodable, T: Decodable>(
        _ body: Body,
        into table: String,
        returning: T.Type
    ) async throws -> T {
        let url = baseURL.appending(path: "rest/v1/\(table)")
        var request = request(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates,return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }


    /// PATCH selected rows and return the stored representation.
    func patch<Body: Encodable, T: Decodable>(
        _ body: Body,
        table: String,
        query: [URLQueryItem],
        returning: T.Type
    ) async throws -> T {
        var components = URLComponents(
            url: baseURL.appending(path: "rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query
        guard let url = components?.url else { throw LoopError.invalidResponse }
        var request = request(url: url, method: "PATCH")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    /// DELETE selected rows. RLS remains the authorization boundary.
    func delete(from table: String, query: [URLQueryItem]) async throws {
        var components = URLComponents(
            url: baseURL.appending(path: "rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query
        guard let url = components?.url else { throw LoopError.invalidResponse }
        var request = request(url: url, method: "DELETE")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        try await performEmpty(request)
    }

    /// Creates a short-lived signed URL for an object in a private bucket.
    func signedStorageURL(bucket: String, path: String, expiresIn: Int = 3600) async throws -> URL {
        let encodedPath = path.split(separator: "/").map {
            String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        let url = baseURL.appending(path: "storage/v1/object/sign/\(bucket)/\(encodedPath)")
        var request = request(url: url, method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["expiresIn": expiresIn])
        let response: SignedStorageResponse = try await perform(request)
        let signed = response.signedURL.hasPrefix("http")
            ? response.signedURL
            : baseURL.appending(path: response.signedURL).absoluteString
        guard let result = URL(string: signed) else { throw LoopError.invalidResponse }
        return result
    }

    /// Updates the current Supabase Auth user's password. This uses only the
    /// current user's bearer token; no admin/service-role credential is needed.
    func updateCurrentUserPassword(_ password: String) async throws {
        let url = baseURL.appending(path: "auth/v1/user")
        var request = request(url: url, method: "PUT")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["password": password])
        try await performEmpty(request)
    }

    /// Calls a Postgres RPC that returns no JSON payload.
    func rpcEmpty<Body: Encodable>(_ name: String, body: Body) async throws {
        let url = baseURL.appending(path: "rest/v1/rpc/\(name)")
        var request = request(url: url, method: "POST")
        request.httpBody = try encoder.encode(body)
        try await performEmpty(request)
    }

    /// Calls a Postgres RPC / Edge Function style endpoint.
    func rpc<Body: Encodable, T: Decodable>(
        _ name: String,
        body: Body,
        returning: T.Type
    ) async throws -> T {
        let url = baseURL.appending(path: "rest/v1/rpc/\(name)")
        var request = request(url: url, method: "POST")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func request(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? anonKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw LoopError.map(error)
        }
        guard let http = response as? HTTPURLResponse else { throw LoopError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                LoopLog.network.error("Decoding failed for \(String(describing: T.self), privacy: .public)")
                throw LoopError.invalidData
            }
        case 401: throw LoopError.unauthorized
        case 403: throw LoopError.forbidden
        case 404: throw LoopError.notFound
        case 500...: throw LoopError.server(message: "LOOP's server had a problem. Please try again.")
        default: throw LoopError.invalidResponse
        }
    }

    private func performEmpty(_ request: URLRequest) async throws {
        let response: URLResponse
        do {
            (_, response) = try await session.data(for: request)
        } catch {
            throw LoopError.map(error)
        }
        guard let http = response as? HTTPURLResponse else { throw LoopError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return
        case 401: throw LoopError.unauthorized
        case 403: throw LoopError.forbidden
        case 404: throw LoopError.notFound
        case 500...: throw LoopError.server(message: "LOOP's server had a problem. Please try again.")
        default: throw LoopError.invalidResponse
        }
    }

    private nonisolated struct SignedStorageResponse: Decodable, Sendable {
        let signedURL: String
    }
}
