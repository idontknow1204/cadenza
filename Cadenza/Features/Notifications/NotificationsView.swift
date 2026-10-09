import SwiftUI

struct NotificationsView: View {
    @Binding var unreadBadge: Int

    @Environment(SessionStore.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var notifications: [AppNotification] = []
    @State private var pendingTags: [ActivityWithAuthor] = []
    private var pendingConnections: [ConnectedProfile] { session.connections.pending }
    @State private var actingTags: Set<UUID> = []
    @State private var suggestedProfiles: [SuggestedProfile] = []
    @State private var loadID = UUID()
    @State private var loading = false

    var body: some View {
        NavigationStack {
            Group {
                if loading && notifications.isEmpty && pendingTags.isEmpty && pendingConnections.isEmpty && suggestedProfiles.isEmpty {
                    ProgressView()
                } else if notifications.isEmpty && pendingTags.isEmpty && pendingConnections.isEmpty && suggestedProfiles.isEmpty && !session.connections.refreshFailed {
                    emptyState
                } else {
                    notifList
                }
            }
            .navigationTitle("tab.notifications")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UserProfileRoute.self) { route in
                PublicProfileView(userId: route.id)
            }
            .navigationDestination(for: SuggestedPeopleRoute.self) { _ in
                SuggestedPeopleView(people: suggestedProfiles)
            }
            .cadenzaRefreshable { await load() }
            .task(id: "\(session.connections.revision):\(scenePhase)") {
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    await load()
                    do { try await Task.sleep(for: .seconds(8)) } catch { break }
                }
            }
            .onDisappear { loadID = UUID(); loading = false }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView(
            "notif.empty.title",
            systemImage: "bell.slash",
            description: Text("notif.empty.desc")
        )
    }

    // MARK: - List

    private var notifList: some View {
        List {
            if session.connections.refreshFailed {
                Button { Task { await session.connections.refresh() } } label: {
                    Label(localized("연결 요청을 다시 불러오기", "Retry connection requests", "Kontaktanfragen erneut laden"), systemImage: "arrow.clockwise")
                }
            }
            // ── 연결 요청 ─────────────────────────────────────────
            if !pendingConnections.isEmpty {
                Section {
                    ForEach(pendingConnections) { person in
                        ConnectionRequestRow(
                            person: person,
                            isActing: session.connections.updating.contains(person.id)
                        ) {
                            await acceptConnection(person)
                        } onDecline: {
                            await declineConnection(person)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                } header: {
                    Label("notif.section.connections", systemImage: "person.badge.plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            // ── 태그 수락 대기 ──────────────────────────────────────
            if !pendingTags.isEmpty {
                Section {
                    ForEach(pendingTags) { item in
                        TagRequestRow(
                            item: item,
                            isActing: actingTags.contains(item.id)
                        ) {
                            await acceptTag(item)
                        } onDecline: {
                            await declineTag(item)
                        }
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    }
                } header: {
                    Label("notif.section.tags", systemImage: "at")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }

            // ── 알림 목록 ────────────────────────────────────────────
            if !notifications.isEmpty {
                Section {
                    ForEach(notifications) { notif in
                        NotificationRow(notif: notif)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    if !pendingTags.isEmpty {
                        Text("notif.section.recent")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }

            // ── 알 수도 있는 사람 ─────────────────────────────────────
            if !suggestedProfiles.isEmpty {
                Section {
                    suggestedSection
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } header: {
                    Label(localized("알 수도 있는 사람", "People you may know", "Personen, die du kennen könntest"), systemImage: "person.2")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Suggested profiles section

    /// Suggestions worth showing (not already connected / incoming).
    private var visibleSuggestions: [SuggestedProfile] {
        suggestedProfiles.filter {
            let status = session.connections.status(for: $0.id)
            return status != .connected && status != .requestReceived
        }
    }

    private var suggestedSection: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(visibleSuggestions.prefix(4)) { person in
                    SuggestedPersonCard(
                        person: person,
                        isSent: session.connections.status(for: person.id) == .requestSent,
                        isUpdating: session.connections.updating.contains(person.id) || !session.connections.hasLoaded
                    ) {
                        await toggleRequest(to: person)
                    }
                }
            }

            if visibleSuggestions.count > 4 {
                NavigationLink(value: SuggestedPeopleRoute()) {
                    HStack(spacing: 4) {
                        Text(localized("전체 보기", "See all", "Alle ansehen"))
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("notifications.suggestions.seeAll")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Load

    private func load() async {
        guard let me = session.currentUserID else { return }
        let id = UUID()
        loadID = id
        let requestsRevision = session.connections.revision
        loading = true
        defer { if loadID == id { loading = false } }
        async let connectionsTask: Void = session.connections.refresh()
        async let notifsTask     = session.repo.notifications(userId: me)
        async let tagsTask       = session.repo.pendingTags(userId: me)
        async let suggestedTask  = session.repo.suggestedProfiles(userId: me)
        let fetchedNotifications = try? await notifsTask
        let tags = try? await tagsTask
        let suggestions = try? await suggestedTask
        await connectionsTask
        guard loadID == id, session.currentUserID == me, !Task.isCancelled else { return }
        if let fetchedNotifications { notifications = fetchedNotifications }
        if let tags { pendingTags = tags }
        // A refresh started before/during a mutation must not replace its cards or state.
        if let suggestions, requestsRevision == session.connections.revision,
           session.connections.updating.isEmpty {
            // Keep just-requested cards actionable so the same button can cancel.
            let availableIDs = Set(suggestions.map(\.id))
            let retained = suggestedProfiles.filter {
                session.connections.status(for: $0.id) == .requestSent || availableIDs.contains($0.id)
            }
            let retainedIDs = Set(retained.map(\.id))
            suggestedProfiles = retained + suggestions.filter { !retainedIDs.contains($0.id) }
        }
        unreadBadge = notifications.filter { !$0.isRead }.count
        let unreadIDs = notifications.filter { !$0.isRead }.map(\.id)
        do {
            try await session.repo.markNotificationsRead(userId: me, ids: unreadIDs)
            guard loadID == id, session.currentUserID == me, !Task.isCancelled else { return }
            notifications = notifications.map { n in
                var m = n
                if unreadIDs.contains(n.id) { m.isRead = true }
                return m
            }
            unreadBadge = notifications.filter { !$0.isRead }.count
        } catch {
            // Preserve unread state on failure; never mark unseen arrivals as read.
        }
    }

    private func toggleRequest(to person: SuggestedProfile) async {
        let action: ConnectionAction = session.connections.status(for: person.id) == .requestSent ? .cancel : .request
        await session.connections.perform(action, with: person.id)
    }

    // MARK: - Connection actions

    private func acceptConnection(_ person: ConnectedProfile) async {
        await session.connections.perform(.accept, with: person.id)
    }

    private func declineConnection(_ person: ConnectedProfile) async {
        await session.connections.perform(.decline, with: person.id)
    }

    // MARK: - Tag actions

    private func acceptTag(_ item: ActivityWithAuthor) async {
        guard let me = session.currentUserID else { return }
        actingTags.insert(item.id)
        defer { actingTags.remove(item.id) }
        try? await session.repo.acceptTag(activityId: item.id, userId: me)
        withAnimation { pendingTags.removeAll { $0.id == item.id } }
    }

    private func declineTag(_ item: ActivityWithAuthor) async {
        guard let me = session.currentUserID else { return }
        actingTags.insert(item.id)
        defer { actingTags.remove(item.id) }
        try? await session.repo.declineTag(activityId: item.id, userId: me)
        withAnimation { pendingTags.removeAll { $0.id == item.id } }
    }
}

// MARK: - Notification row

private struct NotificationRow: View {
    let notif: AppNotification

    private var iconColor: Color {
        switch notif.type {
        case "like":    return .red
        case "comment": return .blue
        case "follow":  return Color.accentColor
        case "tag":     return .orange
        default:        return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Type icon circle
            ZStack {
                Circle().fill(iconColor.opacity(0.12))
                Image(systemName: notif.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(notif.bodyText)
                    .font(.subheadline)
                    .foregroundStyle(notif.isRead ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let title = notif.activity?.title {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(notif.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !notif.isRead {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 2)
        .opacity(notif.isRead ? 0.72 : 1)
    }
}

// MARK: - Tag request row

private struct TagRequestRow: View {
    let item: ActivityWithAuthor
    let isActing: Bool
    let onAccept: () async -> Void
    let onDecline: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.orange.opacity(0.12))
                    Image(systemName: "at")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.orange)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    let authorName = item.author?.realName ?? String(localized: "notif.tag.unknown")
                    Text("notif.tag.request \(authorName)")
                        .font(.subheadline)
                    Text(item.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    Task { await onDecline() }
                } label: {
                    Text("notif.decline")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.primary)
                }
                .disabled(isActing)

                Button {
                    Task { await onAccept() }
                } label: {
                    Text("notif.accept.share")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .disabled(isActing)
            }
        }
    }
}

// MARK: - Suggested person card

private struct SuggestedPersonCard: View {
    let person: SuggestedProfile
    let isSent: Bool
    let isUpdating: Bool
    let onConnect: () async -> Void

    private var reasonLabel: String {
        person.reason == "school"
            ? localized("같은 학교", "Same school", "Gleiche Schule")
            : localized("같은 지역", "Same area", "Gleiche Region")
    }

    private var reasonIcon: String {
        person.reason == "school" ? "graduationcap" : "mappin"
    }

    private var initials: String {
        let words = person.realName.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return String(person.realName.prefix(2)).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationLink(value: UserProfileRoute(id: person.id)) {
                profileContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(person.realName)
            .accessibilityHint(localized("프로필 보기", "View profile", "Profil anzeigen"))
            .accessibilityIdentifier("notifications.suggestion.profile.\(person.id)")

            Spacer(minLength: 12)

            // Connect button
            Button {
                Task { await onConnect() }
            } label: {
                HStack(spacing: 4) {
                    if isSent {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text(localized("신청됨", "Requested", "Angefragt"))
                            .font(.caption.weight(.semibold))
                    } else {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 11, weight: .bold))
                        Text(localized("연결 신청", "Connect", "Verbinden"))
                            .font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(isSent ? .secondary : Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    isSent
                        ? Color.secondary.opacity(0.1)
                        : Color.accentColor.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            }
            .buttonStyle(.plain)
            .disabled(isUpdating)
            .accessibilityHint(isSent
                ? localized("연결 요청 취소", "Cancel connection request", "Kontaktanfrage zurückziehen")
                : localized("연결 요청 보내기", "Send connection request", "Kontaktanfrage senden"))
            .accessibilityIdentifier("notifications.suggestion.connect.\(person.id)")
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }

    private var profileContent: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12))
                Text(initials)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 60, height: 60)
            .padding(.top, 16)

            Text(person.realName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.top, 8)
                .padding(.horizontal, 12)

            if let sub = person.instrument ?? person.major {
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
            }

            HStack(spacing: 4) {
                Image(systemName: reasonIcon)
                    .font(.system(size: 9, weight: .semibold))
                Text(person.sharedInfo)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.accentColor.opacity(0.1), in: Capsule())
            .padding(.horizontal, 12)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - All suggested people (full page)

struct SuggestedPeopleRoute: Hashable {}

private struct SuggestedPeopleView: View {
    let people: [SuggestedProfile]
    @Environment(SessionStore.self) private var session

    private var visible: [SuggestedProfile] {
        people.filter {
            let status = session.connections.status(for: $0.id)
            return status != .connected && status != .requestReceived
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(visible) { person in
                    SuggestedPersonCard(
                        person: person,
                        isSent: session.connections.status(for: person.id) == .requestSent,
                        isUpdating: session.connections.updating.contains(person.id) || !session.connections.hasLoaded
                    ) {
                        let action: ConnectionAction = session.connections.status(for: person.id) == .requestSent ? .cancel : .request
                        await session.connections.perform(action, with: person.id)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(localized("알 수도 있는 사람", "People you may know", "Personen, die du kennen könntest"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Connection request row

private struct ConnectionRequestRow: View {
    let person: ConnectedProfile
    let isActing: Bool
    let onAccept: () async -> Void
    let onDecline: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.12))
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("notif.connection.request \(person.realName)")
                        .font(.subheadline)
                    if let inst = person.instrument {
                        Text(inst)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button { Task { await onDecline() } } label: {
                    Text("notif.decline")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.primary)
                }
                .disabled(isActing)

                Button { Task { await onAccept() } } label: {
                    Text("notif.accept")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
                .disabled(isActing)
            }
        }
    }
}
