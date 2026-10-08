package com.cadenza.android.core.data.onboarding

import com.cadenza.android.core.util.AppLocale

object OnboardingData {

    data class LocalizedOption(
        val id: String,
        val ko: String,
        val en: String,
        val de: String,
    ) {
        val localizedName: String get() = AppLocale.localized(ko, en, de)
    }

    data class CityOption(
        val id: String,
        val flag: String,
        val country: String,
        val ko: String,
        val en: String,
        val de: String,
        val enCountry: String,
        val deCountry: String,
    ) {
        val localizedName: String get() = AppLocale.localized(ko, en, de)
        val localizedCountry: String get() = AppLocale.localized(country, enCountry, deCountry)
    }

    data class CourseOption(
        val id: String,
        val ko: String,
        val en: String,
        val de: String,
    ) {
        val label: String get() = AppLocale.localized(ko, en, de)
    }

    // ─── Majors ───────────────────────────────────────────────────────────────

    val majors = listOf(
        LocalizedOption("피아노",          "피아노",          "Piano",                     "Klavier"),
        LocalizedOption("현악",            "현악",            "Strings",                   "Streicher"),
        LocalizedOption("기악",            "기악",            "Instrumental",              "Instrumentalmusik"),
        LocalizedOption("관악·타악",       "관악·타악",       "Winds & Percussion",        "Bläser & Schlagwerk"),
        LocalizedOption("성악",            "성악",            "Voice",                     "Gesang"),
        LocalizedOption("지휘",            "지휘",            "Conducting",                "Dirigieren"),
        LocalizedOption("작곡",            "작곡",            "Composition",               "Komposition"),
        LocalizedOption("음악이론/음악학", "음악이론/음악학", "Music Theory / Musicology", "Musiktheorie / Musikwissenschaft"),
    )

    val instrumentsByMajor: Map<String, List<LocalizedOption>> = mapOf(
        "피아노" to listOf(
            LocalizedOption("피아노", "피아노", "Piano",         "Klavier"),
            LocalizedOption("반주",   "반주",   "Accompaniment", "Korrepetition"),
        ),
        "기악" to listOf(
            LocalizedOption("오르간",         "오르간",         "Organ",            "Orgel"),
            LocalizedOption("하프시코드",     "하프시코드",     "Harpsichord",      "Cembalo"),
            LocalizedOption("포르테피아노",   "포르테피아노",   "Fortepiano",       "Hammerklavier"),
            LocalizedOption("클래식 기타",    "클래식 기타",    "Classical Guitar", "Klassische Gitarre"),
            LocalizedOption("류트",           "류트",           "Lute",             "Laute"),
            LocalizedOption("만돌린",         "만돌린",         "Mandolin",         "Mandoline"),
            LocalizedOption("리코더",         "리코더",         "Recorder",         "Blockflöte"),
            LocalizedOption("비올라 다 감바", "비올라 다 감바", "Viola da gamba",   "Viola da Gamba"),
            LocalizedOption("아코디언",       "아코디언",       "Accordion",        "Akkordeon"),
        ),
        "현악" to listOf(
            LocalizedOption("바이올린",     "바이올린",     "Violin",      "Violine"),
            LocalizedOption("비올라",       "비올라",       "Viola",       "Viola"),
            LocalizedOption("첼로",         "첼로",         "Cello",       "Violoncello"),
            LocalizedOption("콘트라베이스", "콘트라베이스", "Double Bass", "Kontrabass"),
            LocalizedOption("하프",         "하프",         "Harp",        "Harfe"),
            LocalizedOption("기타",         "기타",         "Guitar",      "Gitarre"),
        ),
        "관악·타악" to listOf(
            LocalizedOption("플루트",   "플루트",   "Flute",      "Flöte"),
            LocalizedOption("오보에",   "오보에",   "Oboe",       "Oboe"),
            LocalizedOption("클라리넷", "클라리넷", "Clarinet",   "Klarinette"),
            LocalizedOption("바순",     "바순",     "Bassoon",    "Fagott"),
            LocalizedOption("색소폰",   "색소폰",   "Saxophone",  "Saxophon"),
            LocalizedOption("호른",     "호른",     "Horn",       "Horn"),
            LocalizedOption("트럼펫",   "트럼펫",   "Trumpet",    "Trompete"),
            LocalizedOption("트롬본",   "트롬본",   "Trombone",   "Posaune"),
            LocalizedOption("유포니엄", "유포니엄", "Euphonium",  "Euphonium"),
            LocalizedOption("튜바",     "튜바",     "Tuba",       "Tuba"),
            LocalizedOption("타악기",   "타악기",   "Percussion", "Schlagwerk"),
            LocalizedOption("팀파니",   "팀파니",   "Timpani",    "Pauke"),
            LocalizedOption("마림바",   "마림바",   "Marimba",    "Marimba"),
        ),
        "성악" to listOf(
            LocalizedOption("소프라노",     "소프라노",     "Soprano",       "Sopran"),
            LocalizedOption("메조소프라노", "메조소프라노", "Mezzo-soprano", "Mezzosopran"),
            LocalizedOption("알토",         "알토",         "Alto",          "Alt"),
            LocalizedOption("테너",         "테너",         "Tenor",         "Tenor"),
            LocalizedOption("바리톤",       "바리톤",       "Baritone",      "Bariton"),
            LocalizedOption("베이스바리톤", "베이스바리톤", "Bass-baritone", "Bassbariton"),
            LocalizedOption("베이스",       "베이스",       "Bass",          "Bass"),
        ),
        "지휘" to listOf(
            LocalizedOption("오케스트라 지휘", "오케스트라 지휘", "Orchestral Conducting", "Orchesterdirigieren"),
            LocalizedOption("합창 지휘",       "합창 지휘",       "Choral Conducting",     "Chordirigieren"),
        ),
        "작곡" to listOf(
            LocalizedOption("작곡",     "작곡",     "Composition",      "Komposition"),
            LocalizedOption("전자음악", "전자음악", "Electronic Music", "Elektronische Musik"),
        ),
        "음악이론/음악학" to listOf(
            LocalizedOption("음악이론", "음악이론", "Music Theory",    "Musiktheorie"),
            LocalizedOption("음악학",   "음악학",   "Musicology",      "Musikwissenschaft"),
            LocalizedOption("음악교육", "음악교육", "Music Education", "Musikpädagogik"),
        ),
    )

    val allInstruments: List<LocalizedOption> by lazy {
        val seen = mutableSetOf<String>()
        instrumentsByMajor.values.flatten().filter { seen.add(it.id) }
    }

    fun majorDisplay(id: String): String = majors.firstOrNull { it.id == id }?.localizedName ?: id
    fun instrumentDisplay(id: String): String = allInstruments.firstOrNull { it.id == id }?.localizedName ?: id

    // ─── Schools ──────────────────────────────────────────────────────────────

    val schools = listOf(
        "한국예술종합학교", "서울대학교 음악대학", "연세대학교 음악대학",
        "이화여자대학교 음악대학", "경희대학교 음악대학", "중앙대학교 음악대학",
        "숙명여자대학교 음악대학", "서울시립대학교 음악대학", "한양대학교 음악대학",
        "성신여자대학교 음악대학",
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
        "Universität Mozarteum Salzburg",
        "Kunstuniversität Graz",
        "Universität für Musik und darstellende Kunst Wien",
        "Zürcher Hochschule der Künste",
        "Haute école de musique de Genève",
        "Hochschule der Künste Bern",
        "Conservatoire national supérieur de musique de Paris",
        "Royal Academy of Music",
        "Royal College of Music",
        "Guildhall School of Music & Drama",
        "The Juilliard School",
        "Curtis Institute of Music",
        "New England Conservatory",
        "Eastman School of Music",
        "Manhattan School of Music",
        "Cleveland Institute of Music",
        "San Francisco Conservatory of Music",
    )

    // ─── Course types ─────────────────────────────────────────────────────────

    val courseOptions = listOf(
        CourseOption("highschool",  "예고/고등학교",  "Arts / High School",  "Musikgymnasium"),
        CourseOption("bachelor",    "학사",           "Bachelor",            "Bachelor"),
        CourseOption("master",      "석사",           "Master",              "Master"),
        CourseOption("phd",         "박사/DMA",       "PhD / DMA",           "Promotion / DMA"),
        CourseOption("performance", "전문연주자과정", "Performance Diploma", "Konzertexamen"),
        CourseOption("diploma",     "디플롬",         "Diploma",             "Diplom"),
        CourseOption("other",       "기타",           "Other",               "Sonstiges"),
    )

    // ─── Cities ───────────────────────────────────────────────────────────────

    val cityOptions = listOf(
        CityOption("seoul",       "🇰🇷", "한국",       "서울",       "Seoul",       "Seoul",       "Korea",       "Südkorea"),
        CityOption("busan",       "🇰🇷", "한국",       "부산",       "Busan",       "Busan",       "Korea",       "Südkorea"),
        CityOption("daegu",       "🇰🇷", "한국",       "대구",       "Daegu",       "Daegu",       "Korea",       "Südkorea"),
        CityOption("gwangju",     "🇰🇷", "한국",       "광주",       "Gwangju",     "Gwangju",     "Korea",       "Südkorea"),
        CityOption("daejeon",     "🇰🇷", "한국",       "대전",       "Daejeon",     "Daejeon",     "Korea",       "Südkorea"),
        CityOption("incheon",     "🇰🇷", "한국",       "인천",       "Incheon",     "Incheon",     "Korea",       "Südkorea"),
        CityOption("berlin",      "🇩🇪", "독일",       "베를린",     "Berlin",      "Berlin",      "Germany",     "Deutschland"),
        CityOption("munich",      "🇩🇪", "독일",       "뮌헨",       "Munich",      "München",     "Germany",     "Deutschland"),
        CityOption("hamburg",     "🇩🇪", "독일",       "함부르크",   "Hamburg",     "Hamburg",     "Germany",     "Deutschland"),
        CityOption("cologne",     "🇩🇪", "독일",       "쾰른",       "Cologne",     "Köln",        "Germany",     "Deutschland"),
        CityOption("frankfurt",   "🇩🇪", "독일",       "프랑크푸르트","Frankfurt",  "Frankfurt",   "Germany",     "Deutschland"),
        CityOption("hannover",    "🇩🇪", "독일",       "하노버",     "Hanover",     "Hannover",    "Germany",     "Deutschland"),
        CityOption("leipzig",     "🇩🇪", "독일",       "라이프치히", "Leipzig",     "Leipzig",     "Germany",     "Deutschland"),
        CityOption("dresden",     "🇩🇪", "독일",       "드레스덴",   "Dresden",     "Dresden",     "Germany",     "Deutschland"),
        CityOption("dusseldorf",  "🇩🇪", "독일",       "뒤셀도르프", "Düsseldorf",  "Düsseldorf",  "Germany",     "Deutschland"),
        CityOption("freiburg",    "🇩🇪", "독일",       "프라이부르크","Freiburg",   "Freiburg",    "Germany",     "Deutschland"),
        CityOption("stuttgart",   "🇩🇪", "독일",       "슈투트가르트","Stuttgart",  "Stuttgart",   "Germany",     "Deutschland"),
        CityOption("weimar",      "🇩🇪", "독일",       "바이마르",   "Weimar",      "Weimar",      "Germany",     "Deutschland"),
        CityOption("detmold",     "🇩🇪", "독일",       "데트몰트",   "Detmold",     "Detmold",     "Germany",     "Deutschland"),
        CityOption("saarbrucken", "🇩🇪", "독일",       "자르브뤼켄", "Saarbrücken", "Saarbrücken", "Germany",     "Deutschland"),
        CityOption("vienna",      "🇦🇹", "오스트리아", "빈",         "Vienna",      "Wien",        "Austria",     "Österreich"),
        CityOption("salzburg",    "🇦🇹", "오스트리아", "잘츠부르크", "Salzburg",    "Salzburg",    "Austria",     "Österreich"),
        CityOption("graz",        "🇦🇹", "오스트리아", "그라츠",     "Graz",        "Graz",        "Austria",     "Österreich"),
        CityOption("zurich",      "🇨🇭", "스위스",     "취리히",     "Zurich",      "Zürich",      "Switzerland", "Schweiz"),
        CityOption("geneva",      "🇨🇭", "스위스",     "제네바",     "Geneva",      "Genf",        "Switzerland", "Schweiz"),
        CityOption("bern",        "🇨🇭", "스위스",     "베른",       "Berne",       "Bern",        "Switzerland", "Schweiz"),
        CityOption("paris",       "🇫🇷", "프랑스",     "파리",       "Paris",       "Paris",       "France",      "Frankreich"),
        CityOption("london",      "🇬🇧", "영국",       "런던",       "London",      "London",      "UK",          "Vereinigtes Königreich"),
        CityOption("amsterdam",   "🇳🇱", "네덜란드",   "암스테르담", "Amsterdam",   "Amsterdam",   "Netherlands", "Niederlande"),
        CityOption("rome",        "🇮🇹", "이탈리아",   "로마",       "Rome",        "Rom",         "Italy",       "Italien"),
        CityOption("milan",       "🇮🇹", "이탈리아",   "밀라노",     "Milan",       "Mailand",     "Italy",       "Italien"),
        CityOption("new_york",    "🇺🇸", "미국",       "뉴욕",       "New York",    "New York",    "USA",         "USA"),
        CityOption("boston",      "🇺🇸", "미국",       "보스턴",     "Boston",      "Boston",      "USA",         "USA"),
        CityOption("philadelphia","🇺🇸", "미국",       "필라델피아", "Philadelphia","Philadelphia","USA",         "USA"),
        CityOption("cleveland",   "🇺🇸", "미국",       "클리블랜드", "Cleveland",   "Cleveland",   "USA",         "USA"),
        CityOption("los_angeles", "🇺🇸", "미국",       "로스앤젤레스","Los Angeles", "Los Angeles", "USA",         "USA"),
    )

    data class CityGroup(val country: String, val flag: String, val cities: List<CityOption>)

    val cityGroups: List<CityGroup> by lazy {
        val seen = linkedMapOf<String, Int>()
        val groups = mutableListOf<CityGroup>()
        cityOptions.forEach { city ->
            val key = city.localizedCountry
            val idx = seen[key]
            if (idx != null) {
                groups[idx] = groups[idx].copy(cities = groups[idx].cities + city)
            } else {
                seen[key] = groups.size
                groups.add(CityGroup(key, city.flag, listOf(city)))
            }
        }
        groups
    }

    val enrollmentYears: List<Int> by lazy {
        val current = java.util.Calendar.getInstance().get(java.util.Calendar.YEAR)
        (current + 1 downTo 1990).toList()
    }
}
