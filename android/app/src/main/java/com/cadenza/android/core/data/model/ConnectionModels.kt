package com.cadenza.android.core.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ConnectionRecord(
    @SerialName("follower_id") val followerId: String,
    @SerialName("followee_id") val followeeId: String,
    val status: String,
    val follower: ConnectedProfile? = null,
)

@Serializable
data class ConnectedProfile(
    val id: String,
    @SerialName("real_name")       val realName: String,
    val instrument: String?        = null,
    val major: String?             = null,
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
