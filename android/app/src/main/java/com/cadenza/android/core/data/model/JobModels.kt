package com.cadenza.android.core.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class City(
    val id: String,
    val name: String,
    val country: String?  = null,
    val region: String?   = null,
)

@Serializable
data class Job(
    val id: String,
    @SerialName("org_id")        val orgId: String?          = null,
    val type: JobType,
    val title: String,
    val instrument: String?      = null,
    val description: String?     = null,
    @SerialName("deadline_date") val deadlineDate: String?   = null,
    @SerialName("start_date")    val startDate: String?      = null,
    @SerialName("city_id")       val cityId: String?         = null,
    @SerialName("city_name")     val cityName: String?       = null,
    val country: String?         = null,
    @SerialName("contact_email") val contactEmail: String?   = null,
    @SerialName("apply_url")     val applyUrl: String?       = null,
    @SerialName("is_active")     val isActive: Boolean       = true,
    @SerialName("created_at")    val createdAt: String?      = null,
    val org: OrgSummary?         = null,
)

@Serializable
data class NewJob(
    @SerialName("org_id")        val orgId: String,
    val type: JobType,
    val title: String,
    val instrument: String?      = null,
    val description: String?     = null,
    @SerialName("deadline_date") val deadlineDate: String?   = null,
    @SerialName("start_date")    val startDate: String?      = null,
    @SerialName("city_id")       val cityId: String?         = null,
    @SerialName("contact_email") val contactEmail: String?   = null,
    @SerialName("apply_url")     val applyUrl: String?       = null,
)
