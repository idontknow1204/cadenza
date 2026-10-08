import Foundation

@MainActor
private final class ControlledRequest {
    private var continuation: CheckedContinuation<[ActivityWithAuthor], Error>?
    var started: Bool { continuation != nil }

    func fetch() async throws -> [ActivityWithAuthor] {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func complete(_ result: Result<[ActivityWithAuthor], Error>) {
        let pending = continuation!
        continuation = nil
        pending.resume(with: result)
    }

    func waitForStart() async {
        for _ in 0..<10_000 {
            if started { return }
            await Task.yield()
        }
        preconditionFailure("Request did not start")
    }
}

@main
struct FeedStoreChecks {
    @MainActor
    static func main() async {
        let store = FeedStore()
        let first = activity("first")
        let latest = activity("latest")
        await store.refresh { [first] }
        precondition(store.items == [first] && !store.isLoading && store.errorMessage == nil)

        // A committed local post appears immediately and wins over a refresh
        // that began before the mutation.
        let local = activity("local")
        let preMutation = ControlledRequest()
        let preMutationTask = Task { await store.refresh { try await preMutation.fetch() } }
        await preMutation.waitForStart()
        store.upsert(local)
        precondition(store.items.first == local && !store.isLoading)
        preMutation.complete(.success([first]))
        await preMutationTask.value
        precondition(store.items.first == local)

        store.upsert(local)
        precondition(store.items.filter { $0.id == local.id }.count == 1)
        store.remove(id: local.id)
        precondition(!store.items.contains { $0.id == local.id })

        // Cancelling the refresh gesture must not abort the screen-owned request.
        let gestureRequest = ControlledRequest()
        let gesture = Task { await store.refresh { try await gestureRequest.fetch() } }
        await gestureRequest.waitForStart()
        gesture.cancel()
        gestureRequest.complete(.success([latest]))
        await gesture.value
        precondition(store.items == [latest] && store.errorMessage == nil && !store.isLoading)

        // Overlapping requests may finish out of order, even after cancellation.
        let older = ControlledRequest()
        let newer = ControlledRequest()
        let olderTask = Task { await store.refresh { try await older.fetch() } }
        await older.waitForStart()
        let newerTask = Task { await store.refresh { try await newer.fetch() } }
        await newer.waitForStart()
        older.complete(.failure(URLError(.timedOut)))
        await olderTask.value
        precondition(store.isLoading && store.errorMessage == nil && store.items == [latest])
        newer.complete(.success([first]))
        await newerTask.value
        precondition(store.items == [first] && !store.isLoading)

        let stale = ControlledRequest()
        let staleTask = Task { await store.refresh { try await stale.fetch() } }
        await stale.waitForStart()
        await store.refresh { [latest] }
        stale.complete(.success([first]))
        await staleTask.value
        precondition(store.items == [latest] && !store.isLoading)

        // Leaving the screen cancels work and prevents late changes or alerts.
        let leaving = ControlledRequest()
        let leavingTask = Task { await store.refresh { try await leaving.fetch() } }
        await leaving.waitForStart()
        store.cancel()
        precondition(!store.isLoading)
        leaving.complete(.success([first]))
        await leavingTask.value
        precondition(store.items == [latest] && store.errorMessage == nil)

        await store.refresh { throw CancellationError() }
        precondition(store.items == [latest] && store.errorMessage == nil && !store.isLoading)
        await store.refresh { throw URLError(.cancelled) }
        precondition(store.errorMessage == nil && !store.isLoading)

        // Genuine errors remain visible; an unsuccessful refresh preserves the feed.
        await store.refresh { throw URLError(.notConnectedToInternet) }
        precondition(store.items == [latest] && store.errorMessage != nil && !store.isLoading)
        await store.refresh { [first] }
        precondition(store.items == [first] && store.errorMessage == nil && !store.isLoading)
        print("PASS: gesture cancellation, overlapping requests, stale responses, screen exit, genuine errors, and retry")
    }

    private static func activity(_ title: String) -> ActivityWithAuthor {
        ActivityWithAuthor(id: UUID(), userId: UUID(), type: .performance, title: title,
                           activityDate: "2026-09-21", location: nil, role: nil, program: nil,
                           prize: nil, organizer: nil, personalNote: nil, imageUrls: [],
                           verification: .pending, createdAt: nil, author: nil, org: nil, feedReason: nil,
                           linkUrl: nil, linkTitle: nil, linkDescription: nil, linkImageUrl: nil, linkSiteName: nil)
    }
}
