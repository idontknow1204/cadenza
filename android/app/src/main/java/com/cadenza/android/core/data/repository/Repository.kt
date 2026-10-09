package com.cadenza.android.core.data.repository

import android.net.Uri
import android.content.Context
import com.cadenza.android.core.data.model.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Count
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.realtime.realtime
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.storage.storage
import io.github.jan.supabase.gotrue.auth
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.client.call.body
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.JsonNull
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class Repository @Inject constructor(
    private val client: SupabaseClient
) {

    // ─── Column projection constants ──────────────────────────────────────────

    private val activityColumns = "id, user_id, type, title, activity_date, location, role, " +
        "program, prize, organizer, personal_note, image_urls, verification, created_at, " +
        "link_url, link_title, link_description, link_image_url, link_site_name"

    private val activityRowSelect    = "$activityColumns, visibility"
    private val activityWithAuthorSelect =
        "$activityColumns, author:profiles!user_id(id, real_name, instrument, avatar_url)"
    private val nestedActivityWithAuthorSelect =
        "activity:activities($activityWithAuthorSelect)"
    private val activityWithOrgSelect =
        "$activityColumns, author:profiles!user_id(id, real_name, instrument, avatar_url), " +
        "org:organizations!org_id(id, name, logo_url, category)"

    private val jobSelect = "id, user_id, type, title, organization, location, instruments, " +
        "description, requirements, deadline, contact, is_active, created_at, source, city_id, " +
        "zone, event_start, event_end, video_audition, application_fee, has_scholarship, " +
        "age_min, age_max, status, source_url, application_url, source_language, " +
        "last_seen_at, quality_score, poster:profiles!user_id(id, real_name, instrument, avatar_url)"

    private val cvEntrySelect =
        "id, kind, year, period, title, org, place, detail, result, institution, degree, teacher"

    // ─── Profile ──────────────────────────────────────────────────────────────

    suspend fun myProfile(id: String): Profile =
        client.postgrest["profiles"].select { filter { eq("id", id) } }.decodeSingle()

    suspend fun profile(id: String): Profile =
        client.postgrest["profiles"].select { filter { eq("id", id) } }.decodeSingle()

    suspend fun people(excludingMe: String): List<ProfileLite> =
        client.postgrest["profiles"].select(Columns.raw("id, real_name, instrument, avatar_url")) {
            filter {
                neq("id", excludingMe)
                eq("is_system", false)
            }
            order("real_name", Order.ASCENDING)
        }.decodeList()

    suspend fun searchProfiles(query: String, excludingMe: String, major: String? = null): List<ProfileLite> =
        client.postgrest["profiles"].select(Columns.raw("id, real_name, instrument, avatar_url")) {
            filter {
                neq("id", excludingMe)
                if (query.isNotBlank()) ilike("real_name", "%$query%")
                if (major != null) eq("major", major)
            }
            limit(20)
        }.decodeList()

    // ─── Onboarding saves ─────────────────────────────────────────────────────

    suspend fun saveInstrument(id: String, major: String, instrument: String) {
        client.postgrest["profiles"].update(
            buildJsonObject { put("major", major); put("instrument", instrument) }
        ) { filter { eq("id", id) } }
    }

    suspend fun upsertAffiliation(
        userId: String, institutionName: String,
        courseType: String?, enrollmentYear: Int?
    ) {
        val cleaned = institutionName.trim()
        if (cleaned.isEmpty()) return
        val current = affiliations(userId).firstOrNull()
        if (current != null) {
            updateAffiliation(
                id = current.id,
                institutionName = cleaned,
                courseType = courseType,
                enrollmentYear = enrollmentYear,
                graduationYear = current.graduationYear,
                isCurrent = current.isCurrent
            )
        } else {
            insertAffiliation(NewAffiliation(
                userId = userId,
                institutionName = cleaned,
                courseType = courseType,
                enrollmentYear = enrollmentYear
            ))
        }
    }

    suspend fun saveHomeCities(id: String, cities: List<String>) {
        client.postgrest["profiles"].update(
            buildJsonObject { putJsonArray("home_cities") { cities.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) } } }
        ) { filter { eq("id", id) } }
    }

    suspend fun saveBio(id: String, bio: String): Profile =
        client.postgrest["profiles"].update(buildJsonObject { put("bio", bio) }) {
            filter { eq("id", id) }
            select()
        }.decodeSingle()

    suspend fun uploadAvatar(userId: String, bytes: ByteArray): String {
        val path = "${userId.lowercase()}/avatar.jpg"
        client.storage["avatars"].upload(path, bytes, upsert = true)
        val url = client.storage["avatars"].publicUrl(path)
        client.postgrest["profiles"].update(
            buildJsonObject { put("avatar_url", url) }
        ) { filter { eq("id", userId) } }
        return url
    }

    suspend fun updateProfileDetails(
        id: String, realName: String, major: String?, instrument: String?,
        homeCities: List<String>, bio: String, defaultVisibility: Visibility
    ): Profile = client.postgrest["profiles"].update(
        buildJsonObject {
            put("real_name", realName)
            if (major != null) put("major", major) else put("major", JsonNull)
            if (instrument != null) put("instrument", instrument) else put("instrument", JsonNull)
            putJsonArray("home_cities") { homeCities.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) } }
            put("bio", bio)
            put("default_visibility", defaultVisibility.name.lowercase())
        }
    ) { filter { eq("id", id) }; select() }.decodeSingle()

    suspend fun updateDefaultVisibility(id: String, visibility: Visibility) {
        client.postgrest["profiles"].update(
            buildJsonObject { put("default_visibility", visibility.name.lowercase()) }
        ) { filter { eq("id", id) } }
    }

    suspend fun completeOnboarding(id: String, visibility: Visibility) {
        client.postgrest["profiles"].update(
            buildJsonObject {
                put("default_visibility", visibility.name.lowercase())
                put("onboarding_complete", true)
            }
        ) { filter { eq("id", id) } }
    }

    suspend fun updateVisibleSections(id: String, sections: List<String>): Profile =
        client.postgrest["profiles"].update(
            buildJsonObject {
                putJsonArray("visible_sections") {
                    sections.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
                }
            }
        ) { filter { eq("id", id) }; select() }.decodeSingle()

    suspend fun updateProfileLinks(id: String, cvUrl: String?, websiteUrl: String?): Profile =
        client.postgrest["profiles"].update(
            buildJsonObject {
                if (cvUrl != null) put("cv_url", cvUrl) else put("cv_url", JsonNull)
                if (websiteUrl != null) put("website_url", websiteUrl) else put("website_url", JsonNull)
            }
        ) { filter { eq("id", id) }; select() }.decodeSingle()

    // ─── Feed ─────────────────────────────────────────────────────────────────

    @Serializable private data class FeedParams(@SerialName("p_user_id") val pUserId: String)

    suspend fun feed(userId: String): List<ActivityWithAuthor> =
        client.postgrest.rpc("social_feed", FeedParams(userId)).decodeList()

    suspend fun activities(byAuthor: String): List<ActivityWithAuthor> =
        client.postgrest["activities"].select(Columns.raw(activityWithAuthorSelect)) {
            filter { eq("user_id", byAuthor) }
            order("activity_date", Order.DESCENDING)
        }.decodeList()

    // ─── Affiliations ─────────────────────────────────────────────────────────

    suspend fun affiliations(forUser: String): List<Affiliation> =
        client.postgrest["affiliations"].select {
            filter { eq("user_id", forUser) }
            order("enrollment_year", Order.DESCENDING)
        }.decodeList()

    suspend fun insertAffiliation(a: NewAffiliation): Affiliation =
        client.postgrest["affiliations"].insert(a) { select() }.decodeSingle()

    suspend fun updateAffiliation(
        id: String, institutionName: String, courseType: String?,
        enrollmentYear: Int?, graduationYear: Int?, isCurrent: Boolean
    ): Affiliation = client.postgrest["affiliations"].update(
        buildJsonObject {
            put("institution_name", institutionName)
            if (courseType != null) put("course_type", courseType) else put("course_type", JsonNull)
            if (enrollmentYear != null) put("enrollment_year", enrollmentYear) else put("enrollment_year", JsonNull)
            if (graduationYear != null) put("graduation_year", graduationYear) else put("graduation_year", JsonNull)
            put("is_current", isCurrent)
        }
    ) { filter { eq("id", id) }; select() }.decodeSingle()

    suspend fun deleteAffiliation(id: String) {
        client.postgrest["affiliations"].delete { filter { eq("id", id) } }
    }

    // ─── Careers ──────────────────────────────────────────────────────────────

    suspend fun careers(forUser: String): List<Career> =
        client.postgrest["careers"].select {
            filter { eq("user_id", forUser) }
            order("start_year", Order.DESCENDING)
        }.decodeList()

    suspend fun insertCareer(c: NewCareer): Career =
        client.postgrest["careers"].insert(c) { select() }.decodeSingle()

    suspend fun updateCareer(
        id: String, organization: String, role: String,
        startYear: Int?, endYear: Int?, isCurrent: Boolean,
        description: String?, contribution: String?,
        linkUrl: String?, mediaUrl: String?
    ): Career = client.postgrest["careers"].update(
        buildJsonObject {
            put("organization", organization); put("role", role)
            if (startYear != null) put("start_year", startYear) else put("start_year", JsonNull)
            if (endYear != null) put("end_year", endYear) else put("end_year", JsonNull)
            put("is_current", isCurrent)
            if (description != null) put("description", description) else put("description", JsonNull)
            if (contribution != null) put("contribution", contribution) else put("contribution", JsonNull)
            if (linkUrl != null) put("link_url", linkUrl) else put("link_url", JsonNull)
            if (mediaUrl != null) put("media_url", mediaUrl) else put("media_url", JsonNull)
        }
    ) { filter { eq("id", id) }; select() }.decodeSingle()

    suspend fun deleteCareer(id: String) {
        client.postgrest["careers"].delete { filter { eq("id", id) } }
    }

    // ─── Awards ───────────────────────────────────────────────────────────────

    suspend fun awards(forUser: String): List<ProfileAward> =
        client.postgrest["profile_awards"].select {
            filter { eq("user_id", forUser) }
            order("year", Order.DESCENDING)
        }.decodeList()

    suspend fun insertAward(award: ProfileAward): ProfileAward =
        client.postgrest["profile_awards"].insert(award) { select() }.decodeSingle()

    suspend fun updateAward(award: ProfileAward): ProfileAward =
        client.postgrest["profile_awards"].update(award) {
            filter { eq("id", award.id); eq("user_id", award.userId) }
            select()
        }.decodeSingle()

    suspend fun deleteAward(id: String, userId: String) {
        client.postgrest["profile_awards"].delete {
            filter { eq("id", id); eq("user_id", userId) }
        }
    }

    // ─── Languages ────────────────────────────────────────────────────────────

    suspend fun languages(forUser: String): List<ProfileLanguage> =
        client.postgrest["profile_languages"].select {
            filter { eq("user_id", forUser) }
            order("created_at", Order.ASCENDING)
        }.decodeList()

    @Serializable
    private data class LanguagePayload(
        @SerialName("user_id") val userId: String,
        val language: String,
        val level: String
    )

    suspend fun upsertLanguage(userId: String, language: String, level: String): ProfileLanguage =
        client.postgrest["profile_languages"]
            .upsert(LanguagePayload(userId, language, level), onConflict = "user_id, language") {
                select()
            }.decodeSingle()

    suspend fun deleteLanguage(id: String) {
        client.postgrest["profile_languages"].delete { filter { eq("id", id) } }
    }

    // ─── Connections ──────────────────────────────────────────────────────────

    @Serializable
    private data class TransitionParams(
        @SerialName("p_other") val pOther: String,
        @SerialName("p_action") val pAction: String
    )

    suspend fun transitionConnection(other: String, action: ConnectionAction): ConnectionStatus {
        val value: String = client.postgrest
            .rpc("transition_connection", TransitionParams(other, action.raw))
            .decodeSingle()
        return when (value) {
            "connected"        -> ConnectionStatus.Connected
            "requestReceived"  -> ConnectionStatus.RequestReceived
            "requestSent"      -> ConnectionStatus.RequestSent
            else               -> ConnectionStatus.None
        }
    }

    @Serializable private data class UserIdParam(@SerialName("p_user_id") val pUserId: String)

    suspend fun connectionCount(userId: String): Int {
        @Serializable data class NRow(val n: Int)
        val rows: List<NRow> = client.postgrest
            .rpc("connection_count", UserIdParam(userId)).decodeList()
        return rows.firstOrNull()?.n ?: 0
    }

    suspend fun connectionStatus(me: String, them: String): ConnectionStatus = coroutineScope {
        @Serializable data class Row(val status: String)
        val mine = async {
            client.postgrest["follows"].select(Columns.raw("status")) {
                filter { eq("follower_id", me); eq("followee_id", them) }
            }.decodeList<Row>()
        }
        val theirs = async {
            client.postgrest["follows"].select(Columns.raw("status")) {
                filter { eq("follower_id", them); eq("followee_id", me) }
            }.decodeList<Row>()
        }
        val myRow    = mine.await().firstOrNull()
        val theirRow = theirs.await().firstOrNull()
        when {
            myRow?.status == "accepted" || theirRow?.status == "accepted" -> ConnectionStatus.Connected
            myRow?.status == "pending"    -> ConnectionStatus.RequestSent
            theirRow?.status == "pending" -> ConnectionStatus.RequestReceived
            else                          -> ConnectionStatus.None
        }
    }

    suspend fun connections(userId: String): List<ConnectedProfile> =
        client.postgrest.rpc("get_connections", UserIdParam(userId)).decodeList()

    suspend fun pendingConnectionRequests(userId: String): List<ConnectedProfile> {
        @Serializable data class Row(val follower: ConnectedProfile)
        val rows: List<Row> = client.postgrest["follows"]
            .select(Columns.raw("follower:profiles!follower_id(id, real_name, instrument, major, avatar_url)")) {
                filter { eq("followee_id", userId); eq("status", "pending") }
            }.decodeList()
        return rows.map { it.follower }
    }

    suspend fun suggestedProfiles(userId: String): List<SuggestedProfile> =
        client.postgrest.rpc("get_suggested_profiles", UserIdParam(userId)).decodeList()

    suspend fun sendConnectionRequest(to: String): ConnectionStatus =
        transitionConnection(to, ConnectionAction.REQUEST)

    suspend fun acceptConnection(from: String): ConnectionStatus =
        transitionConnection(from, ConnectionAction.ACCEPT)

    suspend fun declineConnection(from: String): ConnectionStatus =
        transitionConnection(from, ConnectionAction.DECLINE)

    suspend fun cancelConnectionRequest(to: String): ConnectionStatus =
        transitionConnection(to, ConnectionAction.CANCEL)

    suspend fun disconnect(them: String): ConnectionStatus =
        transitionConnection(them, ConnectionAction.DISCONNECT)

    // Realtime + polling combined — emits Unit whenever connections change.
    fun connectionChanges(userId: String): Flow<Unit> = flow {
        // 8s polling fallback (Realtime handled by ConnectionStore via this flow)
        while (true) {
            emit(Unit)
            delay(8_000)
        }
    }

    suspend fun deleteAccount() {
        client.postgrest.rpc("delete_my_account")
    }

    // ─── Search ───────────────────────────────────────────────────────────────

    suspend fun searchActivities(query: String): List<ActivityWithAuthor> =
        client.postgrest["activities"].select(Columns.raw(activityWithAuthorSelect)) {
            filter { ilike("title", "%$query%") }
            order("activity_date", Order.DESCENDING)
            limit(20)
        }.decodeList()

    @Serializable private data class SearchOpportunitiesParams(val q: String)

    suspend fun searchOpportunities(query: String): List<Job> =
        client.postgrest.rpc("search_opportunities", SearchOpportunitiesParams(query)).decodeList()

    // ─── Activities ───────────────────────────────────────────────────────────

    suspend fun activity(id: String): Activity =
        client.postgrest["activities"].select { filter { eq("id", id) } }.decodeSingle()

    suspend fun updateActivity(id: String, payload: UpdateActivity) {
        client.postgrest["activities"].update(payload) { filter { eq("id", id) } }
    }

    suspend fun deleteActivity(id: String) {
        client.postgrest["activities"].delete { filter { eq("id", id) } }
    }

    suspend fun createActivity(
        activity: NewActivity,
        imageBytes: List<ByteArray>,
        taggedUserIds: List<String>
    ): Activity {
        val imageUrls = uploadActivityImages(activity.userId, activity.id, imageBytes)
        val readyActivity = activity.copy(imageUrls = imageUrls)
        var inserted = false
        try {
            val created: Activity = client.postgrest["activities"]
                .insert(readyActivity) {
                    select(Columns.raw(activityRowSelect))
                }.decodeSingle()
            inserted = true
            tagUsers(created.id, taggedUserIds)
            return created
        } catch (e: Throwable) {
            if (inserted) runCatching { deleteActivity(activity.id) }
            imageBytes.indices.forEach { i ->
                runCatching {
                    client.storage["activity-images"].delete(activityImagePath(activity.userId, activity.id, i))
                }
            }
            throw e
        }
    }

    suspend fun uploadActivityImage(userId: String, activityId: String, index: Int, bytes: ByteArray): String {
        val path = activityImagePath(userId, activityId, index)
        client.storage["activity-images"].upload(path, bytes)
        return client.storage["activity-images"].publicUrl(path)
    }

    private suspend fun uploadActivityImages(userId: String, activityId: String, imageBytes: List<ByteArray>): List<String> =
        coroutineScope {
            imageBytes.mapIndexed { i, bytes ->
                async { i to uploadActivityImage(userId, activityId, i, bytes) }
            }.map { it.await() }.sortedBy { it.first }.map { it.second }
        }

    private fun activityImagePath(userId: String, activityId: String, index: Int) =
        "${userId.lowercase()}/${activityId.lowercase()}/$index.jpg"

    suspend fun uploadActivityImageEdit(userId: String, activityId: String, bytes: ByteArray): String {
        val name = UUID.randomUUID().toString().lowercase()
        val path = "${userId.lowercase()}/${activityId.lowercase()}/$name.jpg"
        client.storage["activity-images"].upload(path, bytes)
        return client.storage["activity-images"].publicUrl(path)
    }

    suspend fun updateActivityImages(activityId: String, imageUrls: List<String>) {
        client.postgrest["activities"].update(
            buildJsonObject {
                putJsonArray("image_urls") {
                    imageUrls.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
                }
            }
        ) { filter { eq("id", activityId) } }
    }

    // ─── Tags ─────────────────────────────────────────────────────────────────

    @Serializable
    private data class TagPayload(
        @SerialName("activity_id")    val activityId: String,
        @SerialName("tagged_user_id") val taggedUserId: String
    )

    suspend fun tagUsers(activityId: String, userIds: List<String>) {
        if (userIds.isEmpty()) return
        client.postgrest["activity_tags"].insert(
            userIds.map { TagPayload(activityId, it) }
        )
    }

    suspend fun tags(forActivity: String): List<ProfileLite> {
        @Serializable data class W(@SerialName("tagged_user") val taggedUser: ProfileLite?)
        val rows: List<W> = client.postgrest["activity_tags"]
            .select(Columns.raw("tagged_user:profiles(id, real_name, instrument, avatar_url)")) {
                filter { eq("activity_id", forActivity) }
                order("created_at", Order.ASCENDING)
            }.decodeList()
        return rows.mapNotNull { it.taggedUser }
    }

    suspend fun taggedActivities(userId: String): List<ActivityWithAuthor> {
        @Serializable data class W(val activity: ActivityWithAuthor?)
        val rows: List<W> = client.postgrest["activity_tags"]
            .select(Columns.raw(nestedActivityWithAuthorSelect)) {
                filter { eq("tagged_user_id", userId) }
                order("created_at", Order.DESCENDING)
            }.decodeList()
        return rows.mapNotNull { it.activity }
    }

    suspend fun pendingTags(userId: String): List<ActivityWithAuthor> {
        @Serializable data class W(val activity: ActivityWithAuthor?)
        val rows: List<W> = client.postgrest["activity_tags"]
            .select(Columns.raw(nestedActivityWithAuthorSelect)) {
                filter { eq("tagged_user_id", userId); eq("status", "pending") }
                order("created_at", Order.DESCENDING)
            }.decodeList()
        return rows.mapNotNull { it.activity }
    }

    suspend fun acceptTag(activityId: String, userId: String) {
        client.postgrest["activity_tags"].update(buildJsonObject { put("status", "accepted") }) {
            filter { eq("activity_id", activityId); eq("tagged_user_id", userId) }
        }
    }

    suspend fun declineTag(activityId: String, userId: String) {
        client.postgrest["activity_tags"].delete {
            filter { eq("activity_id", activityId); eq("tagged_user_id", userId) }
        }
    }

    // ─── Saves ────────────────────────────────────────────────────────────────

    @Serializable
    private data class SavePayload(
        @SerialName("user_id")     val userId: String,
        @SerialName("activity_id") val activityId: String
    )

    suspend fun saveActivity(userId: String, activityId: String) {
        client.postgrest["activity_saves"].insert(SavePayload(userId, activityId))
    }

    suspend fun unsaveActivity(userId: String, activityId: String) {
        client.postgrest["activity_saves"].delete {
            filter { eq("user_id", userId); eq("activity_id", activityId) }
        }
    }

    suspend fun savedActivities(userId: String): List<ActivityWithAuthor> {
        @Serializable data class W(val activity: ActivityWithAuthor?)
        val rows: List<W> = client.postgrest["activity_saves"]
            .select(Columns.raw(nestedActivityWithAuthorSelect)) {
                filter { eq("user_id", userId) }
                order("created_at", Order.DESCENDING)
            }.decodeList()
        return rows.mapNotNull { it.activity }
    }

    // ─── Confirm inbox ────────────────────────────────────────────────────────

    suspend fun inbox(forUser: String): List<ConfirmRequest> =
        client.postgrest["activity_participants"]
            .select(Columns.raw("id, confirm, $nestedActivityWithAuthorSelect")) {
                filter {
                    eq("participant_id", forUser)
                    eq("confirm", ConfirmStatus.REQUESTED.name.lowercase())
                }
                order("created_at", Order.DESCENDING)
            }.decodeList()

    suspend fun respond(participantRowId: String, approved: Boolean) {
        val status = if (approved) ConfirmStatus.APPROVED else ConfirmStatus.REJECTED
        client.postgrest["activity_participants"]
            .update(buildJsonObject { put("confirm", status.name.lowercase()) }) {
                filter { eq("id", participantRowId) }
            }
    }

    // ─── Likes ────────────────────────────────────────────────────────────────

    @Serializable
    private data class LikePayload(
        @SerialName("activity_id") val activityId: String,
        @SerialName("user_id")     val userId: String
    )

    suspend fun likeActivity(activityId: String, userId: String) {
        client.postgrest["activity_likes"].insert(LikePayload(activityId, userId))
    }

    suspend fun unlikeActivity(activityId: String, userId: String) {
        client.postgrest["activity_likes"].delete {
            filter { eq("activity_id", activityId); eq("user_id", userId) }
        }
    }

    // ─── Comments ─────────────────────────────────────────────────────────────

    @Serializable
    private data class CommentsParams(
        @SerialName("p_activity_id") val pActivityId: String,
        @SerialName("p_user_id")     val pUserId: String
    )

    suspend fun comments(forActivity: String, userId: String): List<ActivityComment> =
        client.postgrest.rpc("get_comments", CommentsParams(forActivity, userId)).decodeList()

    @Serializable
    private data class CommentLikePayload(
        @SerialName("comment_id") val commentId: String,
        @SerialName("user_id")    val userId: String
    )

    suspend fun likeComment(commentId: String, userId: String) {
        client.postgrest["comment_likes"].insert(CommentLikePayload(commentId, userId))
    }

    suspend fun unlikeComment(commentId: String, userId: String) {
        client.postgrest["comment_likes"].delete {
            filter { eq("comment_id", commentId); eq("user_id", userId) }
        }
    }

    @Serializable
    private data class NewCommentPayload(
        @SerialName("activity_id")      val activityId: String,
        @SerialName("user_id")          val userId: String,
        val content: String,
        @SerialName("parent_comment_id") val parentCommentId: String? = null
    )

    suspend fun addComment(activityId: String, userId: String, content: String, parentCommentId: String? = null) {
        client.postgrest["activity_comments"].insert(
            NewCommentPayload(activityId, userId, content, parentCommentId)
        )
    }

    suspend fun deleteComment(id: String) {
        client.postgrest["activity_comments"].delete { filter { eq("id", id) } }
    }

    // ─── Activity stats ───────────────────────────────────────────────────────

    @Serializable
    private data class ActivityStatsParams(
        @SerialName("p_activity_id") val pActivityId: String,
        @SerialName("p_user_id")     val pUserId: String
    )

    suspend fun activityStats(activityId: String, userId: String): ActivityStats {
        val rows: List<ActivityStats> = client.postgrest
            .rpc("activity_stats", ActivityStatsParams(activityId, userId)).decodeList()
        return rows.firstOrNull() ?: ActivityStats()
    }

    // ─── Jobs ─────────────────────────────────────────────────────────────────

    suspend fun jobs(type: JobType? = null): List<Job> =
        client.postgrest["jobs"].select(Columns.raw(jobSelect)) {
            filter {
                eq("is_active", true)
                if (type != null) eq("type", type.name.lowercase())
            }
            order("created_at", Order.DESCENDING)
            limit(80)
        }.decodeList()

    suspend fun myJobs(userId: String): List<Job> =
        client.postgrest["jobs"].select(Columns.raw(jobSelect)) {
            filter { eq("user_id", userId) }
            order("created_at", Order.DESCENDING)
        }.decodeList()

    suspend fun postJob(job: NewJob) {
        client.postgrest["jobs"].insert(job)
    }

    suspend fun closeJob(id: String) {
        client.postgrest["jobs"].update(buildJsonObject { put("is_active", false) }) {
            filter { eq("id", id) }
        }
    }

    // ─── Cities ───────────────────────────────────────────────────────────────

    suspend fun cities(): List<City> =
        client.postgrest["city"].select {
            order("name_en", Order.ASCENDING)
        }.decodeList()

    suspend fun baseCityIds(userId: String): List<String> {
        @Serializable data class Row(@SerialName("city_id") val cityId: String)
        val rows: List<Row> = client.postgrest["user_base_city"]
            .select(Columns.raw("city_id")) { filter { eq("user_id", userId) } }.decodeList()
        return rows.map { it.cityId }
    }

    // ─── Notifications ────────────────────────────────────────────────────────

    suspend fun notifications(userId: String): List<AppNotification> =
        client.postgrest["notifications"]
            .select(Columns.raw("*, sender:profiles!sender_id(real_name, instrument), activity:activities!activity_id(title)")) {
                filter { eq("recipient_id", userId); neq("type", "follow") }
                order("created_at", Order.DESCENDING)
                limit(60)
            }.decodeList()

    suspend fun markAllNotificationsRead(userId: String) {
        client.postgrest["notifications"].update(buildJsonObject { put("is_read", true) }) {
            filter { eq("recipient_id", userId); eq("is_read", false) }
        }
    }

    suspend fun markNotificationsRead(userId: String, ids: List<String>) {
        if (ids.isEmpty()) return
        client.postgrest["notifications"].update(buildJsonObject { put("is_read", true) }) {
            filter { eq("recipient_id", userId); isIn("id", ids) }
        }
    }

    suspend fun unreadNotificationCount(userId: String): Int {
        val result = client.postgrest["notifications"].select(Columns.ALL, head = true) {
            filter { eq("recipient_id", userId); neq("type", "follow"); eq("is_read", false) }
            count(Count.EXACT)
        }
        return result.countOrNull()?.toInt() ?: 0
    }

    // ─── Organizations ────────────────────────────────────────────────────────

    private val orgSelect = "id, name, handle, description, logo_url, website, category, created_by"

    suspend fun myOrgs(userId: String): List<Organization> {
        @Serializable data class Row(val org: Organization)
        val rows: List<Row> = client.postgrest["org_admins"]
            .select(Columns.raw("org:$orgSelect")) { filter { eq("user_id", userId) } }.decodeList()
        return rows.map { it.org }
    }

    suspend fun fetchOrg(id: String): Organization =
        client.postgrest["organizations"].select(Columns.raw(orgSelect)) {
            filter { eq("id", id) }
        }.decodeSingle()

    @Serializable
    private data class NewOrgPayload(
        val name: String, val handle: String, val category: String,
        val description: String?, val website: String?,
        @SerialName("created_by") val createdBy: String
    )

    @Serializable
    private data class OrgAdminPayload(
        @SerialName("org_id")  val orgId: String,
        @SerialName("user_id") val userId: String,
        val role: String
    )

    suspend fun createOrg(
        name: String, handle: String, category: OrgCategory,
        description: String?, website: String?, createdBy: String
    ): Organization {
        val org: Organization = client.postgrest["organizations"]
            .insert(NewOrgPayload(name, handle, category.name.lowercase(), description, website, createdBy)) {
                select(Columns.raw(orgSelect))
            }.decodeSingle()
        client.postgrest["org_admins"].insert(OrgAdminPayload(org.id, createdBy, "owner"))
        return org
    }

    suspend fun orgFollowerCount(orgId: String): Int {
        val result = client.postgrest["org_follows"].select(Columns.ALL, head = true) {
            filter { eq("org_id", orgId) }
            count(Count.EXACT)
        }
        return result.countOrNull()?.toInt() ?: 0
    }

    suspend fun isFollowingOrg(orgId: String, userId: String): Boolean {
        val result = client.postgrest["org_follows"].select(Columns.ALL, head = true) {
            filter { eq("org_id", orgId); eq("user_id", userId) }
            count(Count.EXACT)
        }
        return (result.countOrNull() ?: 0) > 0
    }

    @Serializable
    private data class OrgFollowPayload(
        @SerialName("org_id")  val orgId: String,
        @SerialName("user_id") val userId: String
    )

    suspend fun followOrg(orgId: String, userId: String) {
        client.postgrest["org_follows"].insert(OrgFollowPayload(orgId, userId))
    }

    suspend fun unfollowOrg(orgId: String, userId: String) {
        client.postgrest["org_follows"].delete {
            filter { eq("org_id", orgId); eq("user_id", userId) }
        }
    }

    suspend fun orgActivities(orgId: String): List<ActivityWithAuthor> =
        client.postgrest["activities"].select(Columns.raw(activityWithOrgSelect)) {
            filter { eq("org_id", orgId) }
            order("activity_date", Order.DESCENDING)
        }.decodeList()

    // ─── CV (Fermata) ─────────────────────────────────────────────────────────

    suspend fun updateCVFields(
        id: String, nameEn: String?, eyebrow: String?,
        birthDate: String?, phone: String?, address: String?
    ) {
        client.postgrest["profiles"].update(
            buildJsonObject {
                if (nameEn != null) put("name_en", nameEn) else put("name_en", JsonNull)
                if (eyebrow != null) put("eyebrow", eyebrow) else put("eyebrow", JsonNull)
                if (birthDate != null) put("birth_date", birthDate) else put("birth_date", JsonNull)
                if (phone != null) put("phone", phone) else put("phone", JsonNull)
                if (address != null) put("address", address) else put("address", JsonNull)
            }
        ) { filter { eq("id", id) } }
    }

    suspend fun saveRepertoire(id: String, items: List<String>) {
        client.postgrest["profiles"].update(
            buildJsonObject {
                putJsonArray("repertoire") {
                    items.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
                }
            }
        ) { filter { eq("id", id) } }
    }

    suspend fun cvActivities(userId: String): List<Activity> =
        client.postgrest["activities"].select(Columns.raw(activityRowSelect)) {
            filter { eq("user_id", userId) }
            order("activity_date", Order.DESCENDING)
        }.decodeList()

    suspend fun cvEntries(userId: String): List<CVEntryRow> =
        client.postgrest["cv_entries"].select(Columns.raw(cvEntrySelect)) {
            filter { eq("user_id", userId) }
            order("year", Order.DESCENDING)
        }.decodeList()

    @Serializable
    private data class CVEntryPayload(
        @SerialName("user_id")    val userId: String,
        val kind: String,
        val year: Int?      = null,
        val period: String? = null,
        val title: String?  = null,
        val org: String?    = null,
        val place: String?  = null,
        val detail: String? = null,
        val result: String? = null,
        val institution: String? = null,
        val degree: String? = null,
        val teacher: String? = null
    )

    private fun toPayload(userId: String, r: CVEntryRow) =
        CVEntryPayload(userId, r.kind, r.year, r.period, r.title, r.org,
            r.place, r.detail, r.result, r.institution, r.degree, r.teacher)

    suspend fun createCVEntry(userId: String, r: CVEntryRow) {
        client.postgrest["cv_entries"].insert(toPayload(userId, r))
    }

    suspend fun updateCVEntry(userId: String, r: CVEntryRow) {
        client.postgrest["cv_entries"].update(toPayload(userId, r)) {
            filter { eq("id", r.id) }
        }
    }

    suspend fun deleteCVEntry(id: String) {
        client.postgrest["cv_entries"].delete { filter { eq("id", id) } }
    }

    suspend fun cvOverrides(userId: String, lang: String = "en"): List<CVOverride> =
        client.postgrest["cv_i18n"].select(Columns.raw("source_kind, source_id, patch, include")) {
            filter { eq("user_id", userId); eq("lang", lang) }
        }.decodeList()

    @Serializable
    private data class CVOverrideRow(
        @SerialName("source_kind") val sourceKind: String,
        @SerialName("source_id")   val sourceId: String,
        @SerialName("user_id")     val userId: String,
        val lang: String,
        val patch: Map<String, String>,
        val include: Boolean
    )

    suspend fun upsertCVOverride(userId: String, override: CVOverride, lang: String = "en") {
        client.postgrest["cv_i18n"].upsert(
            CVOverrideRow(override.sourceKind, override.sourceId, userId, lang, override.patch, override.include),
            onConflict = "source_kind,source_id,lang"
        )
    }

    suspend fun profileOverlay(userId: String, lang: String): Map<String, String> {
        @Serializable data class Row(val patch: Map<String, String>)
        val rows: List<Row> = client.postgrest["cv_i18n"].select(Columns.raw("patch")) {
            filter {
                eq("source_kind", "profile")
                eq("source_id", userId)
                eq("lang", lang)
            }
        }.decodeList()
        return rows.firstOrNull()?.patch ?: emptyMap()
    }

    suspend fun upsertProfileOverlay(userId: String, lang: String, patch: Map<String, String>) {
        client.postgrest["cv_i18n"].upsert(
            CVOverrideRow("profile", userId, userId, lang, patch, true),
            onConflict = "source_kind,source_id,lang"
        )
    }

    suspend fun setProfileLangs(id: String, langs: List<String>) {
        client.postgrest["profiles"].update(
            buildJsonObject {
                putJsonArray("profile_langs") {
                    langs.forEach { add(kotlinx.serialization.json.JsonPrimitive(it)) }
                }
            }
        ) { filter { eq("id", id) } }
    }

    // ─── CV Edge Functions ────────────────────────────────────────────────────

    @Serializable private data class TranslateReq(
        val kind: String,
        val fields: Map<String, String>,
        @SerialName("targetLang") val targetLang: String
    )
    @Serializable private data class TranslateRes(
        val translations: Map<String, String>? = null,
        val error: String? = null
    )

    suspend fun translateCVEntry(kind: String, fields: Map<String, String>, targetLang: String = "en"): Map<String, String> {
        val res = client.functions
            .invoke("cv-translate", body = TranslateReq(kind, fields, targetLang))
            .body<TranslateRes>()
        if (res.error != null) throw RuntimeException(res.error)
        return res.translations ?: emptyMap()
    }

    @Serializable private data class CVExportRes(val url: String? = null, val error: String? = null)

    suspend fun exportCV(): String {
        val res = client.functions
            .invoke("cv-export", body = kotlinx.serialization.json.JsonObject(emptyMap()))
            .body<CVExportRes>()
        if (res.error != null) throw RuntimeException(res.error)
        return res.url ?: throw RuntimeException("no url returned")
    }

    // ─── Recommendations ──────────────────────────────────────────────────────

    suspend fun recommendations(forUser: String): List<Recommendation> =
        client.postgrest["recommendations"].select {
            filter { eq("recipient_id", forUser) }
            order("created_at", Order.DESCENDING)
        }.decodeList()

    @Serializable
    private data class NewRecommendationPayload(
        @SerialName("recipient_id")      val recipientId: String,
        @SerialName("recommender_name")  val recommenderName: String,
        @SerialName("recommender_title") val recommenderTitle: String?,
        val body: String
    )

    suspend fun addRecommendation(
        recipientId: String, recommenderName: String,
        recommenderTitle: String?, body: String
    ): Recommendation =
        client.postgrest["recommendations"]
            .insert(NewRecommendationPayload(recipientId, recommenderName, recommenderTitle, body)) {
                select()
            }.decodeSingle()

    @Serializable
    private data class UpdateRecommendationPayload(
        @SerialName("recommender_name")  val recommenderName: String,
        @SerialName("recommender_title") val recommenderTitle: String?,
        val body: String,
        @SerialName("is_visible") val isVisible: Boolean
    )

    suspend fun updateRecommendation(id: String, recommenderName: String,
                                     recommenderTitle: String?, body: String, isVisible: Boolean) {
        client.postgrest["recommendations"]
            .update(UpdateRecommendationPayload(recommenderName, recommenderTitle, body, isVisible)) {
                filter { eq("id", id) }
            }
    }

    suspend fun deleteRecommendation(id: String) {
        client.postgrest["recommendations"].delete { filter { eq("id", id) } }
    }

    // ─── Instagram Import ─────────────────────────────────────────────────────

    @Serializable private data class InstagramImportReq(val url: String)
    @Serializable private data class InstagramImportResponse(
        val caption: String? = null,
        val thumbnailUrl: String? = null,
        val error: String? = null
    )

    suspend fun importFromInstagram(url: String): InstagramImportResult {
        val res = client.functions
            .invoke("instagram-import", body = InstagramImportReq(url))
            .body<InstagramImportResponse>()
        if (res.error != null) throw RuntimeException(res.error)
        return InstagramImportResult(caption = res.caption ?: "", thumbnailUrl = res.thumbnailUrl)
    }

    // ─── CV Upload ────────────────────────────────────────────────────────────

    suspend fun uploadCV(bytes: ByteArray): String {
        val authId = client.auth.currentSessionOrNull()?.user?.id
            ?: throw IllegalStateException("No active session")
        val path = "${authId.lowercase()}/cv.pdf"
        client.storage["user-files"].upload(path, bytes, upsert = true)
        return client.storage["user-files"].publicUrl(path)
    }

    // ─── Teacher / lineage ────────────────────────────────────────────────────

    suspend fun saveTeacher(studentId: String, teacherId: String?, teacherName: String) {
        val payload = buildJsonObject {
            put("student_id", studentId)
            put("teacher_name", teacherName)
            if (teacherId != null) put("teacher_id", teacherId)
        }
        client.postgrest["lineage"].upsert(payload, onConflict = "teacher_id, student_id")
    }
}
