import Foundation

/// Standardised lookup tables used across onboarding pickers.
///
/// Every user-facing option is modelled as a `LocalizedOption`: a stable
/// canonical `id` that is persisted to the DB (and used for search/matching),
/// plus ko/en/de labels resolved for display via `localizedName`. Display
/// always follows the in-app language (`appLanguage`), never the raw stored
/// value — so switching language re-labels every option structurally.
enum OnboardingData {

    /// An option with a canonical DB value and per-language display labels.
    struct LocalizedOption: Identifiable, Hashable {
        let id: String   // canonical value stored in DB (stable across languages)
        let ko: String
        let en: String
        let de: String

        /// Display label for the currently selected in-app language.
        var localizedName: String { localized(ko, en, de) }
    }

    // MARK: – Majors & instruments

    static let majors: [LocalizedOption] = [
        .init(id: "피아노",          ko: "피아노",          en: "Piano",                       de: "Klavier"),
        .init(id: "현악",            ko: "현악",            en: "Strings",                     de: "Streicher"),
        .init(id: "기악",            ko: "기악",            en: "Instrumental",                de: "Instrumentalmusik"),
        .init(id: "관악·타악",       ko: "관악·타악",       en: "Winds & Percussion",          de: "Bläser & Schlagwerk"),
        .init(id: "성악",            ko: "성악",            en: "Voice",                       de: "Gesang"),
        .init(id: "지휘",            ko: "지휘",            en: "Conducting",                  de: "Dirigieren"),
        .init(id: "작곡",            ko: "작곡",            en: "Composition",                 de: "Komposition"),
        .init(id: "음악이론/음악학", ko: "음악이론/음악학", en: "Music Theory / Musicology",   de: "Musiktheorie / Musikwissenschaft"),
    ]

    static let instrumentsByMajor: [String: [LocalizedOption]] = [
        "피아노": [
            .init(id: "피아노", ko: "피아노", en: "Piano",         de: "Klavier"),
            .init(id: "반주",   ko: "반주",   en: "Accompaniment", de: "Korrepetition"),
        ],
        "기악": [
            .init(id: "오르간",        ko: "오르간",        en: "Organ",           de: "Orgel"),
            .init(id: "하프시코드",    ko: "하프시코드",    en: "Harpsichord",     de: "Cembalo"),
            .init(id: "포르테피아노",  ko: "포르테피아노",  en: "Fortepiano",      de: "Hammerklavier"),
            .init(id: "클래식 기타",   ko: "클래식 기타",   en: "Classical Guitar", de: "Klassische Gitarre"),
            .init(id: "류트",          ko: "류트",          en: "Lute",            de: "Laute"),
            .init(id: "만돌린",        ko: "만돌린",        en: "Mandolin",        de: "Mandoline"),
            .init(id: "리코더",        ko: "리코더",        en: "Recorder",        de: "Blockflöte"),
            .init(id: "비올라 다 감바", ko: "비올라 다 감바", en: "Viola da gamba",  de: "Viola da Gamba"),
            .init(id: "아코디언",      ko: "아코디언",      en: "Accordion",       de: "Akkordeon"),
        ],
        "현악": [
            .init(id: "바이올린",     ko: "바이올린",     en: "Violin",      de: "Violine"),
            .init(id: "비올라",       ko: "비올라",       en: "Viola",       de: "Viola"),
            .init(id: "첼로",         ko: "첼로",         en: "Cello",       de: "Violoncello"),
            .init(id: "콘트라베이스", ko: "콘트라베이스", en: "Double Bass", de: "Kontrabass"),
            .init(id: "하프",         ko: "하프",         en: "Harp",        de: "Harfe"),
            .init(id: "기타",         ko: "기타",         en: "Guitar",      de: "Gitarre"),
        ],
        "관악·타악": [
            .init(id: "플루트",   ko: "플루트",   en: "Flute",      de: "Flöte"),
            .init(id: "오보에",   ko: "오보에",   en: "Oboe",       de: "Oboe"),
            .init(id: "클라리넷", ko: "클라리넷", en: "Clarinet",   de: "Klarinette"),
            .init(id: "바순",     ko: "바순",     en: "Bassoon",    de: "Fagott"),
            .init(id: "색소폰",   ko: "색소폰",   en: "Saxophone",  de: "Saxophon"),
            .init(id: "호른",     ko: "호른",     en: "Horn",       de: "Horn"),
            .init(id: "트럼펫",   ko: "트럼펫",   en: "Trumpet",    de: "Trompete"),
            .init(id: "트롬본",   ko: "트롬본",   en: "Trombone",   de: "Posaune"),
            .init(id: "유포니엄", ko: "유포니엄", en: "Euphonium",  de: "Euphonium"),
            .init(id: "튜바",     ko: "튜바",     en: "Tuba",       de: "Tuba"),
            .init(id: "타악기",   ko: "타악기",   en: "Percussion", de: "Schlagwerk"),
            .init(id: "팀파니",   ko: "팀파니",   en: "Timpani",    de: "Pauke"),
            .init(id: "마림바",   ko: "마림바",   en: "Marimba",    de: "Marimba"),
        ],
        "성악": [
            .init(id: "소프라노",     ko: "소프라노",     en: "Soprano",       de: "Sopran"),
            .init(id: "메조소프라노", ko: "메조소프라노", en: "Mezzo-soprano", de: "Mezzosopran"),
            .init(id: "알토",         ko: "알토",         en: "Alto",          de: "Alt"),
            .init(id: "테너",         ko: "테너",         en: "Tenor",         de: "Tenor"),
            .init(id: "바리톤",       ko: "바리톤",       en: "Baritone",      de: "Bariton"),
            .init(id: "베이스바리톤", ko: "베이스바리톤", en: "Bass-baritone", de: "Bassbariton"),
            .init(id: "베이스",       ko: "베이스",       en: "Bass",          de: "Bass"),
        ],
        "지휘": [
            .init(id: "오케스트라 지휘", ko: "오케스트라 지휘", en: "Orchestral Conducting", de: "Orchesterdirigieren"),
            .init(id: "합창 지휘",       ko: "합창 지휘",       en: "Choral Conducting",     de: "Chordirigieren"),
        ],
        "작곡": [
            .init(id: "작곡",     ko: "작곡",     en: "Composition",      de: "Komposition"),
            .init(id: "전자음악", ko: "전자음악", en: "Electronic Music", de: "Elektronische Musik"),
        ],
        "음악이론/음악학": [
            .init(id: "음악이론", ko: "음악이론", en: "Music Theory", de: "Musiktheorie"),
            .init(id: "음악학",   ko: "음악학",   en: "Musicology",   de: "Musikwissenschaft"),
            .init(id: "음악교육", ko: "음악교육", en: "Music Education", de: "Musikpädagogik"),
        ],
    ]

    /// Every instrument across all majors (flattened, deduplicated by id).
    static let allInstruments: [LocalizedOption] = {
        var seen = Set<String>()
        return instrumentsByMajor.values.flatMap { $0 }.filter { seen.insert($0.id).inserted }
    }()

    /// Localized display name for a stored major id (falls back to the raw value).
    static func majorDisplay(_ id: String) -> String {
        majors.first { $0.id == id }?.localizedName ?? id
    }

    /// Localized display name for a stored instrument id (falls back to the raw value).
    static func instrumentDisplay(_ id: String) -> String {
        allInstruments.first { $0.id == id }?.localizedName ?? id
    }

    // MARK: – Schools

    static let schools: [String] = [
        // 한국
        "한국예술종합학교",
        "서울대학교 음악대학",
        "연세대학교 음악대학",
        "이화여자대학교 음악대학",
        "경희대학교 음악대학",
        "중앙대학교 음악대학",
        "숙명여자대학교 음악대학",
        "서울시립대학교 음악대학",
        "한양대학교 음악대학",
        "성신여자대학교 음악대학",
        // 독일
        "Hochschule für Musik Hanns Eisler Berlin",
        "Universität der Künste Berlin",
        "Hochschule für Musik und Theater Hamburg",
        "Hochschule für Musik und Theater München",
        "Hochschule für Musik Köln",
        "Hochschule für Musik und Darstellende Kunst Frankfurt",
        "Hochschule für Musik Freiburg",
        "Hochschule für Musik, Theater und Medien Hannover",
        "Hochschule für Musik und Theater Leipzig",
        "Hochschule für Musik Carl Maria von Weber Dresden",
        "Hochschule für Musik Detmold",
        "Hochschule für Musik Würzburg",
        "Hochschule für Musik Nürnberg",
        "Hochschule für Musik und Darstellende Kunst Stuttgart",
        "Hochschule für Musik und Theater Rostock",
        "Hochschule für Musik Saar",
        "Robert Schumann Hochschule Düsseldorf",
        "Hochschule für Musik Weimar",
        // 오스트리아
        "Universität Mozarteum Salzburg",
        "Kunstuniversität Graz",
        "Universität für Musik und darstellende Kunst Wien",
        // 스위스
        "Zürcher Hochschule der Künste",
        "Haute école de musique de Genève",
        "Hochschule der Künste Bern",
        // 프랑스
        "Conservatoire national supérieur de musique de Paris",
        // 영국
        "Royal Academy of Music",
        "Royal College of Music",
        "Guildhall School of Music & Drama",
        // 미국
        "The Juilliard School",
        "Curtis Institute of Music",
        "New England Conservatory",
        "Eastman School of Music",
        "Manhattan School of Music",
        "Cleveland Institute of Music",
        "San Francisco Conservatory of Music",
    ]

    // MARK: – Course types

    struct CourseOption: Identifiable, Hashable {
        let id: String   // raw value for DB
        let ko: String
        let en: String
        let de: String

        /// Display label for the currently selected in-app language.
        var label: String { localized(ko, en, de) }
    }

    static let courseOptions: [CourseOption] = [
        .init(id: "highschool",  ko: "예고/고등학교",   en: "Arts / High School",   de: "Musikgymnasium"),
        .init(id: "bachelor",    ko: "학사",            en: "Bachelor",             de: "Bachelor"),
        .init(id: "master",      ko: "석사",            en: "Master",               de: "Master"),
        .init(id: "phd",         ko: "박사/DMA",        en: "PhD / DMA",            de: "Promotion / DMA"),
        .init(id: "performance", ko: "전문연주자과정",  en: "Performance Diploma",  de: "Konzertexamen"),
        .init(id: "diploma",     ko: "디플롬",          en: "Diploma",              de: "Diplom"),
        .init(id: "other",       ko: "기타",            en: "Other",                de: "Sonstiges"),
    ]

    // MARK: – Cities (KR-DE bridge + major hubs)

    // MARK: – Cities (canonical ID stored in DB; display localized at runtime)

    struct CityOption: Identifiable, Hashable {
        let id: String      // canonical key stored in DB (English slug)
        let flag: String    // country emoji
        let country: String // for section grouping — shown in user's language
        let ko: String
        let en: String
        let de: String

        var localizedName: String { localized(ko, en, de) }
        var localizedCountry: String { localized(country, enCountry, deCountry) }
        // extra country translations stored inline
        let enCountry: String
        let deCountry: String
    }

    static let cityOptions: [CityOption] = [
        // 🇰🇷 한국
        .init(id: "seoul",      flag: "🇰🇷", country: "한국",    ko: "서울",     en: "Seoul",        de: "Seoul",        enCountry: "Korea",    deCountry: "Südkorea"),
        .init(id: "busan",      flag: "🇰🇷", country: "한국",    ko: "부산",     en: "Busan",        de: "Busan",        enCountry: "Korea",    deCountry: "Südkorea"),
        .init(id: "daegu",      flag: "🇰🇷", country: "한국",    ko: "대구",     en: "Daegu",        de: "Daegu",        enCountry: "Korea",    deCountry: "Südkorea"),
        .init(id: "gwangju",    flag: "🇰🇷", country: "한국",    ko: "광주",     en: "Gwangju",      de: "Gwangju",      enCountry: "Korea",    deCountry: "Südkorea"),
        .init(id: "daejeon",    flag: "🇰🇷", country: "한국",    ko: "대전",     en: "Daejeon",      de: "Daejeon",      enCountry: "Korea",    deCountry: "Südkorea"),
        .init(id: "incheon",    flag: "🇰🇷", country: "한국",    ko: "인천",     en: "Incheon",      de: "Incheon",      enCountry: "Korea",    deCountry: "Südkorea"),
        // 🇩🇪 독일
        .init(id: "berlin",     flag: "🇩🇪", country: "독일",    ko: "베를린",   en: "Berlin",       de: "Berlin",       enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "munich",     flag: "🇩🇪", country: "독일",    ko: "뮌헨",     en: "Munich",       de: "München",      enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "hamburg",    flag: "🇩🇪", country: "독일",    ko: "함부르크", en: "Hamburg",      de: "Hamburg",      enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "cologne",    flag: "🇩🇪", country: "독일",    ko: "쾰른",     en: "Cologne",      de: "Köln",         enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "frankfurt",  flag: "🇩🇪", country: "독일",    ko: "프랑크푸르트", en: "Frankfurt", de: "Frankfurt",   enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "hannover",   flag: "🇩🇪", country: "독일",    ko: "하노버",   en: "Hanover",      de: "Hannover",     enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "leipzig",    flag: "🇩🇪", country: "독일",    ko: "라이프치히", en: "Leipzig",    de: "Leipzig",      enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "dresden",    flag: "🇩🇪", country: "독일",    ko: "드레스덴", en: "Dresden",      de: "Dresden",      enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "dusseldorf", flag: "🇩🇪", country: "독일",    ko: "뒤셀도르프", en: "Düsseldorf", de: "Düsseldorf",  enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "freiburg",   flag: "🇩🇪", country: "독일",    ko: "프라이부르크", en: "Freiburg", de: "Freiburg",    enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "stuttgart",  flag: "🇩🇪", country: "독일",    ko: "슈투트가르트", en: "Stuttgart", de: "Stuttgart",  enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "weimar",     flag: "🇩🇪", country: "독일",    ko: "바이마르", en: "Weimar",       de: "Weimar",       enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "detmold",    flag: "🇩🇪", country: "독일",    ko: "데트몰트", en: "Detmold",      de: "Detmold",      enCountry: "Germany",  deCountry: "Deutschland"),
        .init(id: "saarbrucken",flag: "🇩🇪", country: "독일",    ko: "자르브뤼켄", en: "Saarbrücken", de: "Saarbrücken", enCountry: "Germany",  deCountry: "Deutschland"),
        // 🇦🇹 오스트리아
        .init(id: "vienna",     flag: "🇦🇹", country: "오스트리아", ko: "빈",    en: "Vienna",       de: "Wien",         enCountry: "Austria",  deCountry: "Österreich"),
        .init(id: "salzburg",   flag: "🇦🇹", country: "오스트리아", ko: "잘츠부르크", en: "Salzburg", de: "Salzburg",   enCountry: "Austria",  deCountry: "Österreich"),
        .init(id: "graz",       flag: "🇦🇹", country: "오스트리아", ko: "그라츠", en: "Graz",        de: "Graz",         enCountry: "Austria",  deCountry: "Österreich"),
        // 🇨🇭 스위스
        .init(id: "zurich",     flag: "🇨🇭", country: "스위스",  ko: "취리히",   en: "Zurich",       de: "Zürich",       enCountry: "Switzerland", deCountry: "Schweiz"),
        .init(id: "geneva",     flag: "🇨🇭", country: "스위스",  ko: "제네바",   en: "Geneva",       de: "Genf",         enCountry: "Switzerland", deCountry: "Schweiz"),
        .init(id: "bern",       flag: "🇨🇭", country: "스위스",  ko: "베른",     en: "Berne",        de: "Bern",         enCountry: "Switzerland", deCountry: "Schweiz"),
        // 🇫🇷 기타 유럽
        .init(id: "paris",      flag: "🇫🇷", country: "프랑스",  ko: "파리",     en: "Paris",        de: "Paris",        enCountry: "France",   deCountry: "Frankreich"),
        .init(id: "london",     flag: "🇬🇧", country: "영국",    ko: "런던",     en: "London",       de: "London",       enCountry: "UK",       deCountry: "Vereinigtes Königreich"),
        .init(id: "amsterdam",  flag: "🇳🇱", country: "네덜란드", ko: "암스테르담", en: "Amsterdam",  de: "Amsterdam",    enCountry: "Netherlands", deCountry: "Niederlande"),
        .init(id: "rome",       flag: "🇮🇹", country: "이탈리아", ko: "로마",    en: "Rome",         de: "Rom",          enCountry: "Italy",    deCountry: "Italien"),
        .init(id: "milan",      flag: "🇮🇹", country: "이탈리아", ko: "밀라노",  en: "Milan",        de: "Mailand",      enCountry: "Italy",    deCountry: "Italien"),
        // 🇺🇸 미주
        .init(id: "new_york",   flag: "🇺🇸", country: "미국",    ko: "뉴욕",     en: "New York",     de: "New York",     enCountry: "USA",      deCountry: "USA"),
        .init(id: "boston",     flag: "🇺🇸", country: "미국",    ko: "보스턴",   en: "Boston",       de: "Boston",       enCountry: "USA",      deCountry: "USA"),
        .init(id: "philadelphia",flag: "🇺🇸", country: "미국",   ko: "필라델피아", en: "Philadelphia", de: "Philadelphia", enCountry: "USA",     deCountry: "USA"),
        .init(id: "cleveland",  flag: "🇺🇸", country: "미국",    ko: "클리블랜드", en: "Cleveland",  de: "Cleveland",    enCountry: "USA",      deCountry: "USA"),
        .init(id: "los_angeles",flag: "🇺🇸", country: "미국",    ko: "로스앤젤레스", en: "Los Angeles", de: "Los Angeles", enCountry: "USA",    deCountry: "USA"),
    ]

    /// Cities grouped by country, preserving insertion order.
    static var cityGroups: [(country: String, flag: String, cities: [CityOption])] {
        var seen: [String: Int] = [:]
        var groups: [(country: String, flag: String, cities: [CityOption])] = []
        for city in cityOptions {
            let key = city.localizedCountry
            if let idx = seen[key] {
                groups[idx].cities.append(city)
            } else {
                seen[key] = groups.count
                groups.append((key, city.flag, [city]))
            }
        }
        return groups
    }

    // MARK: – Enrollment years

    static var enrollmentYears: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((1990...current + 1).reversed())
    }
}
