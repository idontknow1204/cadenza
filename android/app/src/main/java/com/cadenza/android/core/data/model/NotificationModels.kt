package com.cadenza.android.core.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class AppNotification(
    val id: String,
    @SerialName("user_id")      val userId: String,
    val type: String,
    @SerialName("actor_id")     val actorId: String?     = null,
    @SerialName("activity_id")  val activityId: String?  = null,
    @SerialName("comment_id")   val commentId: String?   = null,
    @SerialName("job_id")       val jobId: String?       = null,
    val message: String?        = null,
    @SerialName("is_read")      var isRead: Boolean      = false,
    @SerialName("created_at")   val createdAt: String,
    val actor: ProfileLite?     = null,
)
