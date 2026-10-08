package com.cadenza.android.core.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ProfileLite(
    val id: String,
    @SerialName("real_name")  val realName: String,
    val instrument: String?   = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
)

@Serializable
data class Profile(
    val id: String,
    @SerialName("real_name")           var realName: String,
    var major: String?                 = null,
    var instrument: String?            = null,
    @SerialName("home_cities")         var homeCities: List<String>   = emptyList(),
    var bio: String?                   = null,
    @SerialName("avatar_url")          var avatarUrl: String?         = null,
    @SerialName("default_visibility")  var defaultVisibility: Visibility = Visibility.INDUSTRY_FOLLOWERS,
    @SerialName("onboarding_complete") var onboardingComplete: Boolean = false,
    @SerialName("visible_sections")    var visibleSections: List<String> = emptyList(),
    @SerialName("cv_url")              var cvUrl: String?             = null,
    @SerialName("website_url")         var websiteUrl: String?        = null,
    // Fermata CV fields (migrations 0030/0031)
    @SerialName("name_en")             var nameEn: String?            = null,
    var eyebrow: String?               = null,
    @SerialName("birth_year")          var birthYear: Int?            = null,
    @SerialName("birth_date")          var birthDate: String?         = null,
    var phone: String?                 = null,
    var address: String?               = null,
    var repertoire: List<String>?      = null,
    @SerialName("profile_langs")       var profileLangs: List<String>? = null,
) {
    fun showsSection(section: ProfileSection): Boolean = visibleSections.contains(section.raw)
}

@Serializable
data class Affiliation(
    val id: String,
    @SerialName("user_id")          val userId: String,
    @SerialName("institution_name") var institutionName: String,
    @SerialName("course_type")      var courseType: String?    = null,
    @SerialName("enrollment_year")  var enrollmentYear: Int?   = null,
    @SerialName("graduation_year")  var graduationYear: Int?   = null,
    @SerialName("is_current")       var isCurrent: Boolean     = true,
)

@Serializable
data class NewAffiliation(
    @SerialName("user_id")          val userId: String,
    @SerialName("institution_name") val institutionName: String,
    @SerialName("course_type")      val courseType: String?    = null,
    @SerialName("enrollment_year")  val enrollmentYear: Int?   = null,
    @SerialName("graduation_year")  val graduationYear: Int?   = null,
    @SerialName("is_current")       val isCurrent: Boolean     = true,
)

@Serializable
data class Career(
    val id: String,
    @SerialName("user_id")      val userId: String,
    var organization: String,
    var role: String,
    @SerialName("start_year")   var startYear: Int?       = null,
    @SerialName("end_year")     var endYear: Int?         = null,
    @SerialName("is_current")   var isCurrent: Boolean    = false,
    var description: String?    = null,
    var contribution: String?   = null,
    @SerialName("link_url")     var linkUrl: String?      = null,
    @SerialName("media_url")    var mediaUrl: String?     = null,
)

@Serializable
data class NewCareer(
    @SerialName("user_id")    val userId: String,
    val organization: String,
    val role: String,
    @SerialName("start_year") val startYear: Int?    = null,
    @SerialName("end_year")   val endYear: Int?      = null,
    @SerialName("is_current") val isCurrent: Boolean = false,
    val description: String?  = null,
    val contribution: String? = null,
    @SerialName("link_url")   val linkUrl: String?   = null,
    @SerialName("media_url")  val mediaUrl: String?  = null,
)

@Serializable
data class ProfileAward(
    val id: String,
    @SerialName("user_id") val userId: String,
    var title: String,
    var prize: String,
    var issuer: String,
    var year: Int,
    var details: String    = "",
    @SerialName("link_url") var linkUrl: String = "",
)

@Serializable
data class ProfileLanguage(
    val id: String,
    @SerialName("user_id") val userId: String,
    var language: String,
    var level: String,
)

@Serializable
data class Recommendation(
    val id: String,
    @SerialName("recommender_name")    var recommenderName: String,
    @SerialName("recommender_title")   var recommenderTitle: String?  = null,
    @SerialName("recommender_user_id") var recommenderUserId: String? = null,
    var body: String,
    @SerialName("is_visible")          var isVisible: Boolean         = true,
    @SerialName("created_at")          val createdAt: String?         = null,
)

// CV 전용 항목 (cv_entries)
@Serializable
data class CVEntryRow(
    val id: String,
    val kind: String,   // performance | competition | education | masterclass
    val year: Int?      = null,
    val period: String? = null,
    val title: String?  = null,
    val org: String?    = null,
    val place: String?  = null,
    val detail: String? = null,
    val result: String? = null,
    val institution: String? = null,
    val degree: String? = null,
    val teacher: String? = null,
)

// cv_i18n 오버레이 (언어별 CV 항목 표기)
@Serializable
data class CVOverride(
    @SerialName("source_kind") val sourceKind: String,
    @SerialName("source_id")   val sourceId: String,
    val patch: Map<String, String>,
    val include: Boolean,
)
