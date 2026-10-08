import XCTest
@testable import CadenzaJobsPreview

final class JobFilterTests: XCTestCase {
    func testOpenFilterExcludesExpiredClosedAnnouncedAndInactive() {
        let open = Fixtures.job(title: "Today", days: 0)
        let ongoing = Fixtures.job(title: "Ongoing", days: nil)
        let others = [Fixtures.job(title: "Expired", days: -1),
                      Fixtures.job(title: "Closed", status: "closed"),
                      Fixtures.job(title: "Upcoming", status: "announced"),
                      Fixtures.job(title: "Inactive", active: false)]
        let jobs = [open, ongoing] + others
        XCTAssertEqual(JobFilter().apply(to: jobs, cityByID: [:]).map(\.id), [open.id, ongoing.id])
        var filter = JobFilter()
        filter.openOnly = false
        XCTAssertEqual(filter.apply(to: jobs, cityByID: [:]).count, jobs.count)
    }

    func testCombinedFiltersAndUnknownFee() {
        let free = Fixtures.job(title: "Free", video: true, fee: 0)
        let unknown = Fixtures.job(title: "Unknown", video: true)
        let paid = Fixtures.job(title: "Paid", video: true, fee: 25)
        var filter = JobFilter()
        filter.instruments = ["바이올린"]
        filter.countryCodes = ["DE"]
        filter.videoOnly = true
        filter.freeOnly = true
        XCTAssertEqual(filter.apply(to: [free, unknown, paid], cityByID: ["berlin": Fixtures.city]).map(\.id), [free.id])
        filter.instruments = ["첼로"]
        XCTAssertTrue(filter.apply(to: [free], cityByID: ["berlin": Fixtures.city]).isEmpty)
    }
}
