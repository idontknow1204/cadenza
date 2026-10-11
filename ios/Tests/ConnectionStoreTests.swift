import XCTest

@MainActor
final class ConnectionStoreTests: XCTestCase {
    private let me = UUID()
    private let other = UUID()

    private func row(_ status: String, incoming: Bool = true) -> ConnectionRecord {
        ConnectionRecord(followerId: incoming ? other : me, followeeId: incoming ? me : other,
                         status: status, follower: ConnectedProfile(id: other, realName: "Test Musician", instrument: nil, major: nil, avatarUrl: nil))
    }

    func testAcceptedReciprocalRelationshipNeverShowsAsPending() async {
        let rows = [row("pending"), row("accepted", incoming: false)]
        for rows in [rows, Array(rows.reversed())] {
            let store = ConnectionStore(fetch: { _ in Array(rows) }, change: { _, _ in .connected })
            store.reset(for: me)
            await store.refresh()
            XCTAssertEqual(store.status(for: other), .connected)
            XCTAssertTrue(store.pending.isEmpty)
        }
    }

    func testLateRefreshCannotResurrectAcceptedRequest() async {
        var rows = [row("pending")]
        var delayed: CheckedContinuation<[ConnectionRecord], Never>?
        var delayNext = false
        let store = ConnectionStore(fetch: { _ in
            if delayNext {
                delayNext = false
                return await withCheckedContinuation { delayed = $0 }
            }
            return rows
        }, change: { _, _ in
            rows = [self.row("accepted")]
            return .connected
        })
        store.reset(for: me)
        await store.refresh()
        delayNext = true
        let oldRefresh = Task { await store.refresh() }
        while delayed == nil { await Task.yield() }
        let accepted = await store.perform(.accept, with: other)
        XCTAssertTrue(accepted)
        delayed?.resume(returning: [row("pending")])
        await oldRefresh.value
        XCTAssertTrue(store.pending.isEmpty)
        XCTAssertEqual(store.status(for: other), .connected)
    }

    func testFailureKeepsRequestVisibleAndRetrySucceeds() async {
        var rows = [row("pending")]
        var shouldFail = true
        let store = ConnectionStore(fetch: { _ in rows }, change: { _, _ in
            if shouldFail { throw URLError(.notConnectedToInternet) }
            rows = [self.row("accepted")]
            return .connected
        })
        store.reset(for: me)
        await store.refresh()
        let failed = await store.perform(.accept, with: other)
        XCTAssertFalse(failed)
        XCTAssertEqual(store.pending.count, 1)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.updating.isEmpty)
        shouldFail = false
        let retried = await store.perform(.accept, with: other)
        XCTAssertTrue(retried)
        XCTAssertTrue(store.pending.isEmpty)
    }

    func testRealtimeEventSupersedesReadStartedBeforeTheEvent() async {
        var delayed: CheckedContinuation<[ConnectionRecord], Never>?
        var first = true
        let store = ConnectionStore(fetch: { _ in
            if first {
                first = false
                return await withCheckedContinuation { delayed = $0 }
            }
            return [self.row("pending")]
        }, change: { _, _ in .none })
        store.reset(for: me)
        let oldRead = Task { await store.refresh() }
        while delayed == nil { await Task.yield() }
        await store.refresh(force: true)
        delayed?.resume(returning: [])
        await oldRead.value
        XCTAssertEqual(store.pending.count, 1)
        XCTAssertEqual(store.status(for: other), .requestReceived)
    }

    func testDuplicateTapProducesOnlyOneMutation() async {
        var completion: CheckedContinuation<ConnectionStatus, Never>?
        var calls = 0
        let store = ConnectionStore(fetch: { _ in [self.row("pending", incoming: false)] }, change: { _, _ in
            calls += 1
            return await withCheckedContinuation { completion = $0 }
        })
        store.reset(for: me)
        let first = Task { await store.perform(.request, with: other) }
        while completion == nil { await Task.yield() }
        let second = await store.perform(.request, with: other)
        XCTAssertFalse(second)
        XCTAssertEqual(calls, 1)
        completion?.resume(returning: .requestSent)
        let sent = await first.value
        XCTAssertTrue(sent)
        XCTAssertTrue(store.updating.isEmpty)
    }

    func testFailedRefreshPreservesLastConfirmedState() async {
        var shouldFail = false
        let store = ConnectionStore(fetch: { _ in
            if shouldFail { throw URLError(.notConnectedToInternet) }
            return [self.row("pending")]
        }, change: { _, _ in .none })
        store.reset(for: me)
        await store.refresh()
        shouldFail = true
        await store.refresh()
        XCTAssertEqual(store.pending.count, 1)
        XCTAssertTrue(store.refreshFailed)
    }

    func testAcceptImmediatelyUpdatesConnectedCount() async {
        var rows = [row("pending")]
        let store = ConnectionStore(fetch: { _ in rows }, change: { _, _ in
            rows = [self.row("accepted")]
            return .connected
        })
        store.reset(for: me)
        await store.refresh()
        XCTAssertEqual(store.connectedCount, 0)

        let accepted = await store.perform(.accept, with: other)

        XCTAssertTrue(accepted)
        XCTAssertEqual(store.connectedCount, 1)
        XCTAssertEqual(store.status(for: other), .connected)
    }

    func testAccountChangeDiscardsInFlightResult() async {
        var delayed: CheckedContinuation<[ConnectionRecord], Never>?
        let store = ConnectionStore(fetch: { _ in await withCheckedContinuation { delayed = $0 } }, change: { _, _ in .none })
        store.reset(for: me)
        let request = Task { await store.refresh() }
        while delayed == nil { await Task.yield() }
        store.reset(for: UUID())
        delayed?.resume(returning: [row("pending")])
        await request.value
        XCTAssertTrue(store.pending.isEmpty)
        XCTAssertTrue(store.statuses.isEmpty)
        XCTAssertFalse(store.hasLoaded)
    }
}
