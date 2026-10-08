package com.cadenza.android.core.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class OrgSummary(
    val id: String,
    val name: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
)

@Serializable
data class Organization(
    val id: String,
    val name: String,
    val category: OrgCategory?              = null,
    val bio: String?                        = null,
    @SerialName("avatar_url")  var avatarUrl: String?    = null,
    @SerialName("website_url") val websiteUrl: String?   = null,
    @SerialName("country")     val country: String?      = null,
    @SerialName("city_name")   val cityName: String?     = null,
    @SerialName("admin_id")    val adminId: String?      = null,
    @SerialName("created_at")  val createdAt: String?    = null,
    @SerialName("member_count") val memberCount: Int?    = null,
    @SerialName("is_member")   val isMember: Boolean     = false,
    @SerialName("is_admin")    val isAdmin: Boolean      = false,
)
