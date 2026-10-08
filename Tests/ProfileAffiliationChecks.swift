import Foundation

// Run with Models.swift and AppLocalization.swift using swiftc.
@main
struct ProfileAffiliationChecks {
    static func main() throws {
        let customSchool = "Independent Conservatory Not In Suggestions"
        let payload = NewAffiliation(
            userId: UUID(),
            institutionName: customSchool,
            courseType: "other",
            enrollmentYear: 2026,
            graduationYear: 2028,
            isCurrent: false
        )

        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        precondition(json["institution_name"] as? String == customSchool)
        precondition(json["is_current"] as? Bool == false)
        precondition(json["graduation_year"] as? Int == 2028)

        print("PASS: custom schools and education status encode without suggestion-list validation")
    }
}
