package com.cadenza.android.core.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ConnectionRecord(
    val id: String,
    @SerialName("requester_id")  val requesterId: String,
    @SerialName("addressee_id")  val addresseeId: String,
    val status: String,
    @SerialName("created_at")    val createdAt: String?  = null,
)

@Serializable
data class ConnectedProfile(
    val id: String,
    @SerialName("real_name")       val realName: String,
    val instrument: String?        = null,
    @SerialName("avatar_url")      val avatarUrl: String? = null,
    @SerialName("connection_date") val connectionDate: String? = null,
)

@Serializable
data class SuggestedProfile(
    val id: String,
    @SerialName("real_name")   val realName: String,
    val instrument: String?    = null,
    @SerialName("avatar_url")  val avatarUrl: String?  = null,
    @SerialName("mutual_count") val mutualCount: Int   = 0,
)
