import Foundation
import UIKit
import Supabase

struct Repository {
    let client: SupabaseClient

    private static let jobSelect = """
    id, user_id, type, title, organization, location, instruments, description, requirements,
    deadline, contact, is_active, created_at, source, city_id, zone, event_start, event_end,
    video_audition, application_fee, has_scholarship, age_min, age_max, status,
    source_url, application_url, source_language, last_seen_at, quality_score,
    poster:profiles!user_id(id, real_name, instrument)
    """

    // MARK: - Profile

    func myProfile(id: UUID) async throws -> Profile {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func profile(id: UUID) async throws -> Profile {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func people(excluding me: UUID) async throws -> [ProfileLite] {
        try await client
            .from("profiles")
            .select("id, real_name, instrument")
            .neq("id", value: me)
            .eq("is_system", value: false)
            .order("real_name")
            .execute()
            .value
    }

    func searchProfiles(query: String, excluding me: UUID, major: String? = nil) async throws -> [ProfileLite] {
        var builder = client
            .from("profiles")
            .select("id, real_name, instrument")
            .neq("id", value: me)
        if !query.isEmpty {
            builder = builder.ilike("real_name", pattern: "%\(query)%")
        }
        if let major {
            builder = builder.eq("major", value: major)
        }
        return try await builder.limit(20).execute().value
    }

    // MARK: - Onboarding saves (each step persists immediately)

    func saveInstrument(id: UUID, major: String, instrument: String) async throws {
        try await client
            .from("profiles")
            .update(["major": major, "instrument": instrument])
            .eq("id", value: id)
            .execute()
    }

    func upsertAffiliation(userId: UUID, institutionName: String,
                           courseType: String?, enrollmentYear: Int?) async throws {
        // Delete current affiliations then insert fresh (single school for MVP)
        try await client
            .from("affiliations")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        try await client
            .from("affiliations")
            .insert(NewAffiliation(userId: userId,
                                   institutionName: institutionName,
                                   courseType: courseType,
                                   enrollmentYear: enrollmentYear,
                                   graduationYear: nil))
            .execute()
    }

    func saveHomeCities(id: UUID, cities: [String]) async throws {
        try await client
            .from("profiles")
            .update(["home_cities": cities])
            .eq("id", value: id)
            .execute()
    }

    func saveTeacher(studentId: UUID, teacherId: UUID?, teacherName: String) async throws {
        var payload: [String: AnyJSON] = ["student_id": .string(studentId.uuidString),
                                          "teacher_name": .string(teacherName)]
        if let tid = teacherId { payload["teacher_id"] = .string(tid.uuidString) }
        try await client
            .from("lineage")
            .upsert(payload, onConflict: "teacher_id, student_id")
            .execute()
    }

    func saveBio(id: UUID, bio: String) async throws {
        try await client
            .from("profiles")
            .update(["bio": bio])
            .eq("id", value: id)
            .execute()
    }

    func uploadAvatar(userId: UUID, image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.cannotDecodeContentData)
        }
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        try await client.storage
            .from("avatars")
            .upload(path, data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true))
        let url = try client.storage.from("avatars").getPublicURL(path: path)
        // Save the URL back to profiles
        try await client
            .from("profiles")
            .update(["avatar_url": url.absoluteString])
            .eq("id", value: userId)
            .execute()
        return url.absoluteString
    }

    func updateBasicInfo(id: UUID, realName: String, major: String?, instrument: String?) async throws {
        struct Payload: Encodable {
            let realName: String
            let major: String?
            let instrument: String?
            enum CodingKeys: String, CodingKey {
                case realName = "real_name"; case major; case instrument
            }
        }
        try await client
            .from("profiles")
            .update(Payload(realName: realName, major: major, instrument: instrument))
            .eq("id", value: id)
            .execute()
    }

    func updateDefaultVisibility(id: UUID, visibility: Visibility) async throws {
        try await client
            .from("profiles")
            .update(["default_visibility": visibility.rawValue])
            .eq("id", value: id)
            .execute()
    }

    func completeOnboarding(id: UUID, visibility: Visibility) async throws {
        let payload: [String: AnyJSON] = [
            "default_visibility": .string(visibility.rawValue),
            "onboarding_complete": .bool(true)
        ]
        try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Feed & timelines

    func feed(userId: UUID) async throws -> [ActivityWithAuthor] {
        struct Params: Encodable {
            let pUserId: UUID
            enum CodingKeys: String, CodingKey { case pUserId = "p_user_id" }
        }
        return try await client
            .rpc("social_feed", params: Params(pUserId: userId))
            .execute()
            .value
    }

    func activities(byAuthor userID: UUID) async throws -> [ActivityWithAuthor] {
        try await client
            .from("activities")
            .select("id, user_id, type, title, activity_date, location, role, program, prize, organizer, personal_note, image_urls, verification, created_at, author:profiles(id, real_name, instrument)")
            .eq("user_id", value: userID)
            .order("activity_date", ascending: false)
            .execute()
            .value
    }

    func affiliations(forUser userID: UUID) async throws -> [Affiliation] {
        try await client
            .from("affiliations")
            .select()
            .eq("user_id", value: userID)
            .order("enrollment_year", ascending: false)
            .execute()
            .value
    }

    func insertAffiliation(_ a: NewAffiliation) async throws {
        try await client.from("affiliations").insert(a).execute()
    }

    func updateAffiliation(id: UUID, institutionName: String, courseType: String?,
                           enrollmentYear: Int?, graduationYear: Int?, isCurrent: Bool) async throws {
        struct P: Encodable {
            let institutionName: String; let courseType: String?
            let enrollmentYear: Int?; let graduationYear: Int?; let isCurrent: Bool
            enum CodingKeys: String, CodingKey {
                case institutionName = "institution_name"; case courseType = "course_type"
                case enrollmentYear = "enrollment_year"; case graduationYear = "graduation_year"
                case isCurrent = "is_current"
            }
        }
        try await client.from("affiliations")
            .update(P(institutionName: institutionName, courseType: courseType,
                      enrollmentYear: enrollmentYear, graduationYear: graduationYear,
                      isCurrent: isCurrent))
            .eq("id", value: id).execute()
    }

    func deleteAffiliation(id: UUID) async throws {
        try await client.from("affiliations").delete().eq("id", value: id).execute()
    }

    // MARK: - Career

    func careers(forUser userID: UUID) async throws -> [Career] {
        try await client
            .from("careers")
            .select()
            .eq("user_id", value: userID)
            .order("start_year", ascending: false)
            .execute()
            .value
    }

    func insertCareer(_ c: NewCareer) async throws {
        try await client.from("careers").insert(c).execute()
    }

    func updateCareer(id: UUID, organization: String, role: String,
                      startYear: Int?, endYear: Int?, isCurrent: Bool,
                      description: String?, contribution: String?,
                      linkUrl: String?, mediaUrl: String?) async throws {
        struct P: Encodable {
            let organization: String; let role: String
            let startYear: Int?; let endYear: Int?; let isCurrent: Bool
            let description: String?; let contribution: String?
            let linkUrl: String?; let mediaUrl: String?
            enum CodingKeys: String, CodingKey {
                case organization; case role
                case startYear = "start_year"; case endYear = "end_year"
                case isCurrent = "is_current"; case description; case contribution
                case linkUrl = "link_url"; case mediaUrl = "media_url"
            }
        }
        try await client.from("careers")
            .update(P(organization: organization, role: role, startYear: startYear,
                      endYear: endYear, isCurrent: isCurrent, description: description,
                      contribution: contribution, linkUrl: linkUrl, mediaUrl: mediaUrl))
            .eq("id", value: id).execute()
    }

    func deleteCareer(id: UUID) async throws {
        try await client.from("careers").delete().eq("id", value: id).execute()
    }

    // MARK: - Profile awards

    func awards(forUser userID: UUID) async throws -> [ProfileAward] {
        try await client.from("profile_awards")
            .select()
            .eq("user_id", value: userID)
            .order("year", ascending: false)
            .order("created_at", ascending: false)
            .execute().value
    }

    func insertAward(_ award: ProfileAward) async throws {
        try await client.from("profile_awards").insert(award).execute()
    }

    func updateAward(_ award: ProfileAward) async throws {
        let _: ProfileAward = try await client.from("profile_awards")
            .update(award)
            .eq("id", value: award.id)
            .eq("user_id", value: award.userId)
            .select().single().execute().value
    }

    func deleteAward(id: UUID, userId: UUID) async throws {
        try await client.from("profile_awards").delete()
            .eq("id", value: id).eq("user_id", value: userId).execute()
    }

    // MARK: - Languages

    func languages(forUser userID: UUID) async throws -> [ProfileLanguage] {
        try await client
            .from("profile_languages")
            .select()
            .eq("user_id", value: userID)
            .order("created_at")
            .execute()
            .value
    }

    func upsertLanguage(userId: UUID, language: String, level: String) async throws {
        struct P: Encodable {
            let userId: UUID; let language: String; let level: String
            enum CodingKeys: String, CodingKey { case userId = "user_id"; case language; case level }
        }
        try await client.from("profile_languages")
            .upsert(P(userId: userId, language: language, level: level),
                    onConflict: "user_id, language")
            .execute()
    }

    func deleteLanguage(id: UUID) async throws {
        try await client.from("profile_languages").delete().eq("id", value: id).execute()
    }

    // MARK: - Connections

    func connectionRecords(userId: UUID) async throws -> [ConnectionRecord] {
        try await client.from("follows")
            .select("follower_id, followee_id, status, follower:profiles!follower_id(id, real_name, instrument, major, avatar_url)")
            .or("follower_id.eq.\(userId),followee_id.eq.\(userId)")
            .execute().value
    }

    func transitionConnection(with other: UUID, action: ConnectionAction) async throws -> ConnectionStatus {
        struct Params: Encodable { let p_other: UUID; let p_action: String }
        let value: String = try await client.rpc("transition_connection", params: Params(p_other: other, p_action: action.rawValue))
            .execute().value
        switch value {
        case "connected": return .connected
        case "requestReceived": return .requestReceived
        case "requestSent": return .requestSent
        case "none": return .none
        default: throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unknown connection status"))
        }
    }

    func observeConnectionChanges(userId: UUID, onChange: @escaping @MainActor @Sendable () async -> Void) async {
        let channel = client.channel("connections:\(userId):\(UUID())")
        let incoming = channel.postgresChange(AnyAction.self, table: "follows", filter: .eq("followee_id", value: userId.uuidString))
        let outgoing = channel.postgresChange(AnyAction.self, table: "follows", filter: .eq("follower_id", value: userId.uuidString))
        let notifications = channel.postgresChange(AnyAction.self, table: "notifications", filter: .eq("recipient_id", value: userId.uuidString))
        let system = channel.system()
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await message in system {
                    guard !Task.isCancelled else { break }
                    if message.payload["status"]?.stringValue == "ok" { await onChange() }
                }
            }
            for stream in [incoming, outgoing, notifications] {
                group.addTask {
                    for await _ in stream {
                        guard !Task.isCancelled else { break }
                        await onChange()
                    }
                }
            }
            do {
                try await channel.subscribeWithError()
                await onChange()
                // A periodic authoritative read also recovers missed DELETEs/reconnects.
                while !Task.isCancelled {
                    try await Task.sleep(for: .seconds(8))
                    await onChange()
                }
            } catch {
                while !Task.isCancelled {
                    await onChange()
                    do { try await Task.sleep(for: .seconds(8)) } catch { break }
                }
            }
            group.cancelAll()
        }
        await client.removeChannel(channel)
    }

    func connectionCount(userId: UUID) async throws -> Int {
        struct NRow: Decodable { let n: Int }
        struct Params: Encodable {
            let pUserId: UUID
            enum CodingKeys: String, CodingKey { case pUserId = "p_user_id" }
        }
        let rows: [NRow] = try await client
            .rpc("connection_count", params: Params(pUserId: userId))
            .execute()
            .value
        return rows.first?.n ?? 0
    }

    func connectionStatus(me: UUID, them: UUID) async throws -> ConnectionStatus {
        struct Row: Decodable { let status: String }
        async let mine: [Row] = client.from("follows").select("status")
            .eq("follower_id", value: me).eq("followee_id", value: them).execute().value
        async let theirs: [Row] = client.from("follows").select("status")
            .eq("follower_id", value: them).eq("followee_id", value: me).execute().value
        let (myRow, theirRow) = try await (mine, theirs)
        if myRow.first?.status == "accepted" || theirRow.first?.status == "accepted" { return .connected }
        if myRow.first?.status == "pending" { return .requestSent }
        if theirRow.first?.status == "pending" { return .requestReceived }
        return .none
    }

    func connections(userId: UUID) async throws -> [ConnectedProfile] {
        struct Params: Encodable {
            let pUserId: UUID
            enum CodingKeys: String, CodingKey { case pUserId = "p_user_id" }
        }
        return try await client
            .rpc("get_connections", params: Params(pUserId: userId))
            .execute()
            .value
    }

    func pendingConnectionRequests(userId: UUID) async throws -> [ConnectedProfile] {
        struct Row: Decodable {
            let follower: ConnectedProfile
            enum CodingKeys: String, CodingKey { case follower }
        }
        let rows: [Row] = try await client.from("follows")
            .select("follower:profiles!follower_id(id, real_name, instrument, major, avatar_url)")
            .eq("followee_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        return rows.map { $0.follower }
    }

    func acceptConnection(from senderId: UUID, to recipientId: UUID) async throws {
        _ = try await transitionConnection(with: senderId, action: .accept)
    }

    func declineConnection(from senderId: UUID, to recipientId: UUID) async throws {
        _ = try await transitionConnection(with: senderId, action: .decline)
    }

    func disconnect(me: UUID, them: UUID) async throws {
        _ = try await transitionConnection(with: them, action: .disconnect)
    }

    func deleteAccount() async throws {
        try await client.rpc("delete_my_account").execute()
    }

    func suggestedProfiles(userId: UUID) async throws -> [SuggestedProfile] {
        struct Params: Encodable {
            let pUserId: UUID
            enum CodingKeys: String, CodingKey { case pUserId = "p_user_id" }
        }
        return try await client
            .rpc("get_suggested_profiles", params: Params(pUserId: userId))
            .execute()
            .value
    }

    func sendConnectionRequest(from senderId: UUID, to receiverId: UUID) async throws {
        _ = try await transitionConnection(with: receiverId, action: .request)
    }

    // MARK: - Search

    func searchActivities(query: String) async throws -> [ActivityWithAuthor] {
        try await client
            .from("activities")
            .select("id, user_id, type, title, activity_date, location, role, program, prize, organizer, image_urls, verification, created_at, author:profiles(id, real_name, instrument)")
            .ilike("title", pattern: "%\(query)%")
            .order("activity_date", ascending: false)
            .limit(20)
            .execute()
            .value
    }

    // MARK: - Activity creation

    func activity(id: UUID) async throws -> Activity {
        try await client
            .from("activities")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func updateActivity(id: UUID, payload: UpdateActivity) async throws {
        try await client
            .from("activities")
            .update(payload)
            .eq("id", value: id)
            .execute()
    }

    func deleteActivity(id: UUID) async throws {
        try await client
            .from("activities")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func createActivity(_ activity: NewActivity) async throws -> Activity {
        try await client
            .from("activities")
            .insert(activity)
            .select("id, user_id, type, title, activity_date, location, role, program, prize, organizer, image_urls, verification, visibility, created_at")
            .single()
            .execute()
            .value
    }

    func uploadActivityImage(userId: UUID, activityId: UUID, index: Int, data: Data) async throws -> String {
        let path = "\(userId.uuidString.lowercased())/\(activityId.uuidString.lowercased())/\(index).jpg"
        try await client.storage
            .from("activity-images")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
        let url = try client.storage.from("activity-images").getPublicURL(path: path)
        return url.absoluteString
    }

    func uploadActivityImageEdit(userId: UUID, activityId: UUID, data: Data) async throws -> String {
        let name = UUID().uuidString.lowercased()
        let path = "\(userId.uuidString.lowercased())/\(activityId.uuidString.lowercased())/\(name).jpg"
        try await client.storage
            .from("activity-images")
            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: false))
        let url = try client.storage.from("activity-images").getPublicURL(path: path)
        return url.absoluteString
    }

    func updateActivityImages(activityId: UUID, imageUrls: [String]) async throws {
        try await client
            .from("activities")
            .update(["image_urls": imageUrls])
            .eq("id", value: activityId)
            .execute()
    }

    // MARK: - Tags (simple, no confirm)

    func tagUsers(activityId: UUID, userIds: [UUID]) async throws {
        guard !userIds.isEmpty else { return }
        struct P: Encodable {
            let activityId: UUID; let taggedUserId: UUID
            enum CodingKeys: String, CodingKey {
                case activityId = "activity_id"; case taggedUserId = "tagged_user_id"
            }
        }
        try await client.from("activity_tags")
            .insert(userIds.map { P(activityId: activityId, taggedUserId: $0) })
            .execute()
    }

    func tags(forActivity activityId: UUID) async throws -> [ProfileLite] {
        struct W: Decodable {
            let taggedUser: ProfileLite?
            enum CodingKeys: String, CodingKey { case taggedUser = "tagged_user" }
        }
        let rows: [W] = try await client.from("activity_tags")
            .select("tagged_user:profiles(id, real_name, instrument)")
            .eq("activity_id", value: activityId)
            .order("created_at")
            .execute()
            .value
        return rows.compactMap { $0.taggedUser }
    }

    func taggedActivities(userId: UUID) async throws -> [ActivityWithAuthor] {
        struct W: Decodable {
            let activity: ActivityWithAuthor?
            enum CodingKeys: String, CodingKey { case activity }
        }
        let rows: [W] = try await client.from("activity_tags")
            .select("activity:activities(id, user_id, type, title, activity_date, location, role, program, prize, organizer, image_urls, verification, created_at, author:profiles(id, real_name, instrument))")
            .eq("tagged_user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { $0.activity }
    }

    // MARK: - Saves

    func saveActivity(userId: UUID, activityId: UUID) async throws {
        struct P: Encodable {
            let userId: UUID; let activityId: UUID
            enum CodingKeys: String, CodingKey { case userId = "user_id"; case activityId = "activity_id" }
        }
        try await client.from("activity_saves")
            .insert(P(userId: userId, activityId: activityId))
            .execute()
    }

    func unsaveActivity(userId: UUID, activityId: UUID) async throws {
        try await client.from("activity_saves")
            .delete()
            .eq("user_id", value: userId)
            .eq("activity_id", value: activityId)
            .execute()
    }

    func savedActivities(userId: UUID) async throws -> [ActivityWithAuthor] {
        struct W: Decodable {
            let activity: ActivityWithAuthor?
            enum CodingKeys: String, CodingKey { case activity }
        }
        let rows: [W] = try await client.from("activity_saves")
            .select("activity:activities(id, user_id, type, title, activity_date, location, role, program, prize, organizer, image_urls, verification, created_at, author:profiles(id, real_name, instrument))")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { $0.activity }
    }

    // MARK: - Confirm inbox

    func inbox(for userID: UUID) async throws -> [ConfirmRequest] {
        try await client
            .from("activity_participants")
            .select("id, confirm, activity:activities(id, user_id, type, title, activity_date, location, role, program, prize, organizer, image_urls, verification, created_at, author:profiles(id, real_name, instrument))")
            .eq("participant_id", value: userID)
            .eq("confirm", value: ConfirmStatus.requested.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func respond(participantRowID: UUID, approved: Bool) async throws {
        let status: ConfirmStatus = approved ? .approved : .rejected
        try await client
            .from("activity_participants")
            .update(["confirm": status.rawValue])
            .eq("id", value: participantRowID)
            .execute()
    }

    // MARK: - Likes

    func likeActivity(activityId: UUID, userId: UUID) async throws {
        struct P: Encodable {
            let activityId: UUID; let userId: UUID
            enum CodingKeys: String, CodingKey {
                case activityId = "activity_id"; case userId = "user_id"
            }
        }
        try await client.from("activity_likes")
            .insert(P(activityId: activityId, userId: userId))
            .execute()
    }

    func unlikeActivity(activityId: UUID, userId: UUID) async throws {
        try await client.from("activity_likes")
            .delete()
            .eq("activity_id", value: activityId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Comments

    func comments(forActivity activityId: UUID, userId: UUID) async throws -> [ActivityComment] {
        struct Params: Encodable {
            let pActivityId: UUID; let pUserId: UUID
            enum CodingKeys: String, CodingKey {
                case pActivityId = "p_activity_id"; case pUserId = "p_user_id"
            }
        }
        return try await client
            .rpc("get_comments", params: Params(pActivityId: activityId, pUserId: userId))
            .execute()
            .value
    }

    func likeComment(commentId: UUID, userId: UUID) async throws {
        struct P: Encodable { let commentId: UUID; let userId: UUID
            enum CodingKeys: String, CodingKey { case commentId = "comment_id"; case userId = "user_id" } }
        try await client.from("comment_likes").insert(P(commentId: commentId, userId: userId)).execute()
    }

    func unlikeComment(commentId: UUID, userId: UUID) async throws {
        try await client.from("comment_likes")
            .delete()
            .eq("comment_id", value: commentId)
            .eq("user_id", value: userId)
            .execute()
    }

    func addComment(activityId: UUID, userId: UUID, content: String, parentCommentId: UUID? = nil) async throws {
        struct P: Encodable {
            let activityId: UUID; let userId: UUID; let content: String; let parentCommentId: UUID?
            enum CodingKeys: String, CodingKey {
                case activityId = "activity_id"; case userId = "user_id"; case content
                case parentCommentId = "parent_comment_id"
            }
        }
        try await client.from("activity_comments")
            .insert(P(activityId: activityId, userId: userId, content: content, parentCommentId: parentCommentId))
            .execute()
    }

    func deleteComment(id: UUID) async throws {
        try await client.from("activity_comments").delete().eq("id", value: id).execute()
    }

    // MARK: - Activity stats (single RPC call)

    func activityStats(activityId: UUID, userId: UUID) async throws -> ActivityStats {
        struct Params: Encodable {
            let pActivityId: UUID; let pUserId: UUID
            enum CodingKeys: String, CodingKey {
                case pActivityId = "p_activity_id"; case pUserId = "p_user_id"
            }
        }
        let rows: [ActivityStats] = try await client
            .rpc("activity_stats", params: Params(pActivityId: activityId, pUserId: userId))
            .execute()
            .value
        return rows.first ?? ActivityStats(likeCount: 0, commentCount: 0, isLiked: false, isSaved: false)
    }

    // MARK: - Connection requests (renamed from Follow)

    func follow(follower: UUID, followee: UUID) async throws {
        _ = try await transitionConnection(with: followee, action: .request)
    }

    func unfollow(follower: UUID, followee: UUID) async throws {
        _ = try await transitionConnection(with: followee, action: .cancel)
    }

    func cancelConnectionRequest(from senderId: UUID, to recipientId: UUID) async throws {
        _ = try await transitionConnection(with: recipientId, action: .cancel)
    }

    func isFollowing(follower: UUID, followee: UUID) async throws -> Bool {
        let r = try await client
            .from("follows")
            .select("*", head: true, count: .exact)
            .eq("follower_id", value: follower)
            .eq("followee_id", value: followee)
            .eq("status", value: "accepted")
            .execute()
        return (r.count ?? 0) > 0
    }

    // MARK: - Tag acceptance

    func pendingTags(userId: UUID) async throws -> [ActivityWithAuthor] {
        struct W: Decodable {
            let activity: ActivityWithAuthor?
            enum CodingKeys: String, CodingKey { case activity }
        }
        let rows: [W] = try await client.from("activity_tags")
            .select("activity:activities(id, user_id, type, title, activity_date, location, role, program, prize, organizer, personal_note, image_urls, verification, created_at, author:profiles(id, real_name, instrument))")
            .eq("tagged_user_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows.compactMap { $0.activity }
    }

    func acceptTag(activityId: UUID, userId: UUID) async throws {
        try await client.from("activity_tags")
            .update(["status": "accepted"])
            .eq("activity_id", value: activityId)
            .eq("tagged_user_id", value: userId)
            .execute()
    }

    func declineTag(activityId: UUID, userId: UUID) async throws {
        try await client.from("activity_tags")
            .delete()
            .eq("activity_id", value: activityId)
            .eq("tagged_user_id", value: userId)
            .execute()
    }

    // MARK: - Jobs

    func jobs(type: JobType? = nil) async throws -> [Job] {
        var builder = client
            .from("jobs")
            .select(Self.jobSelect)
            .eq("is_active", value: true)
        if let type { builder = builder.eq("type", value: type.rawValue) }
        return try await builder
            .order("created_at", ascending: false)
            .limit(80)
            .execute()
            .value
    }

    // MARK: - Cities (opportunity archive)

    /// Canonical city dictionary (seeded from OnboardingData.cityOptions).
    func cities() async throws -> [City] {
        try await client
            .from("city")
            .select()
            .order("name_en", ascending: true)
            .execute()
            .value
    }

    /// The user's base city ids (§6), backfilled from onboarding home cities.
    func baseCityIDs(userId: UUID) async throws -> [String] {
        struct Row: Decodable {
            let cityId: String
            enum CodingKeys: String, CodingKey { case cityId = "city_id" }
        }
        let rows: [Row] = try await client
            .from("user_base_city")
            .select("city_id")
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.map(\.cityId)
    }

    /// Full-text + fuzzy + cross-language search over the opportunity archive (§8).
    func searchOpportunities(query: String) async throws -> [Job] {
        struct Params: Encodable { let q: String }
        return try await client
            .rpc("search_opportunities", params: Params(q: query))
            .execute()
            .value
    }

    func myJobs(userId: UUID) async throws -> [Job] {
        try await client
            .from("jobs")
            .select(Self.jobSelect)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func postJob(_ job: NewJob) async throws {
        try await client.from("jobs").insert(job).execute()
    }

    func closeJob(id: UUID) async throws {
        try await client
            .from("jobs")
            .update(["is_active": false])
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Notifications

    func notifications(userId: UUID) async throws -> [AppNotification] {
        try await client
            .from("notifications")
            .select("*, sender:profiles!sender_id(real_name, instrument), activity:activities!activity_id(title)")
            .eq("recipient_id", value: userId)
            .neq("type", value: "follow")
            .order("created_at", ascending: false)
            .limit(60)
            .execute()
            .value
    }

    func markAllNotificationsRead(userId: UUID) async throws {
        try await client
            .from("notifications")
            .update(["is_read": true])
            .eq("recipient_id", value: userId)
            .eq("is_read", value: false)
            .execute()
    }

    func markNotificationsRead(userId: UUID, ids: [UUID]) async throws {
        guard !ids.isEmpty else { return }
        try await client.from("notifications").update(["is_read": true])
            .eq("recipient_id", value: userId).in("id", values: ids).execute()
    }

    func unreadNotificationCount(userId: UUID) async throws -> Int {
        let r = try await client
            .from("notifications")
            .select("*", head: true, count: .exact)
            .eq("recipient_id", value: userId)
            .neq("type", value: "follow")
            .eq("is_read", value: false)
            .execute()
        return r.count ?? 0
    }

    // MARK: - Organizations

    private static let orgSelect = "id, name, handle, description, logo_url, website, category, created_by"
    private static let activityWithOrgSelect = "id, user_id, type, title, activity_date, location, role, program, prize, organizer, image_urls, verification, personal_note, created_at, author:profiles!user_id(id, real_name, instrument), org:organizations!org_id(id, name, logo_url, category)"

    func myOrgs(userId: UUID) async throws -> [Organization] {
        struct Row: Decodable {
            let org: Organization
            enum CodingKeys: String, CodingKey { case org }
        }
        let rows: [Row] = try await client
            .from("org_admins")
            .select("org:\(Repository.orgSelect)")
            .eq("user_id", value: userId)
            .execute()
            .value
        return rows.map(\.org)
    }

    func fetchOrg(id: UUID) async throws -> Organization {
        try await client
            .from("organizations")
            .select(Repository.orgSelect)
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func createOrg(name: String, handle: String, category: OrgCategory,
                   description: String?, website: String?, createdBy: UUID) async throws -> Organization {
        struct P: Encodable {
            let name, handle, category: String
            let description, website: String?
            let createdBy: UUID
            enum CodingKeys: String, CodingKey {
                case name, handle, category, description, website
                case createdBy = "created_by"
            }
        }
        let org: Organization = try await client
            .from("organizations")
            .insert(P(name: name, handle: handle, category: category.rawValue,
                      description: description, website: website, createdBy: createdBy))
            .select(Repository.orgSelect)
            .single()
            .execute()
            .value
        // Insert owner record
        struct A: Encodable {
            let orgId: UUID; let userId: UUID; let role: String
            enum CodingKeys: String, CodingKey { case orgId = "org_id"; case userId = "user_id"; case role }
        }
        try await client.from("org_admins")
            .insert(A(orgId: org.id, userId: createdBy, role: "owner"))
            .execute()
        return org
    }

    func orgFollowerCount(orgId: UUID) async throws -> Int {
        let r = try await client
            .from("org_follows")
            .select("*", head: true, count: .exact)
            .eq("org_id", value: orgId)
            .execute()
        return r.count ?? 0
    }

    func isFollowingOrg(orgId: UUID, userId: UUID) async throws -> Bool {
        let r = try await client
            .from("org_follows")
            .select("*", head: true, count: .exact)
            .eq("org_id", value: orgId)
            .eq("user_id", value: userId)
            .execute()
        return (r.count ?? 0) > 0
    }

    func followOrg(orgId: UUID, userId: UUID) async throws {
        struct P: Encodable {
            let orgId: UUID; let userId: UUID
            enum CodingKeys: String, CodingKey { case orgId = "org_id"; case userId = "user_id" }
        }
        try await client.from("org_follows").insert(P(orgId: orgId, userId: userId)).execute()
    }

    func unfollowOrg(orgId: UUID, userId: UUID) async throws {
        try await client.from("org_follows")
            .delete()
            .eq("org_id", value: orgId)
            .eq("user_id", value: userId)
            .execute()
    }

    func orgActivities(orgId: UUID) async throws -> [ActivityWithAuthor] {
        try await client
            .from("activities")
            .select(Repository.activityWithOrgSelect)
            .eq("org_id", value: orgId)
            .order("activity_date", ascending: false)
            .execute()
            .value
    }

    // MARK: - Visible sections

    func updateVisibleSections(id: UUID, sections: [String]) async throws -> Profile {
        struct P: Encodable { let visibleSections: [String]
            enum CodingKeys: String, CodingKey { case visibleSections = "visible_sections" } }
        return try await client.from("profiles").update(P(visibleSections: sections))
            .eq("id", value: id).select().single().execute().value
    }

    // MARK: - Profile links (CV / website)

    func updateProfileLinks(id: UUID, cvUrl: String?, websiteUrl: String?) async throws {
        struct P: Encodable {
            let cvUrl: String?; let websiteUrl: String?
            enum CodingKeys: String, CodingKey {
                case cvUrl = "cv_url"; case websiteUrl = "website_url" }
        }
        try await client.from("profiles").update(P(cvUrl: cvUrl, websiteUrl: websiteUrl)).eq("id", value: id).execute()
    }

    func uploadCV(userId: UUID, data: Data) async throws -> String {
        let path = "\(userId)/cv.pdf"
        try await client.storage.from("user-files").upload(
            path, data: data,
            options: FileOptions(contentType: "application/pdf", upsert: true)
        )
        return try client.storage.from("user-files").getPublicURL(path: path).absoluteString
    }

    // MARK: - Recommendations

    func recommendations(for userId: UUID) async throws -> [Recommendation] {
        try await client
            .from("recommendations")
            .select()
            .eq("recipient_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func addRecommendation(recipientId: UUID, recommenderName: String,
                           recommenderTitle: String?, body: String) async throws -> Recommendation {
        struct P: Encodable {
            let recipientId: UUID; let recommenderName: String
            let recommenderTitle: String?; let body: String
            enum CodingKeys: String, CodingKey {
                case recipientId = "recipient_id"
                case recommenderName = "recommender_name"
                case recommenderTitle = "recommender_title"
                case body
            }
        }
        return try await client.from("recommendations")
            .insert(P(recipientId: recipientId, recommenderName: recommenderName,
                      recommenderTitle: recommenderTitle, body: body))
            .select().single().execute().value
    }

    func updateRecommendation(id: UUID, recommenderName: String,
                              recommenderTitle: String?, body: String, isVisible: Bool) async throws {
        struct P: Encodable {
            let recommenderName: String; let recommenderTitle: String?
            let body: String; let isVisible: Bool
            enum CodingKeys: String, CodingKey {
                case recommenderName = "recommender_name"
                case recommenderTitle = "recommender_title"
                case body
                case isVisible = "is_visible"
            }
        }
        try await client.from("recommendations")
            .update(P(recommenderName: recommenderName, recommenderTitle: recommenderTitle,
                      body: body, isVisible: isVisible))
            .eq("id", value: id).execute()
    }

    func deleteRecommendation(id: UUID) async throws {
        try await client.from("recommendations").delete().eq("id", value: id).execute()
    }

    // MARK: - Instagram Import

    func importFromInstagram(url: String) async throws -> InstagramImportResult {
        struct Req: Encodable { let url: String }
        struct Res: Decodable {
            let caption: String?
            let thumbnailUrl: String?
            let error: String?
            enum CodingKeys: String, CodingKey {
                case caption, thumbnailUrl = "thumbnailUrl", error
            }
        }
        let res: Res = try await client.functions.invoke(
            "instagram-import",
            options: FunctionInvokeOptions(body: Req(url: url))
        )
        if let err = res.error { throw NSError(domain: "InstagramImport", code: -1,
            userInfo: [NSLocalizedDescriptionKey: err]) }
        return InstagramImportResult(
            caption: res.caption ?? "",
            thumbnailUrl: res.thumbnailUrl
        )
    }

    // MARK: - Fermata CV

    func updateCVFields(id: UUID, nameEn: String?, eyebrow: String?,
                        birthYear: Int?, phone: String?, address: String?) async throws {
        struct Payload: Encodable {
            let nameEn: String?
            let eyebrow: String?
            let birthYear: Int?
            let phone: String?
            let address: String?
            enum CodingKeys: String, CodingKey {
                case nameEn = "name_en"; case eyebrow
                case birthYear = "birth_year"; case phone; case address
            }
        }
        try await client
            .from("profiles")
            .update(Payload(nameEn: nameEn, eyebrow: eyebrow, birthYear: birthYear,
                            phone: phone, address: address))
            .eq("id", value: id)
            .execute()
    }

    func saveRepertoire(id: UUID, items: [String]) async throws {
        try await client
            .from("profiles")
            .update(["repertoire": items])
            .eq("id", value: id)
            .execute()
    }

    func cvActivities(userId: UUID) async throws -> [Activity] {
        try await client
            .from("activities")
            .select("id, user_id, type, title, activity_date, location, role, program, prize, organizer, personal_note, image_urls, verification, visibility, created_at")
            .eq("user_id", value: userId)
            .order("activity_date", ascending: false)
            .execute()
            .value
    }

    // MARK: - CV 전용 항목 (cv_entries)

    private static let cvEntrySelect =
        "id, kind, year, period, title, org, place, detail, result, institution, degree, teacher"

    func cvEntries(userId: UUID) async throws -> [CVEntryRow] {
        try await client
            .from("cv_entries")
            .select(Repository.cvEntrySelect)
            .eq("user_id", value: userId)
            .order("year", ascending: false)
            .execute()
            .value
    }

    private struct CVEntryPayload: Encodable {
        let userId: UUID
        let kind: String
        let year: Int?
        let period: String?
        let title: String?
        let org: String?
        let place: String?
        let detail: String?
        let result: String?
        let institution: String?
        let degree: String?
        let teacher: String?
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case kind, year, period, title, org, place, detail, result, institution, degree, teacher
        }
    }

    private func payload(_ userId: UUID, _ r: CVEntryRow) -> CVEntryPayload {
        CVEntryPayload(userId: userId, kind: r.kind, year: r.year, period: r.period,
                       title: r.title, org: r.org, place: r.place, detail: r.detail,
                       result: r.result, institution: r.institution, degree: r.degree, teacher: r.teacher)
    }

    func createCVEntry(userId: UUID, _ r: CVEntryRow) async throws {
        try await client.from("cv_entries").insert(payload(userId, r)).execute()
    }

    func updateCVEntry(userId: UUID, _ r: CVEntryRow) async throws {
        try await client.from("cv_entries")
            .update(payload(userId, r))
            .eq("id", value: r.id)
            .execute()
    }

    func deleteCVEntry(id: UUID) async throws {
        try await client.from("cv_entries").delete().eq("id", value: id).execute()
    }

    func cvOverrides(userId: UUID, lang: String = "en") async throws -> [CVOverride] {
        try await client
            .from("cv_i18n")
            .select("source_kind, source_id, patch, include")
            .eq("user_id", value: userId)
            .eq("lang", value: lang)
            .execute()
            .value
    }

    func upsertCVOverride(userId: UUID, override o: CVOverride, lang: String = "en") async throws {
        struct Row: Encodable {
            let sourceKind: String
            let sourceId: UUID
            let userId: UUID
            let lang: String
            let patch: [String: String]
            let include: Bool
            enum CodingKeys: String, CodingKey {
                case sourceKind = "source_kind"; case sourceId = "source_id"
                case userId = "user_id"; case lang; case patch; case include
            }
        }
        try await client
            .from("cv_i18n")
            .upsert(
                Row(sourceKind: o.sourceKind, sourceId: o.sourceId, userId: userId,
                    lang: lang, patch: o.patch, include: o.include),
                onConflict: "source_kind,source_id,lang"
            )
            .execute()
    }

    // MARK: - 다국어 프로필 (profile-level overlay + 언어 목록)

    /// profile-level 오버레이 patch (name/bio/instrument/eyebrow) for a language.
    func profileOverlay(userId: UUID, lang: String) async throws -> [String: String] {
        struct Row: Decodable { let patch: [String: String] }
        let rows: [Row] = try await client
            .from("cv_i18n")
            .select("patch")
            .eq("source_kind", value: "profile")
            .eq("source_id", value: userId)
            .eq("lang", value: lang)
            .execute()
            .value
        return rows.first?.patch ?? [:]
    }

    func upsertProfileOverlay(userId: UUID, lang: String, patch: [String: String]) async throws {
        struct Row: Encodable {
            let sourceKind = "profile"
            let sourceId: UUID
            let userId: UUID
            let lang: String
            let patch: [String: String]
            let include = true
            enum CodingKeys: String, CodingKey {
                case sourceKind = "source_kind"; case sourceId = "source_id"
                case userId = "user_id"; case lang; case patch; case include
            }
        }
        try await client
            .from("cv_i18n")
            .upsert(Row(sourceId: userId, userId: userId, lang: lang, patch: patch),
                    onConflict: "source_kind,source_id,lang")
            .execute()
    }

    func setProfileLangs(id: UUID, langs: [String]) async throws {
        try await client
            .from("profiles")
            .update(["profile_langs": langs])
            .eq("id", value: id)
            .execute()
    }

    /// cv-translate Edge Function 호출 → 원문 필드의 영어 번역 제안.
    func translateCVEntry(kind: String, fields: [String: String],
                          targetLang: String = "en") async throws -> [String: String] {
        struct Req: Encodable {
            let kind: String; let fields: [String: String]; let targetLang: String
        }
        struct Res: Decodable { let translations: [String: String]?; let error: String? }
        let res: Res = try await client.functions.invoke(
            "cv-translate",
            options: FunctionInvokeOptions(body: Req(kind: kind, fields: fields, targetLang: targetLang))
        )
        if let err = res.error {
            throw NSError(domain: "CVTranslate", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: err])
        }
        return res.translations ?? [:]
    }

    /// cv-export Edge Function 호출 → 렌더된 PDF 의 signed URL.
    func exportCV() async throws -> URL {
        struct Empty: Encodable {}
        struct Res: Decodable { let url: String?; let error: String? }
        let res: Res = try await client.functions.invoke(
            "cv-export",
            options: FunctionInvokeOptions(body: Empty())
        )
        if let err = res.error {
            throw NSError(domain: "CVExport", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: err])
        }
        guard let urlString = res.url, let url = URL(string: urlString) else {
            throw NSError(domain: "CVExport", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "no url returned"])
        }
        return url
    }
}
