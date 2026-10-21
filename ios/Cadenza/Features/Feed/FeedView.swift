import SwiftUI
#if canImport(Translation)
import Translation
#endif
#if canImport(_Translation_SwiftUI)
import _Translation_SwiftUI
#endif

struct UserProfileRoute: Hashable { let id: UUID }

struct FeedView: View {
    let feed: FeedStore
    var unreadNotificationCount: Int = 0
    var onNotifications: () -> Void = {}
    var onCreate: () -> Void = {}
    var scrollToTop: Int = 0

    @Environment(SessionStore.self) private var session
    // Keep the original header available for a one-setting rollback.
    @AppStorage("homeCompactHeaderEnabled") private var compactHeaderEnabled = true
    private var items: [ActivityWithAuthor] { feed.items }
    private var loading: Bool { feed.isLoading }

    @State private var searchQuery = ""
    @State private var searchPeople: [ProfileLite] = []
    @State private var searchActivities: [ActivityWithAuthor] = []
    @State private var searchJobs: [Job] = []
    @State private var searching = false

    // Loaded once when search becomes active, then filtered locally.
    @State private var allJobs: [Job] = []
    @State private var suggested: [SuggestedProfile] = []
    @State private var searchActive = false

    // Recent searches persist across launches (newline-joined, newest first).
    @AppStorage("home.recentSearches") private var recentRaw = ""

    private var trimmedQuery: String { searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !trimmedQuery.isEmpty }
    private var recentSearches: [String] {
        recentRaw.split(separator: "\n").map(String.init)
    }

    var body: some View {
        NavigationStack {
            homeContent
            .navigationDestination(for: UserProfileRoute.self) { route in
                PublicProfileView(userId: route.id)
            }
            .navigationDestination(for: OrgRoute.self) { route in
                OrgPageView(orgId: route.id)
            }
            .onChange(of: searchQuery) { _, q in Task { await runSearch(q) } }
            .onChange(of: searchActive) { _, active in
                if active { Task { await loadSearchScaffolding() } }
            }
            .overlay { if loading && items.isEmpty { ProgressView() } }
            .task { await load() }
            .onDisappear { feed.cancel() }
            .alert("error.title", isPresented: Binding(
                get: { feed.errorMessage != nil },
                set: { if !$0 { feed.errorMessage = nil } }
            )) {
                Button("common.ok") { feed.errorMessage = nil }
            } message: { Text(feed.errorMessage ?? "") }
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        if compactHeaderEnabled {
            // Header is a stable sibling (not a safeAreaInset on the switching
            // content). Otherwise, when the content view type flips
            // (feedList/ScrollView ↔ search List) the inset host — and the
            // search TextField inside it — gets torn down mid-keystroke, which
            // breaks Hangul IME composition (only the first jamo is committed).
            VStack(spacing: 0) {
                CadenzaBrowseHeader(
                    searchQuery: $searchQuery,
                    searchActive: $searchActive,
                    unreadNotificationCount: unreadNotificationCount,
                    onNotifications: onNotifications,
                    onCreate: onCreate,
                    onSubmitSearch: { addRecent($0) }
                )
                feedContent
            }
            .toolbar(.hidden, for: .navigationBar)
        } else {
            feedContent
                .navigationTitle("tab.feed")
                .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("feed.search.hint"))
        }
    }

    private var feedContent: some View {
        Group {
            if isSearching {
                searchResults
            } else if searchActive {
                searchIdle
            } else {
                feedList
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Feed list

    private var feedList: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: 0).id("feed-top")
                if items.isEmpty && !loading {
                    ContentUnavailableView("feed.empty.title", systemImage: "music.note.list",
                                           description: Text("feed.empty.desc"))
                        .padding(.top, 60)
                }
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { PostSeparator() }
                    ActivityCard(item: item, showMetadataLine: false, onDeleted: {
                        withAnimation { feed.remove(id: item.id) }
                    })
                }
            }
            .adaptiveContentWidth()
        }
        .cadenzaRefreshable { await load() }
        .background(Color(.secondarySystemBackground))
        .onChange(of: scrollToTop) {
            withAnimation { proxy.scrollTo("feed-top", anchor: .top) }
        }
        } // ScrollViewReader
    }

    // MARK: - Search results

    private var searchResults: some View {
        List {
            if searching {
                HStack { Spacer(); ProgressView(); Spacer() }.listRowSeparator(.hidden)
            } else if searchPeople.isEmpty && searchActivities.isEmpty && searchJobs.isEmpty {
                ContentUnavailableView("feed.search.empty", systemImage: "magnifyingglass")
            } else {
                if !searchPeople.isEmpty {
                    Section("feed.search.people") {
                        ForEach(searchPeople) { p in
                            NavigationLink(value: UserProfileRoute(id: p.id)) {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle")
                                        .font(.title2).foregroundStyle(.secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.realName).font(.subheadline.weight(.medium))
                                        if let inst = p.instrument {
                                            Text(OnboardingData.instrumentDisplay(inst))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .simultaneousGesture(TapGesture().onEnded { addRecent(trimmedQuery) })
                        }
                    }
                }
                if !searchActivities.isEmpty {
                    Section("feed.search.activities") {
                        ForEach(Array(searchActivities.enumerated()), id: \.element.id) { index, item in
                            ActivityCard(item: item, showMetadataLine: false)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color(.secondarySystemBackground))
                            if index < searchActivities.count - 1 {
                                PostSeparator()
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
                if !searchJobs.isEmpty {
                    Section("feed.search.jobs") {
                        ForEach(searchJobs) { job in
                            NavigationLink(destination: JobDetailView(job: job)) {
                                JobSearchRow(job: job)
                            }
                            .simultaneousGesture(TapGesture().onEnded { addRecent(trimmedQuery) })
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Helpers

    private func load() async {
        guard let me = session.currentUserID else { return }
        await feed.refresh {
            let items = try await session.repo.feed(userId: me)
            guard session.currentUserID == me else { throw CancellationError() }
            return items
        }
    }

    private func runSearch(_ query: String) async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            searchPeople = []; searchActivities = []; searchJobs = []; return
        }
        searching = true; defer { searching = false }
        guard let me = session.currentUserID else { return }
        async let people = session.repo.searchProfiles(query: q, excluding: me)
        async let acts   = session.repo.searchActivities(query: q)
        searchPeople     = (try? await people) ?? []
        searchActivities = (try? await acts)   ?? []
        searchJobs       = Self.filterJobs(allJobs, query: q)
    }

    /// Load suggestion + job scaffolding once, when the search field is first focused.
    private func loadSearchScaffolding() async {
        guard let me = session.currentUserID else { return }
        if suggested.isEmpty {
            suggested = (try? await session.repo.suggestedProfiles(userId: me)) ?? []
        }
        if allJobs.isEmpty {
            allJobs = (try? await session.repo.jobs()) ?? []
        }
        if isSearching { searchJobs = Self.filterJobs(allJobs, query: trimmedQuery) }
    }

    /// Client-side job filtering across title, org, location, type and instruments
    /// (matching both the stored id and its localized display name).
    private static func filterJobs(_ jobs: [Job], query q: String) -> [Job] {
        jobs.filter { job in
            job.title.localizedCaseInsensitiveContains(q)
            || (job.organization?.localizedCaseInsensitiveContains(q) ?? false)
            || (job.location?.localizedCaseInsensitiveContains(q) ?? false)
            || job.type.label.localizedCaseInsensitiveContains(q)
            || job.instruments.contains {
                $0.localizedCaseInsensitiveContains(q)
                || OnboardingData.instrumentDisplay($0).localizedCaseInsensitiveContains(q)
            }
        }
    }

    // MARK: - Recent searches

    private func addRecent(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(t) != .orderedSame }
        list.insert(t, at: 0)
        recentRaw = list.prefix(8).joined(separator: "\n")
    }

    private func removeRecent(_ term: String) {
        recentRaw = recentSearches
            .filter { $0.caseInsensitiveCompare(term) != .orderedSame }
            .joined(separator: "\n")
    }

    private func clearRecent() { recentRaw = "" }

    // MARK: - Search idle (recent + suggested)

    private var searchIdle: some View {
        List {
            if !recentSearches.isEmpty {
                Section {
                    ForEach(recentSearches, id: \.self) { term in
                        Button {
                            searchQuery = term
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(.secondary)
                                Text(term).foregroundStyle(.primary)
                                Spacer()
                                Button {
                                    removeRecent(term)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 32, height: 32)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("feed.search.recent")
                        Spacer()
                        Button("feed.search.recent.clear") { clearRecent() }
                            .font(.caption)
                            .textCase(nil)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }

            if !suggested.isEmpty {
                Section("feed.search.suggested") {
                    ForEach(suggested) { p in
                        NavigationLink(value: UserProfileRoute(id: p.id)) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.crop.circle")
                                    .font(.title2).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.realName).font(.subheadline.weight(.medium))
                                    if !p.sharedInfo.isEmpty {
                                        Text(p.sharedInfo)
                                            .font(.caption).foregroundStyle(.secondary)
                                    } else if let inst = p.instrument {
                                        Text(OnboardingData.instrumentDisplay(inst))
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Job search row (compact)

private struct JobSearchRow: View {
    let job: Job

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: job.type.symbol)
                .font(.subheadline)
                .foregroundStyle(JobCard.typeColor(job.type))
                .frame(width: 30, height: 30)
                .background(JobCard.typeColor(job.type).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(job.type.label)
                    if let org = job.organization, !org.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(org).lineLimit(1)
                    } else if let loc = job.location, !loc.isEmpty {
                        Text("·").foregroundStyle(.tertiary)
                        Text(loc).lineLimit(1)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let label = job.deadlineLabel {
                Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Shared home/jobs header: stable search identity also preserves Hangul composition.
struct CadenzaBrowseHeader: View {
    @Binding var searchQuery: String
    @Binding var searchActive: Bool
    var unreadNotificationCount: Int
    var onNotifications: () -> Void
    var onCreate: () -> Void
    var onSubmitSearch: (String) -> Void = { _ in }
    var title: Text = Text(verbatim: "Cadenza")
    var searchPrompt: Text = Text("feed.search.hint")
    var createLabel: Text = Text("tab.record")
    var accessibilityPrefix = "home"
    var showsNotifications = true
    var showsLogo = true
    @FocusState private var searchFocused: Bool
    @ScaledMetric(relativeTo: .title2) private var logoSize = 30.0

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 7) {
                    if showsLogo {
                        Image("CadenzaLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: logoSize, height: logoSize)
                            .background(.white, in: RoundedRectangle(cornerRadius: 6))
                            .accessibilityHidden(true)
                    }
                    title
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                if showsNotifications {
                    Button {
                        searchFocused = false
                        onNotifications()
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 44, height: 44)
                            .overlay(alignment: .topTrailing) {
                                if unreadNotificationCount > 0 {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 7, height: 7)
                                        .padding(8)
                                }
                            }
                    }
                    .accessibilityLabel(Text("tab.notifications"))
                    .accessibilityValue(Text(unreadNotificationCount > 0 ? "읽지 않은 알림 있음" : ""))
                    .help(Text("tab.notifications"))
                }

                Button {
                    searchFocused = false
                    onCreate()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color("BrandSurface"), in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityLabel(createLabel)
                .accessibilityIdentifier("\(accessibilityPrefix).create")
                .help(createLabel)
            }

            HStack(spacing: 8) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(text: $searchQuery) { searchPrompt }
                        .font(.subheadline)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($searchFocused)
                        .onSubmit {
                            onSubmitSearch(searchQuery)
                            searchFocused = false
                        }
                        .onChange(of: searchFocused) { _, focused in
                            searchActive = focused
                        }
                        .accessibilityIdentifier("\(accessibilityPrefix).search")
                    if !searchQuery.isEmpty || searchFocused {
                        Button {
                            searchQuery = ""
                            searchFocused = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(Text("common.cancel"))
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, searchQuery.isEmpty && !searchFocused ? 12 : 0)
                .frame(minHeight: 44)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))

            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 14)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }
}

// MARK: - Post separator

struct PostSeparator: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .frame(height: 6)
    }
}

// MARK: - Activity card

struct ActivityCard: View {
    let item: ActivityWithAuthor
    var showMetadataLine = true
    var onDeleted: (() -> Void)? = nil

    @Environment(SessionStore.self) private var session
    @AppStorage("appLanguage") private var appLanguage: String = ""
    @State private var likeCount = 0
    @State private var commentCount = 0
    @State private var isLiked = false
    @State private var isSaved = false
    @State private var tags: [ProfileLite] = []
    @State private var showComments = false
    @State private var showTranslation = false
    @State private var isTranslating = false
    @State private var translatedText: String?
    @State private var translationError: String?
    @State private var translationRequestID = 0
    @State private var showSystemTranslation = false
    @State private var showMeatball = false
    @State private var showReport = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var isHidden = false
    @State private var isDeleted = false
    @State private var viewerContext: ImageViewerContext? = nil
    private var authorConnectionStatus: ConnectionStatus? {
        guard session.connections.hasLoaded, let author = item.author?.id else { return nil }
        return session.connections.status(for: author)
    }
    private var isUpdatingConnection: Bool {
        item.author.map { session.connections.updating.contains($0.id) } ?? false
    }

    private var displayDate: String {
        item.activityDate.replacingOccurrences(of: "-", with: ".")
    }

    private var postTimeText: String {
        guard let createdAt = item.createdAt,
              let date = parseTimestamp(createdAt) else {
            return displayDate
        }
        return relativeTime(from: date)
    }

    private var shareText: String {
        var lines: [String] = []
        if !postBodyText.isEmpty { lines.append(postBodyText) }
        lines.append(item.activityDate)
        if let loc = item.location, !loc.isEmpty { lines.append(loc) }
        lines.append("— Cadenza")
        return lines.joined(separator: "\n")
    }

    private func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return fractional.date(from: value) ?? standard.date(from: value)
    }

    private func relativeTime(from date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 { return localized("방금", "Just now", "Gerade eben") }
        let minutes = seconds / 60
        if minutes < 60 { return localized("\(minutes)분 전", "\(minutes)m ago", "vor \(minutes) Min.") }
        let hours = minutes / 60
        if hours < 24 { return localized("\(hours)시간 전", "\(hours)h ago", "vor \(hours) Std.") }
        let days = hours / 24
        if days < 7 { return localized("\(days)일 전", "\(days)d ago", "vor \(days) T.") }
        let weeks = days / 7
        if weeks < 5 { return localized("\(weeks)주 전", "\(weeks)w ago", "vor \(weeks) Wo.") }
        let months = days / 30
        if months < 12 { return localized("\(months)개월 전", "\(months)mo ago", "vor \(months) Mon.") }
        let years = days / 365
        return localized("\(years)년 전", "\(years)y ago", "vor \(years) J.")
    }

    private var showConnectButton: Bool {
        guard item.feedReason != nil,
              let status = authorConnectionStatus, status != .connected, status != .requestReceived,
              let authorId = item.author?.id,
              authorId != session.currentUserID else { return false }
        return true
    }

    private var isOwnPost: Bool {
        item.author?.id == session.currentUserID
    }

    var body: some View {
        translatedCard
    }

    @ViewBuilder
    private var translatedCard: some View {
        let content = Group {
            if isDeleted { EmptyView() }
            else if isHidden { hiddenBanner }
            else { cardContent }
        }
        .task { await loadStats() }
        .sheet(isPresented: $showComments, onDismiss: { Task { await loadStats() } }) {
            CommentsSheet(activity: item)
        }
        .sheet(isPresented: $showEdit, onDismiss: { Task { await loadStats() } }) {
            EditActivityView(item: item)
        }
        .sheet(isPresented: $showMeatball) {
            PostMeatballSheet(
                isSaved: isSaved,
                isOwnPost: isOwnPost,
                onSave:      { Task { await toggleSave() } },
                onUnfollow:  { Task { await unfollowAuthor() } },
                onHide:      { withAnimation { isHidden = true } },
                onReport:    { showReport = true },
                onEdit:      { showEdit = true },
                onDelete:    { showDeleteConfirm = true }
            )
            .presentationDetents([.height(isOwnPost ? 210 : 260)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .alert("신고", isPresented: $showReport) {
            Button("스팸") { withAnimation { isHidden = true } }
            Button("부적절한 콘텐츠", role: .destructive) { withAnimation { isHidden = true } }
            Button("취소", role: .cancel) { }
        } message: {
            Text("신고 이유를 선택해 주세요")
        }
        .alert("게시글을 삭제하시겠어요?", isPresented: $showDeleteConfirm) {
            Button("삭제", role: .destructive) { Task { await deletePost() } }
            Button("취소", role: .cancel) { }
        } message: {
            Text("삭제 후에는 복구할 수 없습니다.")
        }
        .fullScreenCover(item: $viewerContext) { ctx in
            ImageViewerSheet(urls: ctx.urls, initialIndex: ctx.initialIndex)
        }

        #if canImport(Translation) && canImport(_Translation_SwiftUI)
        if #available(iOS 18.0, *) {
            content.background {
                InlinePostTranslator(
                    requestID: $translationRequestID,
                    sourceText: translatableText,
                    targetLanguageCode: targetLanguageCode,
                    isTranslating: $isTranslating,
                    translatedText: $translatedText,
                    translationError: $translationError
                )
                .frame(width: 0, height: 0)
            }
        } else if #available(iOS 17.4, *) {
            content.translationPresentation(isPresented: $showSystemTranslation, text: translatableText)
        } else {
            content
        }
        #else
        content
        #endif
    }

    // MARK: - Hidden banner

    private var hiddenBanner: some View {
        HStack {
            Image(systemName: "eye.slash").foregroundStyle(.secondary)
            Text("관심없음으로 표시됨")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Button("실행 취소") { isHidden = false }
                .font(.subheadline).foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
    }

    // MARK: - Card content

    // "connection_commented|박민준" → ("connection_commented", "박민준")
    private var parsedFeedReason: (base: String, name: String?) {
        guard let reason = item.feedReason else { return ("", nil) }
        if let sep = reason.firstIndex(of: "|") {
            let base = String(reason[reason.startIndex..<sep])
            let name = String(reason[reason.index(after: sep)...])
            return (base, name.isEmpty ? nil : name)
        }
        return (reason, nil)
    }

    private var isConnectionCommented: Bool { parsedFeedReason.base == "connection_commented" }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Social context ────────────────────────────────
            if isConnectionCommented {
                let triggerName = parsedFeedReason.name
                HStack(spacing: 5) {
                    Image(systemName: "bubble.right").font(.caption2)
                    Group {
                        if let name = triggerName {
                            Text("\(name)님이 댓글을 달았습니다")
                        } else {
                            Text("연결된 사람이 댓글을 달았습니다")
                        }
                    }
                    .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }

            // ── Author header ─────────────────────────────────
            authorHeader
                .padding(.horizontal, 16)
                .padding(.top, isConnectionCommented ? 6 : 14)
                .padding(.bottom, 6)

            // ── Activity content ──────────────────────────────
            activityContent
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            if canTranslatePost {
                translationButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            // ── Tagged people ─────────────────────────────────
            if !tags.isEmpty {
                taggedRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }

            // ── Media block: 이미지 + 링크 프리뷰는 같은 수평 범위 ──
            mediaBlock

            // ── Stats row ─────────────────────────────────────
            if likeCount > 0 || commentCount > 0 {
                statsRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            Divider()

            // ── Action bar ────────────────────────────────────
            actionBar
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Author header

    private var authorHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            if let org = item.org {
                // Org post: tap navigates to OrgPageView
                NavigationLink(value: OrgRoute(id: org.id)) {
                    HStack(spacing: 10) {
                        OrgAvatar(category: org.category ?? .other, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(org.name)
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 4) {
                                if let cat = org.category {
                                    Text(cat.label).font(.caption).foregroundStyle(.secondary)
                                    Text("·").font(.caption2).foregroundStyle(.tertiary)
                                }
                                    Text(postTimeText).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                let authorHeader = HStack(alignment: .center, spacing: 10) {
                    UserAvatarView(url: item.author?.avatarUrl,
                                   name: item.author?.realName ?? "?",
                                   size: 42)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.author?.realName ?? "—")
                            .font(.subheadline.weight(.semibold))
                        HStack(spacing: 4) {
                            if let inst = item.author?.instrument, !inst.isEmpty {
                                Text(inst).font(.caption).foregroundStyle(.secondary)
                                Text("·").font(.caption2).foregroundStyle(.tertiary)
                            }
                            Text(postTimeText).font(.caption).foregroundStyle(.secondary)
                        }
                        if let affiliation = item.author?.affiliation?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !affiliation.isEmpty {
                            Text(affiliation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let authorId = item.author?.id {
                    NavigationLink(value: UserProfileRoute(id: authorId)) { authorHeader }
                        .buttonStyle(.plain)
                } else {
                    authorHeader
                }
            }

            Spacer()

            // Connect button — only for personal (non-org) posts
            if item.org == nil && showConnectButton {
                ConnectionRequestButton(
                    isRequested: authorConnectionStatus == .requestSent,
                    isLoading: isUpdatingConnection,
                    compact: true
                ) {
                    Task { await toggleConnectionToAuthor() }
                }
                .accessibilityIdentifier("feed.connection.\(item.id)")
            }

            // Meatball ···
            Button { showMeatball = true } label: {
                Image(systemName: "ellipsis")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Activity content

    private var canTranslatePost: Bool {
        !translatableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var targetLanguageCode: String {
        appLanguage.isEmpty ? (Locale.current.language.languageCode?.identifier ?? "ko") : appLanguage
    }

    private var targetLanguageName: String {
        switch targetLanguageCode {
        case "en": return "English"
        case "de": return "Deutsch"
        default: return "한국어"
        }
    }

    private var translatableText: String {
        postBodyText
    }

    private var postBodyText: String {
        // The personal story is the primary narrative. Keeping it first also
        // guarantees that the collapsed home card never hides it behind role
        // or programme metadata.
        [item.personalNote, item.role, item.program]
            .compactMap { text in
                guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: "\n\n")
    }

    private var activityContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !showMetadataLine && item.verification != .pending {
                BadgeChip(status: item.verification)
            }

            if showMetadataLine {
                HStack(spacing: 5) {
                    if item.verification != .pending {
                        BadgeChip(status: item.verification)
                    }
                    ActivityTypeLabel(type: item.type)
                    if let loc = item.location, !loc.isEmpty {
                        Text("·").font(.caption2).foregroundStyle(.tertiary)
                        Text(loc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }

            Group {
                if showTranslation {
                    translatedPostBody
                } else if !postBodyText.isEmpty {
                    originalPostBody
                }
            }

        }
    }

    @ViewBuilder
    private var originalPostBody: some View {
        ExpandableText(text: postBodyText, collapsedLineLimit: 3)
            .padding(.top, 3)
    }

    @ViewBuilder
    private var translatedPostBody: some View {
        Group {
            if isTranslating {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.75)
                    Text("번역 중...")
                }
            } else if let translatedText, !translatedText.isEmpty {
                ExpandableText(text: translatedText, collapsedLineLimit: 3)
            } else if let translationError {
                Text(translationError)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.primary.opacity(0.78))
        .fixedSize(horizontal: false, vertical: true)
        .transition(.opacity)
    }

    private var translationButton: some View {
        Button {
            toggleTranslation()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showTranslation ? "text.bubble.fill" : "text.bubble")
                Text(showTranslation ? "원문 보기" : "\(targetLanguageName) 번역 보기")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Media block (images + link preview)

    @ViewBuilder
    private var mediaBlock: some View {
        let hasImages = !item.imageUrls.isEmpty
        let linkUrl = item.linkUrl.flatMap { $0.isEmpty ? nil : $0 }
        if hasImages || linkUrl != nil {
            VStack(spacing: 0) {
                if hasImages {
                    imageArea
                }
                if let linkUrl {
                    LinkPreviewCard(
                        urlString: linkUrl,
                        title: item.linkTitle,
                        siteName: item.linkSiteName,
                        imageUrl: item.linkImageUrl
                    )
                }
            }
            .padding(.bottom, 12)
        }
    }

    // MARK: - Images

    @ViewBuilder
    private var imageArea: some View {
        let urls = item.imageUrls
        let count = urls.count
        // 2장: 240pt, 4장+: 260pt, 나머지(1·3장): 300pt
        let gridH: CGFloat = count == 2 ? 240 : 300
        let gap: CGFloat = 2

        GeometryReader { geo in
            let w = geo.size.width
            if count == 1 {
                photoCell(urlStr: urls[0], index: 0, all: urls, w: w, h: gridH)
            } else if count == 2 {
                let cw = (w - gap) / 2
                HStack(spacing: gap) {
                    photoCell(urlStr: urls[0], index: 0, all: urls, w: cw, h: gridH)
                    photoCell(urlStr: urls[1], index: 1, all: urls, w: cw, h: gridH)
                }
            } else if count == 3 {
                // 메인(좌 60% 전체 높이) + 서브 2장 우측 세로 배치
                let mainW = (w * 0.6).rounded() - gap / 2
                let rightW = w - mainW - gap
                let rh = (gridH - gap) / 2
                HStack(alignment: .top, spacing: gap) {
                    photoCell(urlStr: urls[0], index: 0, all: urls, w: mainW, h: gridH)
                    VStack(spacing: gap) {
                        photoCell(urlStr: urls[1], index: 1, all: urls, w: rightW, h: rh)
                        photoCell(urlStr: urls[2], index: 2, all: urls, w: rightW, h: rh)
                    }
                    .frame(width: rightW)
                }
            } else {
                // 메인(좌 60% 전체 높이) + 서브 3장 우측 세로 배치, 마지막 셀에 "+N"
                let mainW = (w * 0.6).rounded() - gap / 2
                let rightW = w - mainW - gap
                let rh = (gridH - gap * 2) / 3
                let extra = count - 4
                HStack(alignment: .top, spacing: gap) {
                    photoCell(urlStr: urls[0], index: 0, all: urls, w: mainW, h: gridH)
                    VStack(spacing: gap) {
                        photoCell(urlStr: urls[1], index: 1, all: urls, w: rightW, h: rh)
                        photoCell(urlStr: urls[2], index: 2, all: urls, w: rightW, h: rh)
                        ZStack {
                            photoCell(urlStr: urls[3], index: 3, all: urls, w: rightW, h: rh)
                            if extra > 0 {
                                Color.black.opacity(0.45)
                                    .frame(width: rightW, height: rh)
                                Text("+\(extra)")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: rightW, height: rh)
                        .clipped()
                    }
                    .frame(width: rightW)
                }
            }
        }
        .frame(height: gridH)
    }

    private func photoCell(urlStr: String, index: Int, all: [String], w: CGFloat, h: CGFloat) -> some View {
        Button {
            viewerContext = ImageViewerContext(urls: all, initialIndex: index)
        } label: {
            AsyncImage(url: URL(string: urlStr)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFill()
                default: Color(.systemFill)
                }
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tagged people row

    private var taggedRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "at")
                .font(.caption2).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags) { p in
                        Text(p.realName)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 10) {
            if likeCount > 0 {
                HStack(spacing: 4) {
                    ZStack {
                        Circle().fill(Color.accentColor)
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 18, height: 18)
                    Text("\(likeCount)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if commentCount > 0 {
                Button { showComments = true } label: {
                    Text("댓글 \(commentCount)개")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 0) {
            Button { Task { await toggleLike() } } label: {
                actionLabel(
                    icon: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup",
                    title: localized("좋아요", "Like", "Gefällt mir"),
                    tint: isLiked ? Color.accentColor : Color.secondary
                )
            }
            .buttonStyle(.plain)

            Button { showComments = true } label: {
                actionLabel(icon: "bubble.right", title: localized("댓글", "Comment", "Kommentar"))
            }
            .buttonStyle(.plain)

            ShareLink(item: shareText) {
                actionLabel(icon: "square.and.arrow.up", title: localized("공유", "Share", "Teilen"))
            }
        }
    }

    private func actionLabel(icon: String, title: String, tint: Color = Color.secondary) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15))
            Text(title)
                .font(.subheadline)
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
    }

    // MARK: - Data loading

    private func loadStats() async {
        guard let me = session.currentUserID else { return }
        async let statsTask = session.repo.activityStats(activityId: item.id, userId: me)
        async let tagsTask  = session.repo.tags(forActivity: item.id)
        if let stats = try? await statsTask {
            likeCount    = stats.likeCount
            commentCount = stats.commentCount
            isLiked      = stats.isLiked
            isSaved      = stats.isSaved
        }
        tags = (try? await tagsTask) ?? []

    }

    // MARK: - Actions

    private func toggleSave() async {
        guard let me = session.currentUserID else { return }
        let was = isSaved
        isSaved.toggle()
        do {
            if was { try await session.repo.unsaveActivity(userId: me, activityId: item.id) }
            else   { try await session.repo.saveActivity(userId: me, activityId: item.id) }
        } catch { isSaved = was }
    }

    private func toggleLike() async {
        guard let me = session.currentUserID else { return }
        let wasLiked = isLiked
        isLiked.toggle()
        likeCount += isLiked ? 1 : -1
        do {
            if wasLiked { try await session.repo.unlikeActivity(activityId: item.id, userId: me) }
            else        { try await session.repo.likeActivity(activityId: item.id, userId: me) }
        } catch {
            isLiked = wasLiked
            likeCount += wasLiked ? 1 : -1
        }
    }

    private func toggleTranslation() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showTranslation.toggle()
        }
        guard showTranslation, translatedText == nil else { return }

        #if canImport(Translation) && canImport(_Translation_SwiftUI)
        if #available(iOS 18.0, *) {
            translationError = nil
            isTranslating = true
            translationRequestID += 1
        } else if #available(iOS 17.4, *) {
            showTranslation = false
            showSystemTranslation = true
        } else {
            translationError = "번역은 iOS 17.4 이상에서 사용할 수 있습니다."
        }
        #else
        translationError = "이 빌드에서는 번역 기능을 사용할 수 없습니다."
        #endif
    }

    private func unfollowAuthor() async {
        guard let authorId = item.author?.id else { return }
        await session.connections.perform(.disconnect, with: authorId)
    }

    private func toggleConnectionToAuthor() async {
        guard showConnectButton, let authorId = item.author?.id else { return }
        await session.connections.perform(authorConnectionStatus == .requestSent ? .cancel : .request, with: authorId)
    }

    private func deletePost() async {
        try? await session.repo.deleteActivity(id: item.id)
        if let onDeleted {
            onDeleted()
        } else {
            withAnimation { isDeleted = true }
        }
    }
}

#if canImport(Translation) && canImport(_Translation_SwiftUI)
@available(iOS 18.0, *)
private struct InlinePostTranslator: View {
    @Binding var requestID: Int
    let sourceText: String
    let targetLanguageCode: String
    @Binding var isTranslating: Bool
    @Binding var translatedText: String?
    @Binding var translationError: String?

    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        Color.clear
            .onChange(of: requestID) { _, newValue in
                guard newValue > 0 else { return }
                configuration = TranslationSession.Configuration(
                    source: nil,
                    target: Locale.Language(identifier: targetLanguageCode)
                )
            }
            .translationTask(configuration) { session in
                do {
                    let response = try await session.translate(sourceText)
                    await MainActor.run {
                        translatedText = response.targetText
                        translationError = nil
                        isTranslating = false
                    }
                } catch {
                    await MainActor.run {
                        translationError = "번역을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요."
                        isTranslating = false
                    }
                }
            }
    }
}
#endif

// MARK: - Post meatball bottom sheet

struct PostMeatballSheet: View {
    let isSaved: Bool
    let isOwnPost: Bool
    let onSave: () -> Void
    let onUnfollow: () -> Void
    let onHide: () -> Void
    let onReport: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            menuRow(
                title: isSaved ? "저장 취소" : "저장",
                icon:  isSaved ? "bookmark.fill" : "bookmark",
                tint: isSaved ? Color.accentColor : .primary
            ) { onSave(); dismiss() }

            rowDivider

            if isOwnPost {
                menuRow(title: "수정", icon: "pencil") {
                    onEdit(); dismiss()
                }
                rowDivider
                menuRow(title: "삭제", icon: "trash", tint: .red, destructive: true) {
                    onDelete(); dismiss()
                }
            } else {
                menuRow(title: "연결 끊기", icon: "person.badge.minus") {
                    onUnfollow(); dismiss()
                }
                rowDivider
                menuRow(title: "관심없음", icon: "eye.slash") {
                    onHide(); dismiss()
                }
                rowDivider
                menuRow(title: "신고", icon: "exclamationmark.triangle", tint: .red, destructive: true) {
                    onReport(); dismiss()
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 56)
    }

    private func menuRow(
        title: String,
        icon: String,
        tint: Color = .primary,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(destructive ? .red : tint)
                    .frame(width: 24, alignment: .center)
                Text(title)
                    .font(.body)
                    .foregroundStyle(destructive ? .red : .primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
