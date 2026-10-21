import Foundation

// MARK: - Job

// TAXONOMY PLAN (기회 아카이브 §7) — decided direction, deferred implementation.
//
// The plan's 8 categories mix two axes: opportunity *kind* (콩쿠르/마스터클래스/
// 입시/교수직) and organization *type* (오케스트라/앙상블/아카데미/페스티벌).
// Users filter almost entirely by the former; the latter already lives in the
// `organization` field. So the agreed direction is a SINGLE enriched `type`
// enum (no second axis, no new table), extended additively via
// `ALTER TYPE job_type ADD VALUE` when curated data actually lands:
//     audition · position · competition · masterclass · admission · faculty · lesson · gig
// If org-type filtering ever proves necessary, add one `org_type` attribute —
// not a parallel taxonomy. Intentionally NOT expanded yet: with only demo data,
// naming/count can't be pinned down without seeing real opportunities.
enum JobType: String, Codable, CaseIterable, Identifiable {
    case audition, position, lesson, gig
    var id: String { rawValue }
    var label: String {
        switch self {
        case .audition: return localized("오디션", "Audition", "Vorspiel")
        case .position: return localized("단원 모집", "Position", "Stelle")
        case .lesson:   return localized("레슨", "Lesson", "Unterricht")
        case .gig:      return localized("연주 의뢰", "Gig", "Engagement")
        }
    }
    var symbol: String {
        switch self {
        case .audition: return "music.mic"
        case .position: return "building.2"
        case .lesson:   return "graduationcap"
        case .gig:      return "music.note.list"
        }
    }
}

struct Job: Identifiable, Codable {
    let id: UUID
    let userId: UUID?
    let type: JobType
    let title: String
    let organization: String?
    let location: String?
    let instruments: [String]
    let description: String
    let requirements: String?
    let deadline: String?
    let contact: String?
    let isActive: Bool
    let createdAt: String
    let poster: ProfileLite?

    // ── Opportunity archive fields (0027) — all optional so user posts decode fine
    let source: String?          // "user" | "curated"
    let cityId: String?          // references city.id (slug)
    let zone: String?            // "Z1" … derived from city
    let eventStart: String?
    let eventEnd: String?
    let videoAudition: Bool?     // 영상 예선 가능 (§6/§7)
    let applicationFee: Double?  // nil = 미상, 0 = 무료
    let hasScholarship: Bool?
    let ageMin: Int?
    let ageMax: Int?
    let status: String?          // "open" | "announced" | "closed"
    let sourceURL: String?
    let applicationURL: String?
    let sourceLanguage: String?
    let lastSeenAt: String?
    let qualityScore: Double?

    var isCurated: Bool { source == "curated" }

    var isAcceptingApplications: Bool {
        isActive && (status ?? "open") == "open" && (daysLeft.map { $0 >= 0 } ?? true)
    }

    var daysLeft: Int? {
        guard let deadline else { return nil }
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: deadline) else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: date)
        ).day
    }

    var deadlineLabel: String? {
        guard let d = daysLeft else { return nil }
        if d < 0  { return localized("마감", "Closed", "Beendet") }
        if d == 0 { return "D-Day" }
        return "D-\(d)"
    }

    enum CodingKeys: String, CodingKey {
        case id, type, title, organization, location, instruments
        case description, requirements, deadline, contact
        case userId = "user_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case poster
        case source, zone, status
        case cityId = "city_id"
        case eventStart = "event_start"
        case eventEnd = "event_end"
        case videoAudition = "video_audition"
        case applicationFee = "application_fee"
        case hasScholarship = "has_scholarship"
        case ageMin = "age_min"
        case ageMax = "age_max"
        case sourceURL = "source_url"
        case applicationURL = "application_url"
        case sourceLanguage = "source_language"
        case lastSeenAt = "last_seen_at"
        case qualityScore = "quality_score"
    }
}

// MARK: - City (opportunity archive)

struct City: Codable, Identifiable, Hashable {
    let id: String            // slug, e.g. "berlin"
    let nameEn: String
    let nameLocal: String?
    let nameKo: String?
    let countryCode: String
    let zone: String?

    /// Display name for the current in-app language.
    var localizedName: String {
        localized(nameKo ?? nameEn, nameEn, nameLocal ?? nameEn)
    }

    enum CodingKeys: String, CodingKey {
        case id, zone
        case nameEn = "name_en"
        case nameLocal = "name_local"
        case nameKo = "name_ko"
        case countryCode = "country_code"
    }
}

struct NewJob: Encodable {
    let userId: UUID
    let type: String
    let title: String
    let organization: String?
    let location: String?
    let instruments: [String]
    let description: String
    let requirements: String?
    let deadline: String?
    let contact: String?
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type, title, organization, location, instruments
        case description, requirements, deadline, contact
    }
}

// MARK: - Organization

enum OrgCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case orchestra, school, label, venue, agency, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .orchestra: return "오케스트라/앙상블"
        case .school:    return "음악학교/대학교"
        case .label:     return "음반사/레이블"
        case .venue:     return "공연장"
        case .agency:    return "에이전시/프로덕션"
        case .other:     return "기타"
        }
    }
    var symbol: String {
        switch self {
        case .orchestra: return "music.note.list"
        case .school:    return "graduationcap"
        case .label:     return "opticaldisc"
        case .venue:     return "building.2"
        case .agency:    return "person.2.badge.gearshape"
        case .other:     return "building"
        }
    }
}

struct OrgSummary: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let logoUrl: String?
    let category: OrgCategory?
    enum CodingKeys: String, CodingKey {
        case id; case name
        case logoUrl = "logo_url"
        case category
    }
}

struct Organization: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var handle: String
    var description: String?
    var logoUrl: String?
    var website: String?
    var category: OrgCategory
    let createdBy: UUID?
    enum CodingKeys: String, CodingKey {
        case id; case name; case handle; case description
        case logoUrl = "logo_url"; case website; case category
        case createdBy = "created_by"
    }
}

// MARK: - Enums

enum ActivityType: String, Codable, CaseIterable, Identifiable, Hashable {
    case performance, competition, education, recording
    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .performance: return "activity.type.performance"
        case .competition: return "activity.type.competition"
        case .education:   return "activity.type.education"
        case .recording:   return "activity.type.recording"
        }
    }
    var localizedLabel: String {
        switch self {
        case .performance: return localized("연주", "Performance", "Auftritt")
        case .competition: return localized("경연", "Competition", "Wettbewerb")
        case .education:   return localized("교육", "Education", "Ausbildung")
        case .recording:   return localized("음반/미디어", "Recording", "Aufnahme")
        }
    }
    var symbol: String {
        switch self {
        case .performance: return "music.note"
        case .competition: return "trophy"
        case .education:   return "graduationcap"
        case .recording:   return "opticaldisc"
        }
    }
    var localizedTitleHint: String {
        switch self {
        case .performance: return localized("공연명", "Concert name", "Konzertname")
        case .competition: return localized("대회명", "Competition name", "Wettbewerbsname")
        case .education:   return localized("강좌·과목명", "Course name", "Kursname")
        case .recording:   return localized("앨범·음원 제목", "Album title", "Albumtitel")
        }
    }
    var localizedLocationHint: String {
        switch self {
        case .performance: return localized("공연장", "Venue", "Veranstaltungsort")
        case .competition: return localized("개최지", "Location", "Ort")
        case .education:   return localized("기관명", "Institution", "Institution")
        case .recording:   return localized("레이블·스튜디오", "Label / Studio", "Label / Studio")
        }
    }
    var localizedDateLabel: String {
        self == .recording
            ? localized("발매일", "Release date", "Erscheinungsdatum")
            : localized("날짜", "Date", "Datum")
    }
    var titleHint: String {
        switch self {
        case .performance: return "create.title.performance"
        case .competition: return "create.title.competition"
        case .education:   return "create.title.education"
        case .recording:   return "create.title.recording"
        }
    }
    var locationHint: String {
        switch self {
        case .performance: return "create.location.performance"
        case .competition: return "create.location.competition"
        case .education:   return "create.location.education"
        case .recording:   return "create.location.recording"
        }
    }
    var dateLabel: String {
        self == .recording ? "create.date.release" : "create.date"
    }
}

enum VerificationStatus: String, Codable, Hashable {
    case pending
    case institutionVerified = "institution_verified"

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = VerificationStatus(rawValue: raw) ?? .pending
    }

    var labelKey: String {
        switch self {
        case .pending:             return "badge.pending"
        case .institutionVerified: return "badge.institution"
        }
    }
    var tint: String {
        switch self {
        case .pending:             return "gray"
        case .institutionVerified: return "green"
        }
    }
}

enum ConfirmStatus: String, Codable, Hashable {
    case requested, approved, rejected
}

enum Visibility: String, Codable, CaseIterable, Identifiable, Hashable {
    case `public`
    case industryFollowers = "industry_followers"
    case followers
    case `private`
    var id: String { rawValue }
    var labelKey: String {
        switch self {
        case .public:            return "visibility.public"
        case .industryFollowers: return "visibility.industry"
        case .followers:         return "visibility.followers"
        case .private:           return "visibility.private"
        }
    }
    var localizedLabel: String {
        switch self {
        case .public:            return localized("전체 공개", "Public", "Öffentlich")
        case .industryFollowers: return localized("업계+팔로워", "Industry + followers", "Branche + Follower")
        case .followers:         return localized("팔로워만", "Followers only", "Nur Follower")
        case .private:           return localized("비공개", "Private", "Privat")
        }
    }
}

// MARK: - Profile

enum ProfileSection: String, CaseIterable, Identifiable {
    case bio, activities, career, education, awards, languages
    case cvWebsite = "cv_website"
    case recommendations, org

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bio: return localized("소개", "About", "Über mich")
        case .activities: return localized("나의 활동", "My Activities", "Meine Aktivitäten")
        case .career: return localized("경력사항", "Career", "Berufserfahrung")
        case .education: return localized("학력", "Education", "Ausbildung")
        case .awards: return localized("수상 경력", "Honors & Awards", "Auszeichnungen")
        case .languages: return localized("언어", "Languages", "Sprachen")
        case .cvWebsite: return localized("CV / 홈페이지", "CV / Website", "CV / Webseite")
        case .recommendations: return localized("추천서", "Recommendations", "Empfehlungen")
        case .org: return localized("기관 페이지", "Organization Page", "Organisationsseite")
        }
    }

    var icon: String {
        switch self {
        case .bio: return "text.alignleft"
        case .activities: return "music.note.list"
        case .career: return "briefcase"
        case .education: return "graduationcap"
        case .awards: return "trophy"
        case .languages: return "globe"
        case .cvWebsite: return "doc"
        case .recommendations: return "quote.bubble"
        case .org: return "building.2"
        }
    }
}

struct Profile: Codable, Identifiable, Hashable {
    let id: UUID
    var realName: String
    var major: String?
    var instrument: String?
    var homeCities: [String]
    var bio: String?
    var avatarUrl: String?
    var defaultVisibility: Visibility
    var onboardingComplete: Bool
    var visibleSections: [String]
    var cvUrl: String?
    var websiteUrl: String?

    // Fermata CV fields (migrations 0030/0031)
    var nameEn: String?
    var eyebrow: String?
    var birthYear: Int?
    var birthDate: String?
    var phone: String?
    var address: String?
    var repertoire: [String]?   // optional so Profile still decodes where the column isn't deployed yet
    var profileLangs: [String]? // 다국어 프로필이 제공하는 오버레이 언어 (ko 베이스 제외)
    var cvPhotoUrl: String?     // CV 전용 사진. nil이면 avatar_url 폴백

    func showsSection(_ section: ProfileSection) -> Bool {
        visibleSections.contains(section.rawValue)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case realName = "real_name"
        case major
        case instrument
        case homeCities = "home_cities"
        case bio
        case avatarUrl = "avatar_url"
        case defaultVisibility = "default_visibility"
        case onboardingComplete = "onboarding_complete"
        case visibleSections = "visible_sections"
        case cvUrl = "cv_url"
        case websiteUrl = "website_url"
        case nameEn = "name_en"
        case eyebrow
        case birthYear = "birth_year"
        case birthDate = "birth_date"
        case phone
        case address
        case repertoire
        case profileLangs = "profile_langs"
        case cvPhotoUrl = "cv_photo_url"
    }
}

/// CV 전용 간단 항목 (cv_entries). 기록과 분리되어 CV에만 들어감.
struct CVEntryRow: Codable, Identifiable, Hashable {
    var id: UUID
    var kind: String            // performance | competition | education | masterclass
    var year: Int?
    var period: String?
    var title: String?
    var org: String?
    var place: String?
    var detail: String?
    var result: String?
    var institution: String?
    var degree: String?
    var teacher: String?

    enum CodingKeys: String, CodingKey {
        case id, kind, year, period, title, org, place, detail, result, institution, degree, teacher
    }
}

/// cv_i18n 오버레이 한 행 — 활동/학적/CV항목에 대한 언어별 표기 + 포함 여부.
struct CVOverride: Codable, Hashable {
    var sourceKind: String     // "activity" | "affiliation"
    var sourceId: UUID
    var patch: [String: String]
    var include: Bool

    enum CodingKeys: String, CodingKey {
        case sourceKind = "source_kind"
        case sourceId = "source_id"
        case patch
        case include
    }
}

struct Recommendation: Codable, Identifiable, Hashable {
    let id: UUID
    var recommenderName: String
    var recommenderTitle: String?
    var recommenderUserId: UUID?
    var body: String
    var isVisible: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recommenderName  = "recommender_name"
        case recommenderTitle = "recommender_title"
        case recommenderUserId = "recommender_user_id"
        case body
        case isVisible = "is_visible"
        case createdAt = "created_at"
    }
}

struct ProfileLite: Codable, Identifiable, Hashable {
    let id: UUID
    let realName: String
    let instrument: String?
    let avatarUrl: String?
    let affiliation: String?

    init(
        id: UUID,
        realName: String,
        instrument: String?,
        avatarUrl: String?,
        affiliation: String? = nil
    ) {
        self.id = id
        self.realName = realName
        self.instrument = instrument
        self.avatarUrl = avatarUrl
        self.affiliation = affiliation
    }

    enum CodingKeys: String, CodingKey {
        case id
        case realName = "real_name"
        case instrument
        case avatarUrl = "avatar_url"
        case affiliation
    }
}

// MARK: - Affiliation

struct Affiliation: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var institutionName: String
    var courseType: String?
    var enrollmentYear: Int?
    var graduationYear: Int?
    var isCurrent: Bool
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case institutionName = "institution_name"
        case courseType = "course_type"
        case enrollmentYear = "enrollment_year"
        case graduationYear = "graduation_year"
        case isCurrent = "is_current"
    }
}

struct NewAffiliation: Encodable {
    let userId: UUID
    let institutionName: String
    let courseType: String?
    let enrollmentYear: Int?
    let graduationYear: Int?
    let isCurrent: Bool

    init(userId: UUID, institutionName: String, courseType: String?,
         enrollmentYear: Int?, graduationYear: Int?, isCurrent: Bool = true) {
        self.userId = userId
        self.institutionName = institutionName
        self.courseType = courseType
        self.enrollmentYear = enrollmentYear
        self.graduationYear = graduationYear
        self.isCurrent = isCurrent
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case institutionName = "institution_name"
        case courseType = "course_type"
        case enrollmentYear = "enrollment_year"
        case graduationYear = "graduation_year"
        case isCurrent = "is_current"
    }
}

// MARK: - Career

struct Career: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var organization: String
    var role: String
    var startYear: Int?
    var endYear: Int?
    var isCurrent: Bool
    var description: String?
    var contribution: String?
    var linkUrl: String?
    var mediaUrl: String?
    enum CodingKeys: String, CodingKey {
        case id; case userId = "user_id"
        case organization; case role
        case startYear = "start_year"; case endYear = "end_year"
        case isCurrent = "is_current"; case description; case contribution
        case linkUrl = "link_url"; case mediaUrl = "media_url"
    }
}

struct NewCareer: Encodable {
    let userId: UUID
    let organization: String
    let role: String
    let startYear: Int?
    let endYear: Int?
    let isCurrent: Bool
    let description: String?
    let contribution: String?
    let linkUrl: String?
    let mediaUrl: String?
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"; case organization; case role
        case startYear = "start_year"; case endYear = "end_year"
        case isCurrent = "is_current"; case description; case contribution
        case linkUrl = "link_url"; case mediaUrl = "media_url"
    }
}

// MARK: - Profile awards

struct ProfileAward: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var title: String
    var prize: String
    var issuer: String
    var year: Int
    var details: String
    var linkUrl: String

    enum CodingKeys: String, CodingKey {
        case id, title, prize, issuer, year, details
        case userId = "user_id"
        case linkUrl = "link_url"
    }

    static func normalizedLink(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        let candidate = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, host.contains("."),
              url.user == nil, url.password == nil else { return nil }
        return url.absoluteString
    }
}

// MARK: - Language

struct ProfileLanguage: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var language: String
    var level: String
    enum CodingKeys: String, CodingKey {
        case id; case userId = "user_id"; case language; case level
    }
}

// MARK: - Activity

struct Activity: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    var type: ActivityType
    var title: String
    var activityDate: String
    var location: String?
    var role: String?
    var program: String?
    var prize: String?
    var organizer: String?
    var personalNote: String?
    var imageUrls: [String]
    var verification: VerificationStatus
    var visibility: Visibility
    var createdAt: String?
    // Link preview (Open Graph) — captured when the post is created.
    var linkUrl: String?
    var linkTitle: String?
    var linkDescription: String?
    var linkImageUrl: String?
    var linkSiteName: String?
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case activityDate = "activity_date"
        case location; case role; case program; case prize; case organizer
        case personalNote = "personal_note"
        case imageUrls = "image_urls"
        case verification; case visibility
        case createdAt = "created_at"
        case linkUrl = "link_url"
        case linkTitle = "link_title"
        case linkDescription = "link_description"
        case linkImageUrl = "link_image_url"
        case linkSiteName = "link_site_name"
    }
}

struct ActivityWithAuthor: Codable, Identifiable, Hashable {
    let id: UUID
    let userId: UUID
    let type: ActivityType
    let title: String
    let activityDate: String
    let location: String?
    let role: String?
    let program: String?
    let prize: String?
    let organizer: String?
    let personalNote: String?
    let imageUrls: [String]
    let verification: VerificationStatus
    let createdAt: String?
    let author: ProfileLite?
    let org: OrgSummary?
    let feedReason: String?
    // Link preview (Open Graph)
    let linkUrl: String?
    let linkTitle: String?
    let linkDescription: String?
    let linkImageUrl: String?
    let linkSiteName: String?
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type; case title
        case activityDate = "activity_date"
        case location; case role; case program; case prize; case organizer
        case personalNote = "personal_note"
        case imageUrls = "image_urls"
        case verification; case createdAt = "created_at"
        case author; case org
        case feedReason = "feed_reason"
        case linkUrl = "link_url"
        case linkTitle = "link_title"
        case linkDescription = "link_description"
        case linkImageUrl = "link_image_url"
        case linkSiteName = "link_site_name"
    }

    init(id: UUID, userId: UUID, type: ActivityType, title: String,
         activityDate: String, location: String?, role: String?, program: String?,
         prize: String?, organizer: String?, personalNote: String?, imageUrls: [String],
         verification: VerificationStatus, createdAt: String?, author: ProfileLite?,
         org: OrgSummary?, feedReason: String?, linkUrl: String?, linkTitle: String?,
         linkDescription: String?, linkImageUrl: String?, linkSiteName: String?) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.activityDate = activityDate
        self.location = location
        self.role = role
        self.program = program
        self.prize = prize
        self.organizer = organizer
        self.personalNote = personalNote
        self.imageUrls = imageUrls
        self.verification = verification
        self.createdAt = createdAt
        self.author = author
        self.org = org
        self.feedReason = feedReason
        self.linkUrl = linkUrl
        self.linkTitle = linkTitle
        self.linkDescription = linkDescription
        self.linkImageUrl = linkImageUrl
        self.linkSiteName = linkSiteName
    }

    /// Builds the feed/profile projection from the authoritative row returned
    /// after a local activity mutation, without waiting for a second fetch.
    init(activity: Activity, author: ProfileLite?, org: OrgSummary?, feedReason: String?) {
        id = activity.id
        userId = activity.userId
        type = activity.type
        title = activity.title
        activityDate = activity.activityDate
        location = activity.location
        role = activity.role
        program = activity.program
        prize = activity.prize
        organizer = activity.organizer
        personalNote = activity.personalNote
        imageUrls = activity.imageUrls
        verification = activity.verification
        createdAt = activity.createdAt
        self.author = author
        self.org = org
        self.feedReason = feedReason
        linkUrl = activity.linkUrl
        linkTitle = activity.linkTitle
        linkDescription = activity.linkDescription
        linkImageUrl = activity.linkImageUrl
        linkSiteName = activity.linkSiteName
    }
}

struct ConfirmRequest: Codable, Identifiable, Hashable {
    let id: UUID
    let confirm: ConfirmStatus
    let activity: ActivityWithAuthor?
}

// MARK: - Insert / update payloads

struct UpdateActivity: Encodable {
    let type: ActivityType
    let title: String
    let activityDate: String
    let location: String?
    let role: String?
    let program: String?
    let prize: String?
    let organizer: String?
    let personalNote: String?
    let visibility: Visibility
    let linkUrl: String?
    let linkTitle: String?
    let linkDescription: String?
    let linkImageUrl: String?
    let linkSiteName: String?
    enum CodingKeys: String, CodingKey {
        case type; case title
        case activityDate = "activity_date"
        case location; case role; case program; case prize; case organizer
        case personalNote = "personal_note"
        case visibility
        case linkUrl = "link_url"
        case linkTitle = "link_title"
        case linkDescription = "link_description"
        case linkImageUrl = "link_image_url"
        case linkSiteName = "link_site_name"
    }
}

struct NewActivity: Encodable {
    /// Generated before upload so attachments and the database row share one
    /// stable identity and the row can be inserted in its final state.
    var id = UUID()
    let userId: UUID
    let orgId: UUID?
    let type: ActivityType
    let title: String
    let activityDate: String
    let location: String?
    let role: String?
    let program: String?
    let prize: String?
    let organizer: String?
    let personalNote: String?
    let visibility: Visibility
    let linkUrl: String?
    let linkTitle: String?
    let linkDescription: String?
    let linkImageUrl: String?
    let linkSiteName: String?
    var imageUrls: [String] = []
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case orgId = "org_id"
        case type; case title
        case activityDate = "activity_date"
        case location; case role; case program; case prize; case organizer
        case personalNote = "personal_note"
        case visibility
        case linkUrl = "link_url"
        case linkTitle = "link_title"
        case linkDescription = "link_description"
        case linkImageUrl = "link_image_url"
        case linkSiteName = "link_site_name"
        case imageUrls = "image_urls"
    }
}

// MARK: - Likes & Comments

struct ActivityStats: Decodable {
    var likeCount: Int
    var commentCount: Int
    var isLiked: Bool
    var isSaved: Bool
    enum CodingKeys: String, CodingKey {
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case isLiked = "is_liked"
        case isSaved = "is_saved"
    }
}

struct ActivityComment: Codable, Identifiable {
    let id: UUID
    let activityId: UUID
    let userId: UUID
    let content: String
    let createdAt: String
    let parentCommentId: UUID?
    let author: ProfileLite?
    var likeCount: Int
    var isLiked: Bool
    enum CodingKeys: String, CodingKey {
        case id; case activityId = "activity_id"; case userId = "user_id"
        case content; case createdAt = "created_at"
        case parentCommentId = "parent_comment_id"; case author
        case likeCount = "like_count"; case isLiked = "is_liked"
    }
}

struct NewParticipant: Encodable {
    let activityId: UUID
    let participantId: UUID
    let role: String?
    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case participantId = "participant_id"
        case role
    }
}

// MARK: - Connection

enum ConnectionStatus: Equatable {
    case none
    case requestSent      // I sent the request, waiting for their acceptance
    case requestReceived  // They sent me a request, I can accept or decline
    case connected        // Accepted — bidirectional
}

struct ConnectedProfile: Codable, Identifiable, Hashable {
    let id: UUID
    let realName: String
    let instrument: String?
    let major: String?
    let avatarUrl: String?
    enum CodingKeys: String, CodingKey {
        case id
        case realName  = "real_name"
        case instrument
        case major
        case avatarUrl = "avatar_url"
    }
}

struct SuggestedProfile: Codable, Identifiable, Hashable {
    let id: UUID
    let realName: String
    let instrument: String?
    let major: String?
    let avatarUrl: String?
    let reason: String      // "school" | "city"
    let sharedInfo: String

    enum CodingKeys: String, CodingKey {
        case id, instrument, major, reason
        case realName  = "real_name"
        case avatarUrl = "avatar_url"
        case sharedInfo = "shared_info"
    }
}

// MARK: - Notification

struct AppNotification: Identifiable, Codable {
    let id: UUID
    let type: String          // "like" | "comment" | "follow" | "tag"
    let activityId: UUID?
    var isRead: Bool
    let createdAt: String
    let sender: SenderSnippet?
    let activity: ActivitySnippet?

    struct SenderSnippet: Codable {
        let realName: String
        let instrument: String?
        enum CodingKeys: String, CodingKey {
            case realName = "real_name"; case instrument
        }
    }

    struct ActivitySnippet: Codable {
        let title: String
    }

    var timeAgo: String {
        let fmt1 = ISO8601DateFormatter()
        fmt1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmt2 = ISO8601DateFormatter()
        fmt2.formatOptions = [.withInternetDateTime]
        guard let date = fmt1.date(from: createdAt) ?? fmt2.date(from: createdAt) else { return "" }
        let s = Int(-date.timeIntervalSinceNow)
        if s < 60  { return localized("방금", "Just now", "Gerade eben") }
        let m = s / 60
        if m < 60  { return localized("\(m)분 전", "\(m)m ago", "vor \(m) Min.") }
        let h = m / 60
        if h < 24  { return localized("\(h)시간 전", "\(h)h ago", "vor \(h) Std.") }
        let d = h / 24
        if d < 7   { return localized("\(d)일 전", "\(d)d ago", "vor \(d) T.") }
        if d < 30  { return localized("\(d / 7)주 전", "\(d / 7)w ago", "vor \(d / 7) Wo.") }
        return localized("\(d / 30)달 전", "\(d / 30)mo ago", "vor \(d / 30) Mon.")
    }

    var bodyText: String {
        let name = sender?.realName ?? "누군가"
        switch type {
        case "like":    return "\(name)님이 게시글을 좋아합니다"
        case "comment": return "\(name)님이 댓글을 남겼습니다"
        case "follow":  return "\(name)님이 연결을 요청했습니다"
        case "tag":     return "\(name)님이 게시글에 태그했습니다"
        default:        return "\(name)님의 알림"
        }
    }

    var iconName: String {
        switch type {
        case "like":    return "hand.thumbsup.fill"
        case "comment": return "bubble.right.fill"
        case "follow":  return "person.fill.badge.plus"
        case "tag":     return "at"
        default:        return "bell.fill"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, type
        case activityId  = "activity_id"
        case isRead      = "is_read"
        case createdAt   = "created_at"
        case sender, activity
    }
}
