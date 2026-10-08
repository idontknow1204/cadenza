import Foundation

@main
struct ProfileSectionChecks {
    static func main() throws {
        let defaults = UserDefaults.standard
        let previousLanguage = defaults.string(forKey: "appLanguage")
        defer {
            if let previousLanguage { defaults.set(previousLanguage, forKey: "appLanguage") }
            else { defaults.removeObject(forKey: "appLanguage") }
        }
        let titles: [String: [String]] = [
            "ko": ["소개", "나의 활동", "경력사항", "학력", "수상 경력", "언어", "CV / 홈페이지", "추천서", "기관 페이지"],
            "en": ["About", "My Activities", "Career", "Education", "Honors & Awards", "Languages", "CV / Website", "Recommendations", "Organization Page"],
            "de": ["Über mich", "Meine Aktivitäten", "Berufserfahrung", "Ausbildung", "Auszeichnungen", "Sprachen", "CV / Webseite", "Empfehlungen", "Organisationsseite"]
        ]
        for language in ["ko", "en", "de", "ko"] {
            defaults.set(language, forKey: "appLanguage")
            precondition(ProfileSection.allCases.map(\.title) == titles[language], language)
        }
        print("PASS: all nine section titles in Korean, English, and German, including language switching")

        var profile = Profile(id: UUID(), realName: "Test Musician", homeCities: [],
                              bio: "Existing biography", defaultVisibility: .public,
                              onboardingComplete: true,
                              visibleSections: ProfileSection.allCases.map(\.rawValue),
                              cvUrl: "https://example.com/cv", websiteUrl: "https://example.com")
        let original = profile
        precondition(Set(ProfileSection.allCases.map(\.rawValue)).count == 9)

        for section in ProfileSection.allCases {
            precondition(profile.showsSection(section))
            profile.visibleSections.removeAll { $0 == section.rawValue }
            precondition(!profile.showsSection(section))
            profile.visibleSections.append(section.rawValue)
            precondition(profile.showsSection(section))
        }

        profile.visibleSections = []
        let hidden = try JSONDecoder().decode(Profile.self, from: JSONEncoder().encode(profile))
        precondition(ProfileSection.allCases.allSatisfy { !hidden.showsSection($0) })
        precondition(hidden.bio == original.bio)
        precondition(hidden.cvUrl == original.cvUrl)
        precondition(hidden.websiteUrl == original.websiteUrl)

        profile.visibleSections = original.visibleSections
        precondition(profile == original)
        print("PASS: all nine sections can be hidden and restored; empty visibility persists without deleting content")
    }
}
