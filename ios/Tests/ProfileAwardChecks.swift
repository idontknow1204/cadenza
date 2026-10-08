import Foundation

// Run with Models.swift and AppLocalization.swift using swiftc.
@main
struct ProfileAwardChecks {
    static func main() throws {
        precondition(ProfileAward.normalizedLink("  ") == "")
        precondition(ProfileAward.normalizedLink(" example.com/results ") == "https://example.com/results")
        precondition(ProfileAward.normalizedLink("https://example.com/results?id=42") == "https://example.com/results?id=42")
        for invalid in ["javascript:alert(1)", "ftp://example.com", "not a link", "https://", "https://user:secret@example.com"] {
            precondition(ProfileAward.normalizedLink(invalid) == nil, invalid)
        }

        let award = ProfileAward(id: UUID(), userId: UUID(), title: "Competition",
                                 prize: "First prize", issuer: "", year: 2026,
                                 details: "", linkUrl: "")
        let data = try JSONEncoder().encode(award)
        let decoded = try JSONDecoder().decode(ProfileAward.self, from: data)
        precondition(decoded == award)
        let payload = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        // Cleared optional form fields must be sent, not omitted on update.
        for key in ["issuer", "details", "link_url"] {
            precondition(payload[key] as? String == "", key)
        }
        precondition(payload["user_id"] as? String == award.userId.uuidString)
        print("PASS: award URL validation, encoding, and clearing saved fields")
    }
}
