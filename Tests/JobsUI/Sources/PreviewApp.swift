import SwiftUI

@main
struct JobsPreviewApp: App {
    @State private var session = SessionStore()
    init() {
        UserDefaults.standard.set(ProcessInfo.processInfo.environment["PREVIEW_LANGUAGE"] ?? "ko", forKey: "appLanguage")
    }
    var body: some Scene {
        WindowGroup {
            TabView {
                JobsView().tabItem { Label("채용", systemImage: "briefcase") }
            }
            .environment(session)
            .progressViewStyle(CadenzaProgressViewStyle())
            .preferredColorScheme(ProcessInfo.processInfo.environment["PREVIEW_DARK"] == "1" ? .dark : .light)
        }
    }
}

@MainActor @Observable
final class SessionStore {
    let repo = PreviewRepository()
    let currentUserID: UUID? = UUID(uuidString: "11111111-1111-1111-1111-111111111111")
    var profile: Profile? = Profile(id: UUID(), realName: "Preview", instrument: "바이올린", homeCities: [],
                                   bio: nil, defaultVisibility: .public, onboardingComplete: true, visibleSections: [])
}

struct PreviewRepository {
    func jobs() async throws -> [Job] { Fixtures.jobs }
    func cities() async throws -> [City] { [Fixtures.city] }
    func baseCityIDs(userId: UUID) async throws -> [String] { ["berlin"] }
    func searchOpportunities(query: String) async throws -> [Job] {
        // Deliberately completes out of order, even when the original task is cancelled.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + (query == "slow" ? 1.5 : 0.1)) {
                continuation.resume()
            }
        }
        if query == "error" { throw URLError(.notConnectedToInternet) }
        if query == "slow" { return [Fixtures.jobs[1]] }
        return Fixtures.jobs.filter {
            $0.title.localizedCaseInsensitiveContains(query)
            || ($0.organization?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    func postJob(_ job: NewJob) async throws {}
    func closeJob(id: UUID) async throws {}
}

enum Fixtures {
    static let city = City(id: "berlin", nameEn: "Berlin", nameLocal: "Berlin", nameKo: "베를린", countryCode: "DE", zone: nil)
    static func job(title: String, instrument: String = "바이올린", days: Int? = 5,
                    status: String = "open", active: Bool = true, video: Bool = false,
                    fee: Double? = nil) -> Job {
        var data: [String: Any] = [
            "id": UUID().uuidString, "user_id": "11111111-1111-1111-1111-111111111111",
            "type": "audition", "title": title, "organization": "Cadenza Chamber Orchestra",
            "location": "Berlin, Germany", "city_id": "berlin", "instruments": [instrument],
            "description": "함께 무대를 만들어 갈 음악가를 기다립니다. 자유곡 두 곡과 오케스트라 발췌곡을 준비해 주세요.",
            "requirements": "지원 악기 전공자 또는 이에 준하는 연주 경력", "contact": "auditions@example.com",
            "is_active": active, "created_at": "2026-09-23T10:00:00Z", "status": status,
            "video_audition": video, "has_scholarship": video
        ]
        if let days {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            data["deadline"] = formatter.string(from: Calendar.current.date(byAdding: .day, value: days, to: Date())!)
        }
        if let fee { data["application_fee"] = fee }
        return try! JSONDecoder().decode(Job.self, from: JSONSerialization.data(withJSONObject: data))
    }
    static let jobs = [
        job(title: "바이올린 정단원 오디션", days: 2, video: true, fee: 0),
        job(title: "첼로 수석 단원 모집", instrument: "첼로", days: 7),
        job(title: "실내악 프로젝트 바이올린 연주자 모집", days: nil),
        job(title: "지난 오디션", days: -1),
        job(title: "모집 예정 오디션", days: 30, status: "announced")
    ]
}
