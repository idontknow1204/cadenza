import SwiftUI

struct JobsView: View {
    var scrollToTop: Int = 0
    @Environment(SessionStore.self) private var session
    @State private var jobs: [Job] = []
    @State private var baseCityIDs: [String] = []
    @State private var cityByID: [String: City] = [:]
    @State private var loading = false
    @State private var loadError: String?
    @State private var showCreate = false
    @State private var showFilter = false
    @State private var filter = JobFilter()
    @State private var sort: JobSort = .cityFirst
    @State private var searchText = ""
    @State private var searchActive = false
    @State private var searchResults: [Job] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var completedQuery = ""
    @State private var searchRequestID = UUID()

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !query.isEmpty }
    private var waitingForSearch: Bool { isSearching && (searching || completedQuery != query) }
    private var filtered: [Job] {
        filter.apply(to: isSearching ? searchResults : jobs, cityByID: cityByID)
    }
    private var sections: [JobSection] {
        JobSection.build(jobs: filtered, baseCityIDs: baseCityIDs, cityByID: cityByID)
    }
    private var flatJobs: [Job] {
        filtered.sorted {
            if sort == .recent { return $0.createdAt > $1.createdAt }
            let a = deadlineKey($0), b = deadlineKey($1)
            return a == b ? $0.createdAt > $1.createdAt : a < b
        }
    }
    private func deadlineKey(_ job: Job) -> Int {
        guard let days = job.daysLeft else { return Int.max }
        return days < 0 ? Int.max - 1 : days
    }
    private var availableCountries: [String] {
        Array(Set((jobs + searchResults).compactMap {
            $0.cityId.flatMap { cityByID[$0]?.countryCode }
        })).sorted()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CadenzaBrowseHeader(
                    searchQuery: $searchText,
                    searchActive: $searchActive,
                    unreadNotificationCount: 0,
                    onNotifications: {},
                    onCreate: { showCreate = true },
                    title: Text(localized("채용", "Jobs", "Stellen")),
                    searchPrompt: Text(localized("기관·악기·도시 검색", "Institution, instrument, city", "Institution, Instrument, Stadt")),
                    createLabel: Text(localized("공고 올리기", "Post an opportunity", "Ausschreibung erstellen")),
                    accessibilityPrefix: "jobs",
                    showsNotifications: false,
                    showsLogo: false
                )
                filterBar
                Divider()
                content
            }
            .background(Color(.secondarySystemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .task(id: searchText) { await runSearch() }
            .task(id: session.authenticatedDataRevision) { await load() }
            .sheet(isPresented: $showCreate, onDismiss: { Task { await load() } }) {
                CreateJobView()
            }
            .sheet(isPresented: $showFilter) {
                JobFilterSheet(filter: $filter, sort: $sort,
                               myInstrument: session.profile?.instrument,
                               availableCountries: availableCountries)
                    .presentationDetents([.large])
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { showFilter = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text(localized("필터", "Filters", "Filter"))
                        if filter.activeCount > 0 {
                            Text("\(filter.activeCount)")
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12),
                                            in: Capsule())
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Color("BrandSurface"), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(Color.accentColor)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("jobs.filters")
                .frame(minHeight: 44)

                if let instrument = session.profile?.instrument, !instrument.isEmpty {
                    quickFilter(OnboardingData.instrumentDisplay(instrument), symbol: "music.note",
                                selected: filter.instruments == [instrument]) {
                        filter.instruments = filter.instruments == [instrument] ? [] : [instrument]
                    }
                }
                quickFilter(localized("모집 중", "Open", "Offen"), symbol: "checkmark.circle",
                            selected: filter.openOnly) { filter.openOnly.toggle() }
                quickFilter(localized("영상 예선", "Video round", "Video-Vorrunde"), symbol: "video",
                            selected: filter.videoOnly) { filter.videoOnly.toggle() }
            }
            .font(.footnote.weight(.medium))
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .background(Color(.systemBackground))
    }

    private func quickFilter(_ title: String, symbol: String, selected: Bool,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(selected ? Color("BrandSurface") : Color(.quaternarySystemFill),
                            in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(selected ? Color.accentColor : .secondary)
                .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .frame(minHeight: 44)
    }

    private var content: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 0).id("jobs-top")
                if waitingForSearch || (loading && jobs.isEmpty && !isSearching) {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if let error = isSearching ? searchError : loadError,
                          (isSearching ? searchResults : jobs).isEmpty {
                    ContentUnavailableView {
                        Label(localized("공고를 불러오지 못했어요", "Couldn't load opportunities", "Ausschreibungen konnten nicht geladen werden"), systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button(localized("다시 시도", "Try again", "Erneut versuchen")) {
                            Task { if isSearching { await runSearch() } else { await load() } }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 36)
                } else {
                    if !isSearching, loadError != nil {
                        Label(localized("새로고침하지 못했어요. 아래로 당겨 다시 시도하세요.", "Couldn't refresh. Pull down to retry.", "Aktualisierung fehlgeschlagen. Zum Wiederholen nach unten ziehen."), systemImage: "wifi.exclamationmark")
                            .font(.footnote).foregroundStyle(.secondary).padding(16)
                    }
                    if filtered.isEmpty {
                        emptyState
                    } else if sort == .cityFirst {
                        ForEach(sections) { section in
                            sectionHeader(section)
                            ForEach(section.jobs) { job in jobRow(job) }
                        }
                    } else {
                        ForEach(flatJobs) { job in jobRow(job) }
                    }
                }
            }
            .padding(.bottom, 24)
            .adaptiveContentWidth()
        }
        .scrollDismissesKeyboard(.interactively)
        .cadenzaRefreshable {
            await load()
            if isSearching { await runSearch() }
        }
        .onChange(of: scrollToTop) {
            withAnimation { proxy.scrollTo("jobs-top", anchor: .top) }
        }
        } // ScrollViewReader
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(localized("조건에 맞는 공고가 없어요", "No matching opportunities", "Keine passenden Ausschreibungen"),
                  systemImage: isSearching ? "magnifyingglass" : "briefcase")
        } description: {
            Text(localized("검색어나 필터를 바꿔 다른 기회를 찾아보세요.", "Try another search or adjust your filters.", "Ändere den Suchbegriff oder die Filter."))
        } actions: {
            if filter != JobFilter() {
                Button(localized("필터 초기화", "Reset filters", "Filter zurücksetzen")) { filter = JobFilter() }
                    .buttonStyle(.bordered)
            } else if isSearching {
                Button(localized("검색 지우기", "Clear search", "Suche löschen")) { searchText = "" }
                    .buttonStyle(.bordered)
            } else if jobs.isEmpty {
                Button(localized("첫 공고 올리기", "Post an opportunity", "Ausschreibung erstellen")) { showCreate = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.top, 24)
    }

    private func jobRow(_ job: Job) -> some View {
        VStack(spacing: 0) {
            NavigationLink {
                JobDetailView(job: job, onClosed: {
                    jobs.removeAll { $0.id == job.id }
                    searchResults.removeAll { $0.id == job.id }
                })
            } label: { JobCard(job: job) }
                .buttonStyle(.plain)
            PostSeparator()
        }
    }

    private func sectionHeader(_ section: JobSection) -> some View {
        HStack(spacing: 7) {
            Image(systemName: section.kind.symbol).foregroundStyle(Color.accentColor)
            Text(section.title).foregroundStyle(.primary)
            Text("\(section.jobs.count)").foregroundStyle(.secondary)
            Spacer()
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityAddTraits(.isHeader)
    }

    @MainActor
    private func runSearch() async {
        let requestID = UUID()
        searchRequestID = requestID
        let requestedQuery = query
        searchError = nil
        guard !requestedQuery.isEmpty else {
            searchResults = []; searching = false; completedQuery = ""; return
        }
        searching = true
        defer { if searchRequestID == requestID { searching = false } }
        do {
            try await Task.sleep(for: .milliseconds(300))
            let results = try await session.repo.searchOpportunities(query: requestedQuery)
            try Task.checkCancellation()
            guard searchRequestID == requestID, query == requestedQuery else { return }
            searchResults = results
            completedQuery = requestedQuery
        } catch {
            guard !Task.isCancelled, searchRequestID == requestID, query == requestedQuery else { return }
            searchResults = []
            completedQuery = requestedQuery
            searchError = localized("연결을 확인하고 다시 시도해 주세요.", "Check your connection and try again.", "Prüfe deine Verbindung und versuche es erneut.")
        }
    }

    @MainActor
    private func load() async {
        guard !loading else { return }
        guard session.currentUserID != nil else {
            jobs = []
            loadError = localized("로그인 세션을 확인해 주세요.", "Please check your login session.", "Bitte überprüfe deine Anmeldung.")
            return
        }
        loading = true
        defer { loading = false }
        do {
            let validSession = try await session.ensureAuthenticatedSession()
            let me = validSession.user.id
            async let jobsTask = session.repo.jobs()
            async let citiesTask = session.repo.cities()
            async let basesTask = session.repo.baseCityIDs(userId: me)

            let loadedJobs = try await jobsTask
            let loadedCities = try? await citiesTask
            let loadedBases = try? await basesTask

            guard session.currentUserID == me else { throw CancellationError() }
            if let loadedCities {
                cityByID = Dictionary(uniqueKeysWithValues: loadedCities.map { ($0.id, $0) })
            }
            if let loadedBases { baseCityIDs = loadedBases }
            jobs = loadedJobs
            loadError = nil
        } catch {
            if !Task.isCancelled {
                loadError = localized("연결을 확인하고 다시 시도해 주세요.", "Check your connection and try again.", "Prüfe deine Verbindung und versuche es erneut.")
            }
        }
    }
}

// MARK: - City-first sections (§6)

struct JobSection: Identifiable {
    enum Kind: Equatable {
        case baseCity, baseCountry, video, rest
        var symbol: String {
            switch self {
            case .baseCity:    return "mappin.circle.fill"
            case .baseCountry: return "flag.fill"
            case .video:       return "video.fill"
            case .rest:        return "square.grid.2x2"
            }
        }
        var tint: Color {
            switch self {
            case .baseCity:    return .accentColor
            case .baseCountry: return .accentColor
            case .video:       return .accentColor
            case .rest:        return .secondary
            }
        }
    }

    let id: String
    let title: String
    let kind: Kind
    let jobs: [Job]

    /// Nearest deadline first; past/unknown deadlines sink to the bottom.
    private static func byDeadline(_ a: Job, _ b: Job) -> Bool {
        func key(_ j: Job) -> Int {
            guard let d = j.daysLeft else { return Int.max }
            return d < 0 ? Int.max - 1 : d
        }
        let ka = key(a), kb = key(b)
        if ka != kb { return ka < kb }
        return a.createdAt > b.createdAt
    }

    static func build(jobs: [Job], baseCityIDs: [String], cityByID: [String: City]) -> [JobSection] {
        var used = Set<UUID>()
        var out: [JobSection] = []

        // 1. Each base city (§6: 거점 도시, 반경은 이후 단계)
        for cid in baseCityIDs {
            let group = jobs.filter { $0.cityId == cid && !used.contains($0.id) }
                            .sorted(by: byDeadline)
            guard !group.isEmpty else { continue }
            group.forEach { used.insert($0.id) }
            out.append(JobSection(id: "city-\(cid)",
                                  title: cityByID[cid]?.localizedName ?? cid,
                                  kind: .baseCity, jobs: group))
        }

        // 2. Each base country (거점 국가) — jobs in that country not already bucketed
        var seenCountry = Set<String>()
        let baseCountries = baseCityIDs.compactMap { cityByID[$0]?.countryCode }
            .filter { seenCountry.insert($0).inserted }
        for cc in baseCountries {
            let group = jobs.filter { j in
                guard !used.contains(j.id), let cid = j.cityId else { return false }
                return cityByID[cid]?.countryCode == cc
            }.sorted(by: byDeadline)
            guard !group.isEmpty else { continue }
            group.forEach { used.insert($0.id) }
            out.append(JobSection(id: "country-\(cc)",
                                  title: localizedCountryName(cc),
                                  kind: .baseCountry, jobs: group))
        }

        // 3. 영상으로 지원 가능
        let video = jobs.filter { ($0.videoAudition ?? false) && !used.contains($0.id) }
                        .sorted(by: byDeadline)
        if !video.isEmpty {
            video.forEach { used.insert($0.id) }
            out.append(JobSection(id: "video",
                                  title: localized("영상으로 지원 가능", "Apply by video", "Bewerbung per Video"),
                                  kind: .video, jobs: video))
        }

        // 4. 그 외
        let rest = jobs.filter { !used.contains($0.id) }.sorted(by: byDeadline)
        if !rest.isEmpty {
            out.append(JobSection(id: "rest",
                                  title: localized("그 외", "Others", "Weitere"),
                                  kind: .rest, jobs: rest))
        }
        return out
    }
}

// MARK: - Job card

struct JobCard: View {
    let job: Job
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static func typeColor(_ type: JobType) -> Color { .accentColor }

    private var organizationTitle: String {
        guard let organization = job.organization, !organization.isEmpty else { return job.type.label }
        return organization
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader

            Text(job.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let location = job.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if !job.instruments.isEmpty {
                Text(job.instruments.map { OnboardingData.instrumentDisplay($0) }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if job.videoAudition == true || job.applicationFee == 0 || job.hasScholarship == true {
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 8) { applicationFacts }
                    } else {
                        FlowLayout(spacing: 12) { applicationFacts }
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var cardHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                JobDeadlineBadge(job: job)
                Text(organizationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(job.type.label, systemImage: job.type.symbol)
                    .font(.caption).foregroundStyle(Color.accentColor)
            }
        } else {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: job.type.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color("BrandSurface"), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(organizationTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(job.type.label).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                JobDeadlineBadge(job: job)
            }
        }
    }

    @ViewBuilder
    private var applicationFacts: some View {
        if job.videoAudition == true {
            Label(localized("영상 예선", "Video round", "Video-Vorrunde"), systemImage: "video")
        }
        if job.applicationFee == 0 {
            Label(localized("지원료 없음", "No application fee", "Keine Bewerbungsgebühr"), systemImage: "checkmark.circle")
        }
        if job.hasScholarship == true {
            Label(localized("장학금", "Scholarship", "Stipendium"), systemImage: "graduationcap")
        }
    }
}

struct JobDeadlineBadge: View {
    let job: Job
    private var closed: Bool { !job.isActive || job.status == "closed" || (job.daysLeft ?? 0) < 0 }
    private var upcoming: Bool { !closed && job.status == "announced" }
    private var urgent: Bool { job.isAcceptingApplications && (job.daysLeft.map { $0 <= 3 } ?? false) }
    private var label: String? {
        if closed { return localized("마감", "Closed", "Beendet") }
        if upcoming { return localized("모집 예정", "Upcoming", "Demnächst") }
        return job.deadlineLabel
    }
    var body: some View {
        if let label {
            Text(label)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(urgent ? Color.accentColor : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(urgent ? Color("BrandSurface") : Color(.tertiarySystemFill),
                            in: RoundedRectangle(cornerRadius: 6))
                .fixedSize()
        }
    }
}
