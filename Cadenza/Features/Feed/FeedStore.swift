import Foundation
import Observation

@MainActor
@Observable
final class FeedStore {
    var items: [ActivityWithAuthor] = []
    private(set) var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    func refresh(using fetch: @escaping @MainActor () async throws -> [ActivityWithAuthor]) async {
        loadTask?.cancel()
        let id = UUID()
        requestID = id
        isLoading = true
        errorMessage = nil

        // The screen owns the request, not SwiftUI's transient refresh gesture task.
        // A newer refresh or leaving the screen explicitly cancels this work.
        let task = Task { @MainActor in
            defer {
                if requestID == id {
                    isLoading = false
                    loadTask = nil
                }
            }
            do {
                try Task.checkCancellation()
                let result = try await fetch()
                try Task.checkCancellation()
                guard requestID == id else { return }
                items = result
            } catch {
                guard requestID == id, !Task.isCancelled else { return }
                let networkError = error as NSError
                guard !(error is CancellationError),
                      !(networkError.domain == NSURLErrorDomain && networkError.code == NSURLErrorCancelled)
                else { return }
                errorMessage = error.localizedDescription
            }
        }
        loadTask = task
        await task.value
    }

    func cancel() {
        requestID = UUID()
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}
