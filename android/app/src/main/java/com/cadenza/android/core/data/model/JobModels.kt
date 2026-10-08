package com.cadenza.android.core.data.model

import com.cadenza.android.core.util.AppLocale
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

@Serializable
data class City(
    val id: String,
    val name: String,
    val country: String? = null,
    val region: String?  = null,
) {
    val countryCode: String? get() = country
    val localizedName: String get() = name
}

@Serializable
data class Job(
    val id: String,
    @SerialName("user_id")          val userId: String?          = null,
    val type: JobType,
    val title: String,
    val organization: String?        = null,
    val location: String?            = null,
    val instruments: List<String>    = emptyList(),
    val description: String?         = null,
    val requirements: String?        = null,
    val deadline: String?            = null,
    val contact: String?             = null,
    @SerialName("is_active")         val isActive: Boolean        = true,
    @SerialName("created_at")        val createdAt: String?       = null,
    val source: String?              = null,
    @SerialName("city_id")           val cityId: String?          = null,
    val zone: String?                = null,
    @SerialName("event_start")       val eventStart: String?      = null,
    @SerialName("event_end")         val eventEnd: String?        = null,
    @SerialName("video_audition")    val videoAudition: Boolean?  = null,
    @SerialName("application_fee")   val applicationFee: Int?     = null,
    @SerialName("has_scholarship")   val hasScholarship: Boolean? = null,
    @SerialName("age_min")           val ageMin: Int?             = null,
    @SerialName("age_max")           val ageMax: Int?             = null,
    val status: String?              = null,
    @SerialName("source_url")        val sourceUrl: String?       = null,
    @SerialName("application_url")   val applicationUrl: String?  = null,
    @SerialName("source_language")   val sourceLanguage: String?  = null,
    @SerialName("last_seen_at")      val lastSeenAt: String?      = null,
    @SerialName("quality_score")     val qualityScore: Double?    = null,
    val poster: ProfileLite?         = null,
) {
    val isCurated: Boolean get() = source != null

    val daysLeft: Int? get() {
        val d = deadline ?: return null
        return try {
            val deadlineDate = LocalDate.parse(d, DateTimeFormatter.ISO_LOCAL_DATE)
            ChronoUnit.DAYS.between(LocalDate.now(), deadlineDate).toInt()
        } catch (_: Exception) { null }
    }

    val isAcceptingApplications: Boolean get() =
        isActive && status != "closed" && (daysLeft?.let { it >= 0 } != false)

    val deadlineLabel: String? get() {
        val days = daysLeft ?: return deadline
        return when {
            days < 0  -> null
            days == 0 -> AppLocale.localized("오늘 마감", "Due today", "Heute fällig")
            days == 1 -> AppLocale.localized("내일 마감", "Tomorrow", "Morgen fällig")
            days <= 7 -> AppLocale.localized("${days}일 후", "${days}d left", "Noch ${days}T")
            else      -> deadline
        }
    }
}

@Serializable
data class NewJob(
    @SerialName("user_id")      val userId: String,
    val type: JobType,
    val title: String,
    val organization: String?    = null,
    val location: String?        = null,
    val instruments: List<String> = emptyList(),
    val description: String?     = null,
    val requirements: String?    = null,
    val deadline: String?        = null,
    val contact: String?         = null,
)
