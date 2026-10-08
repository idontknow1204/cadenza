import Foundation

struct ActivityDraft: Codable {
    var type: ActivityType = .performance
    var title: String = ""
    var date: Date = .init()
    var location: String = ""
    var role: String = ""
    var program: String = ""
    var prize: String = ""
    var organizer: String = ""
    var visibility: Visibility = .industryFollowers
    var personalNote: String = ""
    var linkInput: String = ""
    var selectedOrgId: UUID? = nil

    private static let key = "com.cadenza.activity_draft"

    static func load() -> ActivityDraft? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ActivityDraft.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: ActivityDraft.key)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty
            && location.isEmpty && role.isEmpty && program.isEmpty
            && prize.isEmpty && organizer.isEmpty && personalNote.isEmpty
            && linkInput.isEmpty
    }
}
