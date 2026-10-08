package com.cadenza.android.core.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// iOS Activity 모델 이관. UUID 필드는 JSON 문자열(String)로 표현.

@Serializable
data class Activity(
    val id: String,
    @SerialName("user_id")       val userId: String,
    val type: ActivityType,
    val title: String,
    @SerialName("activity_date") val activityDate: String,
    val location: String?        = null,
    val role: String?            = null,
    val program: String?         = null,
    val prize: String?           = null,
    val organizer: String?       = null,
    @SerialName("personal_note") val personalNote: String? = null,
    @SerialName("image_urls")    val imageUrls: List<String> = emptyList(),
    val verification: VerificationStatus = VerificationStatus.PENDING,
    val visibility: Visibility   = Visibility.PUBLIC,
    @SerialName("created_at")    val createdAt: String?    = null,
    @SerialName("link_url")      val linkUrl: String?      = null,
    @SerialName("link_title")    val linkTitle: String?    = null,
    @SerialName("link_description") val linkDescription: String? = null,
    @SerialName("link_image_url") val linkImageUrl: String? = null,
    @SerialName("link_site_name") val linkSiteName: String? = null,
)

@Serializable
data class ActivityWithAuthor(
    val id: String,
    @SerialName("user_id")       val userId: String,
    val type: ActivityType,
    val title: String,
    @SerialName("activity_date") val activityDate: String,
    val location: String?        = null,
    val role: String?            = null,
    val program: String?         = null,
    val prize: String?           = null,
    val organizer: String?       = null,
    @SerialName("personal_note") val personalNote: String? = null,
    @SerialName("image_urls")    val imageUrls: List<String> = emptyList(),
    val verification: VerificationStatus = VerificationStatus.PENDING,
    @SerialName("created_at")    val createdAt: String?    = null,
    val author: ProfileLite?     = null,
    val org: OrgSummary?         = null,
    @SerialName("feed_reason")   val feedReason: String?   = null,
    @SerialName("link_url")      val linkUrl: String?      = null,
    @SerialName("link_title")    val linkTitle: String?    = null,
    @SerialName("link_description") val linkDescription: String? = null,
    @SerialName("link_image_url") val linkImageUrl: String? = null,
    @SerialName("link_site_name") val linkSiteName: String? = null,
)

@Serializable
data class ActivityStats(
    @SerialName("like_count")    val likeCount: Int    = 0,
    @SerialName("comment_count") val commentCount: Int = 0,
    @SerialName("is_liked")      val isLiked: Boolean  = false,
    @SerialName("is_saved")      val isSaved: Boolean  = false,
)

@Serializable
data class ActivityComment(
    val id: String,
    @SerialName("activity_id")      val activityId: String,
    @SerialName("user_id")          val userId: String,
    val content: String,
    @SerialName("created_at")       val createdAt: String,
    @SerialName("parent_comment_id") val parentCommentId: String? = null,
    val author: ProfileLite?        = null,
    @SerialName("like_count")       var likeCount: Int    = 0,
    @SerialName("is_liked")         var isLiked: Boolean  = false,
)

@Serializable
data class ConfirmRequest(
    val id: String,
    val confirm: ConfirmStatus,
    val activity: ActivityWithAuthor? = null,
)

// ─── Insert/Update payloads ────────────────────────────────────────────────

@Serializable
data class NewActivity(
    val id: String,                          // UUID pre-generated on client
    @SerialName("user_id")       val userId: String,
    @SerialName("org_id")        val orgId: String?  = null,
    val type: ActivityType,
    val title: String,
    @SerialName("activity_date") val activityDate: String,
    val location: String?        = null,
    val role: String?            = null,
    val program: String?         = null,
    val prize: String?           = null,
    val organizer: String?       = null,
    @SerialName("personal_note") val personalNote: String? = null,
    val visibility: Visibility,
    @SerialName("link_url")      val linkUrl: String?      = null,
    @SerialName("link_title")    val linkTitle: String?    = null,
    @SerialName("link_description") val linkDescription: String? = null,
    @SerialName("link_image_url") val linkImageUrl: String? = null,
    @SerialName("link_site_name") val linkSiteName: String? = null,
    @SerialName("image_urls")    val imageUrls: List<String> = emptyList(),
)

@Serializable
data class UpdateActivity(
    val type: ActivityType,
    val title: String,
    @SerialName("activity_date") val activityDate: String,
    val location: String?        = null,
    val role: String?            = null,
    val program: String?         = null,
    val prize: String?           = null,
    val organizer: String?       = null,
    @SerialName("personal_note") val personalNote: String? = null,
    val visibility: Visibility,
    @SerialName("link_url")      val linkUrl: String?      = null,
    @SerialName("link_title")    val linkTitle: String?    = null,
    @SerialName("link_description") val linkDescription: String? = null,
    @SerialName("link_image_url") val linkImageUrl: String? = null,
    @SerialName("link_site_name") val linkSiteName: String? = null,
)

@Serializable
data class NewParticipant(
    @SerialName("activity_id")    val activityId: String,
    @SerialName("participant_id") val participantId: String,
    val role: String? = null,
)

data class InstagramImportResult(
    val caption: String,
    val thumbnailUrl: String?,
)
