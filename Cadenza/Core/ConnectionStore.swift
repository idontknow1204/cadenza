import Foundation
import Observation

enum ConnectionAction: String, Sendable {
    case request, accept, decline, cancel, disconnect
}

struct ConnectionRecord: Decodable, Equatable {
    let followerId: UUID
    let followeeId: UUID
    let status: String
    let follower: ConnectedProfile?

    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id", followeeId = "followee_id", status, follower
    }
}

@MainActor
@Observable
final class ConnectionStore {
    private(set) var userId: UUID?
    private(set) var statuses: [UUID: ConnectionStatus] = [:]
    private(set) var pending: [ConnectedProfile] = []
    private(set) var updating: Set<UUID> = []
    private(set) var hasLoaded = false
    private(set) var refreshFailed = false
    private(set) var revision = 0
    var errorMessage: String?

    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private let fetch: (UUID) async throws -> [ConnectionRecord]
    @ObservationIgnored private let change: (UUID, ConnectionAction) async throws -> ConnectionStatus

    init(fetch: @escaping (UUID) async throws -> [ConnectionRecord],
         change: @escaping (UUID, ConnectionAction) async throws -> ConnectionStatus) {
        self.fetch = fetch
        self.change = change
    }

    func reset(for userId: UUID?) {
        guard self.userId != userId else { return }
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        self.userId = userId
        statuses = [:]
        pending = []
        updating = []
        hasLoaded = false
        refreshFailed = false
        errorMessage = nil
        revision += 1
    }

    func status(for other: UUID) -> ConnectionStatus { statuses[other] ?? .none }

    var connectedCount: Int { statuses.values.filter { $0 == .connected }.count }

    func refresh(force: Bool = false) async {
        guard let userId, updating.isEmpty else { return }
        if force, refreshTask != nil {
            generation += 1
            refreshTask?.cancel()
            refreshTask = nil
        }
        if let refreshTask { await refreshTask.value; return }
        let generation = generation
        // Own the request independently of transient SwiftUI refresh/navigation tasks.
        let task = Task { @MainActor in
            defer { if self.generation == generation { self.refreshTask = nil } }
            do {
                let rows = try await fetch(userId)
                try Task.checkCancellation()
                guard self.generation == generation, self.userId == userId else { return }
                var statuses: [UUID: ConnectionStatus] = [:]
                var people: [UUID: ConnectedProfile] = [:]
                for row in rows where row.followerId == userId || row.followeeId == userId {
                    let other = row.followerId == userId ? row.followeeId : row.followerId
                    if row.status == "accepted" { statuses[other] = .connected }
                    else if statuses[other] != .connected {
                        if row.followeeId == userId { statuses[other] = .requestReceived }
                        else if statuses[other] != .requestReceived { statuses[other] = .requestSent }
                    }
                    if let person = row.follower, row.followeeId == userId { people[other] = person }
                }
                let pending = people.values.filter { statuses[$0.id] == .requestReceived }
                    .sorted { $0.id.uuidString < $1.id.uuidString }
                if self.statuses != statuses || self.pending != pending || !self.hasLoaded {
                    self.statuses = statuses
                    self.pending = pending
                    self.revision += 1
                }
                self.hasLoaded = true
                self.refreshFailed = false
            } catch {
                if self.generation == generation, !Task.isCancelled { self.refreshFailed = true }
            }
        }
        refreshTask = task
        await task.value
    }

    @discardableResult
    func perform(_ action: ConnectionAction, with other: UUID) async -> Bool {
        guard let userId, other != userId, !updating.contains(other) else { return false }
        generation += 1
        refreshTask?.cancel()
        refreshTask = nil
        updating.insert(other)
        errorMessage = nil
        var succeeded = false
        do {
            let status = try await change(other, action)
            guard self.userId == userId else { return false }
            statuses[other] = status
            if status != .requestReceived { pending.removeAll { $0.id == other } }
            revision += 1
            succeeded = true
        } catch {
            guard self.userId == userId else { return false }
            errorMessage = localized("연결 상태를 변경하지 못했습니다. 요청이 취소되었거나 네트워크에 문제가 있을 수 있습니다. 다시 확인해 주세요.",
                                     "Unable to update the connection. The request may have been withdrawn or the network is unavailable. Please try again.",
                                     "Die Verbindung konnte nicht geändert werden. Die Anfrage wurde möglicherweise zurückgezogen oder das Netzwerk ist nicht verfügbar. Bitte versuche es erneut.")
        }
        updating.remove(other)
        generation += 1
        await refresh()
        return succeeded
    }
}
