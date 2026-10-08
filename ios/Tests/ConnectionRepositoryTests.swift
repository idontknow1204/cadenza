import XCTest
import Supabase

private final class ConnectionServer: @unchecked Sendable {
    let me = UUID()
    let them = UUID()
    private let lock = NSLock()
    var outgoing: String?
    var incoming: String?
    var invalidReads = false

    func respond(to request: URLRequest) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems ?? []
        let filters = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value ?? "") })
        switch request.httpMethod {
        case "POST":
            XCTAssertEqual(request.url?.lastPathComponent, "transition_connection")
            var body = request.httpBody ?? Data()
            if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    body.append(contentsOf: buffer.prefix(count))
                }
            }
            let params = try JSONSerialization.jsonObject(with: body) as! [String: String]
            XCTAssertEqual(params["p_other"]?.lowercased(), them.uuidString.lowercased())
            switch params["p_action"] {
            case "request":
                if outgoing == nil && incoming == nil { outgoing = "pending" }
            case "accept":
                if outgoing != "accepted" && incoming != "accepted" {
                    guard incoming == "pending" else { throw URLError(.badServerResponse) }
                    incoming = "accepted"
                }
                if outgoing == "pending" { outgoing = nil }
            case "decline": if incoming == "pending" { incoming = nil }
            case "cancel": if outgoing == "pending" { outgoing = nil }
            case "disconnect": outgoing = nil; incoming = nil
            default: throw URLError(.unsupportedURL)
            }
            let status = outgoing == "accepted" || incoming == "accepted" ? "connected"
                : incoming == "pending" ? "requestReceived" : outgoing == "pending" ? "requestSent" : "none"
            return try JSONEncoder().encode(status)
        case "DELETE":
            XCTAssertEqual(filters["follower_id"]?.lowercased(), "eq.\(me.uuidString.lowercased())")
            XCTAssertEqual(filters["followee_id"]?.lowercased(), "eq.\(them.uuidString.lowercased())")
            XCTAssertEqual(filters["status"], "eq.pending")
            if outgoing == "pending" { outgoing = nil }
            return Data("[]".utf8)
        case "GET":
            if invalidReads { return Data("{}".utf8) }
            let isOutgoing = filters["follower_id"]?.lowercased() == "eq.\(me.uuidString.lowercased())"
            let status = isOutgoing ? outgoing : incoming
            return try JSONSerialization.data(withJSONObject: status.map { [["status": $0]] } ?? [])
        default:
            throw URLError(.unsupportedURL)
        }
    }
}

private final class ConnectionURLProtocol: URLProtocol {
    static var server: ConnectionServer!

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "connection-tests.invalid"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let data = try Self.server.respond(to: request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                           headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}

final class ConnectionRepositoryTests: XCTestCase {
    private func repository(_ server: ConnectionServer) -> Repository {
        ConnectionURLProtocol.server = server
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ConnectionURLProtocol.self]
        let client = SupabaseClient(
            supabaseURL: URL(string: "https://connection-tests.invalid")!,
            supabaseKey: "test-only-key",
            options: .init(global: .init(session: URLSession(configuration: configuration)))
        )
        return Repository(client: client)
    }

    func testSendCancelAndSendAgain() async throws {
        let server = ConnectionServer()
        let repo = repository(server)
        for _ in 0..<2 {
            try await repo.follow(follower: server.me, followee: server.them)
            let sent = try await repo.connectionStatus(me: server.me, them: server.them)
            XCTAssertEqual(sent, .requestSent)
            try await repo.cancelConnectionRequest(from: server.me, to: server.them)
            let cancelled = try await repo.connectionStatus(me: server.me, them: server.them)
            XCTAssertEqual(cancelled, .none)
        }
    }

    func testCancellationPreservesAcceptedConnection() async throws {
        let server = ConnectionServer()
        server.outgoing = "accepted"
        let repo = repository(server)
        try await repo.cancelConnectionRequest(from: server.me, to: server.them)
        let status = try await repo.connectionStatus(me: server.me, them: server.them)
        XCTAssertEqual(status, .connected)
    }

    func testSuggestedConnectionSendCancelAndSendAgain() async throws {
        let server = ConnectionServer()
        let repo = repository(server)
        for _ in 0..<2 {
            try await repo.sendConnectionRequest(from: server.me, to: server.them)
            let sent = try await repo.connectionStatus(me: server.me, them: server.them)
            XCTAssertEqual(sent, .requestSent)
            try await repo.cancelConnectionRequest(from: server.me, to: server.them)
            let cancelled = try await repo.connectionStatus(me: server.me, them: server.them)
            XCTAssertEqual(cancelled, .none)
        }
    }

    func testCancellationPreservesIncomingRequest() async throws {
        let server = ConnectionServer()
        server.outgoing = "pending"
        server.incoming = "pending"
        let repo = repository(server)
        try await repo.cancelConnectionRequest(from: server.me, to: server.them)
        let status = try await repo.connectionStatus(me: server.me, them: server.them)
        XCTAssertEqual(status, .requestReceived)
    }

    func testFailedStatusReadDoesNotBecomeDisconnected() async throws {
        let server = ConnectionServer()
        server.invalidReads = true
        let repo = repository(server)
        do {
            _ = try await repo.connectionStatus(me: server.me, them: server.them)
            XCTFail("A failed status read must not report no connection")
        } catch is DecodingError {
            // Expected: callers retain their prior state and can retry.
        }
    }
}
