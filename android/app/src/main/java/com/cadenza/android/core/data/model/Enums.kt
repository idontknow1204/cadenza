package com.cadenza.android.core.data.model

import com.cadenza.android.core.util.AppLocale
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class JobType {
    @SerialName("audition") AUDITION,
    @SerialName("position") POSITION,
    @SerialName("lesson")   LESSON,
    @SerialName("gig")      GIG;

    val label: String get() = when (this) {
        AUDITION -> AppLocale.localized("오디션",    "Audition",  "Vorspiel")
        POSITION -> AppLocale.localized("단원 모집", "Position",  "Stelle")
        LESSON   -> AppLocale.localized("레슨",      "Lesson",    "Unterricht")
        GIG      -> AppLocale.localized("연주 의뢰", "Gig",       "Engagement")
    }
    val symbol: String get() = when (this) {
        AUDITION -> "music_mic"
        POSITION -> "building_2"
        LESSON   -> "graduationcap"
        GIG      -> "music_note_list"
    }
}

@Serializable
enum class OrgCategory {
    @SerialName("orchestra") ORCHESTRA,
    @SerialName("school")    SCHOOL,
    @SerialName("label")     LABEL,
    @SerialName("venue")     VENUE,
    @SerialName("agency")    AGENCY,
    @SerialName("other")     OTHER;

    val label: String get() = when (this) {
        ORCHESTRA -> AppLocale.localized("오케스트라/앙상블", "Orchestra/Ensemble", "Orchester/Ensemble")
        SCHOOL    -> AppLocale.localized("음악학교/대학교",   "Music School",        "Musikschule")
        LABEL     -> AppLocale.localized("음반사/레이블",     "Label/Publisher",     "Label")
        VENUE     -> AppLocale.localized("공연장",           "Venue",               "Veranstaltungsort")
        AGENCY    -> AppLocale.localized("에이전시/프로덕션", "Agency",              "Agentur")
        OTHER     -> AppLocale.localized("기타",             "Other",               "Sonstiges")
    }
}

@Serializable
enum class ActivityType {
    @SerialName("performance") PERFORMANCE,
    @SerialName("competition") COMPETITION,
    @SerialName("education")   EDUCATION,
    @SerialName("recording")   RECORDING;

    val localizedLabel: String get() = when (this) {
        PERFORMANCE -> AppLocale.localized("연주",       "Performance", "Auftritt")
        COMPETITION -> AppLocale.localized("경연",       "Competition", "Wettbewerb")
        EDUCATION   -> AppLocale.localized("교육",       "Education",   "Ausbildung")
        RECORDING   -> AppLocale.localized("음반/미디어","Recording",   "Aufnahme")
    }
    val symbol: String get() = when (this) {
        PERFORMANCE -> "music_note"
        COMPETITION -> "trophy"
        EDUCATION   -> "graduationcap"
        RECORDING   -> "opticaldisc"
    }
    val localizedTitleHint: String get() = when (this) {
        PERFORMANCE -> AppLocale.localized("공연명",        "Concert name",      "Konzertname")
        COMPETITION -> AppLocale.localized("대회명",        "Competition name",  "Wettbewerbsname")
        EDUCATION   -> AppLocale.localized("강좌·과목명",   "Course name",       "Kursname")
        RECORDING   -> AppLocale.localized("앨범·음원 제목","Album title",       "Albumtitel")
    }
    val localizedLocationHint: String get() = when (this) {
        PERFORMANCE -> AppLocale.localized("공연장",       "Venue",       "Veranstaltungsort")
        COMPETITION -> AppLocale.localized("개최지",       "Location",    "Ort")
        EDUCATION   -> AppLocale.localized("기관명",       "Institution", "Institution")
        RECORDING   -> AppLocale.localized("레이블·스튜디오","Label / Studio","Label / Studio")
    }
    val localizedDateLabel: String get() =
        if (this == RECORDING) AppLocale.localized("발매일","Release date","Erscheinungsdatum")
        else AppLocale.localized("날짜","Date","Datum")
}

@Serializable
enum class VerificationStatus {
    @SerialName("pending")               PENDING,
    @SerialName("institution_verified")  INSTITUTION_VERIFIED;
}

@Serializable
enum class ConfirmStatus {
    @SerialName("requested") REQUESTED,
    @SerialName("approved")  APPROVED,
    @SerialName("rejected")  REJECTED;
}

@Serializable
enum class Visibility {
    @SerialName("public")               PUBLIC,
    @SerialName("industry_followers")   INDUSTRY_FOLLOWERS,
    @SerialName("followers")            FOLLOWERS,
    @SerialName("private")              PRIVATE;

    val localizedLabel: String get() = when (this) {
        PUBLIC             -> AppLocale.localized("전체 공개",   "Public",                 "Öffentlich")
        INDUSTRY_FOLLOWERS -> AppLocale.localized("업계+팔로워", "Industry + followers",   "Branche + Follower")
        FOLLOWERS          -> AppLocale.localized("팔로워만",    "Followers only",         "Nur Follower")
        PRIVATE            -> AppLocale.localized("나만 보기",   "Only me",                "Nur ich")
    }
}

enum class ProfileSection(val raw: String) {
    BIO("bio"),
    ACTIVITIES("activities"),
    CAREER("career"),
    EDUCATION("education"),
    AWARDS("awards"),
    LANGUAGES("languages"),
    CV_WEBSITE("cv_website"),
    RECOMMENDATIONS("recommendations"),
    ORG("org");

    val title: String get() = when (this) {
        BIO             -> AppLocale.localized("소개",       "About",              "Über mich")
        ACTIVITIES      -> AppLocale.localized("나의 활동",  "My Activities",      "Meine Aktivitäten")
        CAREER          -> AppLocale.localized("경력사항",   "Career",             "Berufserfahrung")
        EDUCATION       -> AppLocale.localized("학력",       "Education",          "Ausbildung")
        AWARDS          -> AppLocale.localized("수상 경력",  "Honors & Awards",    "Auszeichnungen")
        LANGUAGES       -> AppLocale.localized("언어",       "Languages",          "Sprachen")
        CV_WEBSITE      -> AppLocale.localized("CV / 홈페이지","CV / Website",     "CV / Webseite")
        RECOMMENDATIONS -> AppLocale.localized("추천서",     "Recommendations",    "Empfehlungen")
        ORG             -> AppLocale.localized("기관 페이지","Organization Page",  "Organisationsseite")
    }
}

// Connection 전환 액션 (iOS ConnectionAction 동일)
enum class ConnectionAction(val raw: String) {
    REQUEST("request"),
    ACCEPT("accept"),
    DECLINE("decline"),
    CANCEL("cancel"),
    DISCONNECT("disconnect")
}

// Client-side 연결 상태 (UI 표현용)
sealed class ConnectionStatus {
    data object None             : ConnectionStatus()
    data object RequestSent      : ConnectionStatus()
    data object RequestReceived  : ConnectionStatus()
    data object Connected        : ConnectionStatus()
}
