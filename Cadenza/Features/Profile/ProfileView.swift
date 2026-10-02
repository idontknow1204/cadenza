import SwiftUI

// MARK: - Main Profile View

struct ProfileView: View {
    @Environment(SessionStore.self) private var session

    @State private var activities: [ActivityWithAuthor] = []
    @State private var affiliations: [Affiliation] = []
    @State private var careers: [Career] = []
    @State private var awards: [ProfileAward] = []
    @State private var awardsLoadFailed = false
    @State private var languages: [ProfileLanguage] = []
    @State private var contactCount = 0
    @State private var loading = false
    @State private var errorText: String?

    // Org
    @State private var myOrgs: [Organization] = []
    @State private var showCreateOrg = false
    @State private var selectedOrg: Organization? = nil

    // Recommendations
    @State private var recommendations: [Recommendation] = []
    @State private var showRecommendationAdd = false
    @State private var showRecommendationEdit: Recommendation? = nil

    // Section visibility
    @State private var showAddSection = false
    @State private var showCvWebsiteEdit = false

    // Sheet controls
    @State private var showBasicEdit = false
    @State private var showBioEdit = false
    @State private var showAffiliationEdit: Affiliation? = nil
    @State private var showAffiliationAdd = false
    @State private var showCareerEdit: Career? = nil
    @State private var showCareerAdd = false
    @State private var showAwardAdd = false
    @State private var showAwardEdit: ProfileAward?
    @State private var showLanguageEdit = false
    @State private var showSettings = false
    @State private var showConnections = false
    @State private var showAllActivities = false

    private var profile: Profile? { session.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if let profile {
                        headerCard(profile)
                        if profile.showsSection(.bio) { bioCard(profile) }
                        if profile.showsSection(.activities) { activityPager }
                        if profile.showsSection(.career) { careerCard }
                        if profile.showsSection(.education) { educationCard }
                        if profile.showsSection(.awards) { awardsCard }
                        if profile.showsSection(.languages) { languageCard }

                        // Optional sections
                        if profile.showsSection(.cvWebsite) {
                            cvWebsiteCard(profile)
                        }
                        if profile.showsSection(.recommendations) {
                            recommendationsCard(profile)
                        }
                        if profile.showsSection(.org) {
                            orgCard
                        }

                        manageSectionsButton
                    } else if loading {
                        ProgressView().padding(40)
                    } else {
                        ContentUnavailableView {
                            Label(localized("프로필을 불러오지 못했어요", "Couldn't load your profile", "Profil konnte nicht geladen werden"),
                                  systemImage: "person.crop.circle.badge.exclamationmark")
                        } description: {
                            Text(session.profileError ?? localized("로그인 상태를 확인한 뒤 다시 시도해 주세요.", "Check your login and try again.", "Überprüfe deine Anmeldung und versuche es erneut."))
                        } actions: {
                            Button(localized("다시 시도", "Try again", "Erneut versuchen")) {
                                Task { await load() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 36)
                    }
                }
                .padding(.vertical, 12)
            }
            .cadenzaRefreshable { await load() }
            .task(id: session.authenticatedDataRevision) { await load() }
            .task(id: session.connections.revision) {
                guard let me = session.currentUserID else { return }
                if let count = try? await session.repo.connectionCount(userId: me) { contactCount = count }
            }
            .navigationTitle("tab.profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showAllActivities) {
                if let profile {
                    ProfileActivitiesView(userId: profile.id, initialActivities: activities)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSection = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .foregroundStyle(.primary)
                    .disabled(profile == nil)
                    .accessibilityLabel(localized("프로필 섹션 관리", "Profile Sections", "Profilabschnitte"))
                    .accessibilityIdentifier("profile.sections.manage")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .foregroundStyle(.primary)
                }
            }
            .alert("error.title", isPresented: .constant(errorText != nil)) {
                Button("common.ok") { errorText = nil }
            } message: { Text(errorText ?? "") }
            .navigationDestination(isPresented: Binding(
                get: { selectedOrg != nil },
                set: { if !$0 { selectedOrg = nil } }
            )) {
                if let org = selectedOrg {
                    OrgPageView(orgId: org.id)
                }
            }
        }
        // Sheets
        .sheet(isPresented: $showBasicEdit, onDismiss: { Task { await load() } }) {
            EditProfileView()
        }
        .sheet(isPresented: $showBioEdit, onDismiss: { Task { await session.refreshProfile() } }) {
            BioEditSheet()
        }
        .sheet(isPresented: $showAffiliationAdd, onDismiss: { Task { await load() } }) {
            AffiliationEditSheet(existing: nil)
        }
        .sheet(item: $showAffiliationEdit, onDismiss: { Task { await load() } }) { aff in
            AffiliationEditSheet(existing: aff)
        }
        .sheet(isPresented: $showCareerAdd, onDismiss: { Task { await load() } }) {
            CareerEditSheet(existing: nil)
        }
        .sheet(item: $showCareerEdit, onDismiss: { Task { await load() } }) { career in
            CareerEditSheet(existing: career)
        }
        .sheet(isPresented: $showLanguageEdit, onDismiss: { Task { await load() } }) {
            LanguageEditSheet(current: languages)
        }
        .sheet(isPresented: $showAwardAdd, onDismiss: { Task { await loadAwards() } }) {
            AwardEditSheet(existing: nil)
        }
        .sheet(item: $showAwardEdit, onDismiss: { Task { await loadAwards() } }) { award in
            AwardEditSheet(existing: award)
        }
        .sheet(isPresented: $showSettings) {
            ProfileSettingsView(
                languages: languages,
                defaultVisibility: profile?.defaultVisibility ?? .industryFollowers,
                onEditLanguages: {
                    showSettings = false
                    showLanguageEdit = true
                },
                onSignOut: {
                    showSettings = false
                    Task { await session.signOut() }
                }
            )
        }
        .sheet(isPresented: $showConnections) {
            if let profile {
                NavigationStack {
                    ConnectionsListView(userId: profile.id)
                        .navigationDestination(for: UserProfileRoute.self) { route in
                            PublicProfileView(userId: route.id)
                        }
                }
            }
        }
        .sheet(isPresented: $showAddSection) {
            AddProfileSectionSheet(visibleSections: profile?.visibleSections ?? []) { sections in
                try await saveSections(sections)
            }
        }
        .sheet(isPresented: $showCvWebsiteEdit, onDismiss: { Task { await session.refreshProfile() } }) {
            if let profile {
                CvWebsiteEditSheet(
                    userId: profile.id,
                    currentCvUrl: profile.cvUrl,
                    currentWebsiteUrl: profile.websiteUrl
                ) { cv, web in
                    Task { await session.refreshProfile() }
                }
            }
        }
        .sheet(isPresented: $showRecommendationAdd, onDismiss: { Task { await loadRecommendations() } }) {
            if let profile {
                RecommendationEditSheet(recipientId: profile.id) { rec in
                    recommendations.insert(rec, at: 0)
                }
            }
        }
        .sheet(item: $showRecommendationEdit, onDismiss: { Task { await loadRecommendations() } }) { rec in
            if let profile {
                RecommendationEditSheet(existing: rec, recipientId: profile.id) { updated in
                    if let idx = recommendations.firstIndex(where: { $0.id == updated.id }) {
                        recommendations[idx] = updated
                    }
                } onDelete: {
                    recommendations.removeAll { $0.id == rec.id }
                }
            }
        }
    }

    // MARK: - Header card

    private func headerCard(_ profile: Profile) -> some View {
        SectionCard {
            HStack(alignment: .top, spacing: 14) {
                avatarView(profile)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.realName).font(.title2.bold())
                    if let inst = profile.instrument, !inst.isEmpty {
                        HStack(spacing: 4) {
                            if let major = profile.major { Text(OnboardingData.majorDisplay(major)) }
                            if profile.major != nil { Text("·").foregroundStyle(.tertiary) }
                            Text(OnboardingData.instrumentDisplay(inst))
                        }
                        .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if let aff = affiliations.first {
                        Text(aff.institutionName)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { showBasicEdit = true } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1), in: Circle())
                }
                .foregroundStyle(.primary)
            }

            // Connector count
            Button { showConnections = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(localized("\(contactCount)명과 연결됨", "Connected with \(contactCount)", "Verbunden mit \(contactCount)"))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.connections")

            // City chips
            if !profile.homeCities.isEmpty {
                let cities = profile.homeCities.compactMap { id in
                    OnboardingData.cityOptions.first { $0.id == id }
                }
                FlowLayout(spacing: 6) {
                    ForEach(cities) { city in
                        Text(city.localizedName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.top, 3)
            }
        }
    }

    @ViewBuilder
    private func avatarView(_ profile: Profile) -> some View {
        Group {
            if let url = profile.avatarUrl, let u = URL(string: url) {
                AsyncImage(url: u) { phase in
                    if case .success(let img) = phase { img.resizable().scaledToFill() }
                    else { Color.secondary.opacity(0.15) }
                }
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().foregroundStyle(.secondary.opacity(0.35))
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Bio card

    private func bioCard(_ profile: Profile) -> some View {
        SectionCard(title: ProfileSection.bio.title, onEdit: { showBioEdit = true }) {
            if let bio = profile.bio, !bio.isEmpty {
                Text(bio).font(.subheadline).lineSpacing(3)
            } else {
                Text(verbatim: localized("소개글을 작성해보세요", "Add a bio", "Bio hinzufügen"))
                    .font(.subheadline).foregroundStyle(.tertiary).italic()
            }
        }
    }

    // MARK: - Activity pager

    private var activityPager: some View {
        SectionCard {
            Button { showAllActivities = true } label: {
                HStack(spacing: 12) {
                    Text(ProfileSection.activities.title)
                        .font(.headline).foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(localized("전체 보기", "View all", "Alle anzeigen"))
                        .font(.subheadline)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.primary)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(localized("나의 활동 전체 보기", "View all my activities", "Alle meine Aktivitäten anzeigen")))
            .accessibilityIdentifier("profile.activities.all")

            if activities.isEmpty {
                Text(verbatim: localized("아직 기록한 활동이 없어요.", "No activities yet.", "Noch keine Aktivitäten."))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                TabView {
                    ForEach(activities) { item in
                        ActivityPagerCard(item: item)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 20) // space for page dots
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 150)
                .padding(.horizontal, -4)
            }
        }
    }

    // MARK: - Career card

    private var careerCard: some View {
        SectionCard(title: ProfileSection.career.title, onAdd: { showCareerAdd = true }) {
            if careers.isEmpty {
                emptyRow(localized("경력을 추가해보세요", "Add your career history", "Berufserfahrung hinzufügen"))
            } else {
                ForEach(careers) { c in
                    Button { showCareerEdit = c } label: {
                        CareerRow(career: c, showsDisclosure: true, interactiveLinks: false)
                    }
                    .foregroundStyle(.primary)
                    if c.id != careers.last?.id { Divider() }
                }
            }
        }
    }

    // MARK: - Education card

    private var educationCard: some View {
        SectionCard(title: ProfileSection.education.title, onAdd: { showAffiliationAdd = true }) {
            if affiliations.isEmpty {
                emptyRow(localized("학력을 추가해보세요", "Add your education", "Ausbildung hinzufügen"))
            } else {
                ForEach(affiliations) { aff in
                    Button { showAffiliationEdit = aff } label: {
                        AffiliationRow(affiliation: aff)
                    }
                    .foregroundStyle(.primary)
                    if aff.id != affiliations.last?.id { Divider() }
                }
            }
        }
    }

    // MARK: - Awards

    private var awardsCard: some View {
        SectionCard(title: ProfileSection.awards.title, onAdd: { showAwardAdd = true }) {
            if awardsLoadFailed {
                Text(localized("수상 경력을 불러오지 못했습니다.", "Unable to load awards.", "Auszeichnungen konnten nicht geladen werden."))
                    .font(.subheadline).foregroundStyle(.secondary)
                Button { Task { await loadAwards() } } label: {
                    Label(localized("다시 시도", "Retry", "Erneut versuchen"), systemImage: "arrow.clockwise")
                }
            } else if awards.isEmpty {
                emptyRow(localized("수상 경력을 추가해보세요", "Add your honors and awards", "Auszeichnungen hinzufuegen"))
            } else {
                ForEach(awards) { award in
                    Button { showAwardEdit = award } label: {
                        ProfileAwardRow(award: award, showsDisclosure: true, interactiveLinks: false)
                    }
                    .buttonStyle(.plain)
                    if award.id != awards.last?.id { Divider() }
                }
            }
        }
    }

    private func loadAwards() async {
        guard let me = session.currentUserID else { return }
        do {
            awards = try await session.repo.awards(forUser: me)
            awardsLoadFailed = false
        } catch {
            awardsLoadFailed = true
        }
    }

    // MARK: - Language card

    private var languageCard: some View {
        SectionCard(title: ProfileSection.languages.title, onEdit: { showLanguageEdit = true }) {
            if languages.isEmpty {
                emptyRow(localized("사용 언어를 추가해보세요", "Add languages you speak", "Sprachen hinzufügen"))
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(languages) { lang in
                        LanguageChip(lang: lang)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(verbatim: text).font(.subheadline).foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
    }

    // MARK: - Load

    private func load() async {
        guard let me = session.currentUserID else {
            errorText = localized("로그인 세션을 확인해 주세요.", "Please check your login session.", "Bitte überprüfe deine Anmeldung.")
            return
        }
        loading = true; defer { loading = false }
        do {
            await session.refreshProfile()
            guard session.profile != nil else { return }
            async let a  = session.repo.activities(byAuthor: me)
            async let af = session.repo.affiliations(forUser: me)
            async let c  = session.repo.careers(forUser: me)
            async let l  = session.repo.languages(forUser: me)
            async let cc = session.repo.connectionCount(userId: me)
            async let og = session.repo.myOrgs(userId: me)
            (activities, affiliations, careers, languages, contactCount) =
                try await (a, af, c, l, cc)
            myOrgs = (try? await og) ?? []
        } catch { errorText = error.localizedDescription }
        await loadRecommendations()
        await loadAwards()
    }

    private func loadRecommendations() async {
        guard let me = session.currentUserID,
              profile?.showsSection(.recommendations) == true else { return }
        recommendations = (try? await session.repo.recommendations(for: me)) ?? []
    }

    @MainActor
    private func saveSections(_ sections: [String]) async throws {
        guard let me = session.currentUserID else { throw CancellationError() }
        let updated = try await session.repo.updateVisibleSections(id: me, sections: sections)
        guard session.currentUserID == me else { throw CancellationError() }
        session.profile = updated
        await loadRecommendations()
    }

    // MARK: - Manage sections button

    private var manageSectionsButton: some View {
        Button { showAddSection = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                Text(localized("프로필 섹션 관리", "Profile Sections", "Profilabschnitte"))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - CV / Website card

    private func cvWebsiteCard(_ profile: Profile) -> some View {
        SectionCard(title: ProfileSection.cvWebsite.title, onEdit: { showCvWebsiteEdit = true }) {
            let hasCv      = !(profile.cvUrl ?? "").isEmpty
            let hasWebsite = !(profile.websiteUrl ?? "").isEmpty

            if !hasCv && !hasWebsite {
                Button { showCvWebsiteEdit = true } label: {
                    Label(localized("CV 또는 홈페이지 추가", "Add CV or Website", "CV oder Webseite hinzufügen"), systemImage: "plus.circle")
                        .font(.subheadline).foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if hasCv, let cvUrl = profile.cvUrl, let url = URL(string: cvUrl) {
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.fill")
                                    .font(.title3).foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localized("CV / 이력서", "CV / Resume", "CV / Lebenslauf")).font(.subheadline.weight(.medium))
                                    Text(cvUrl.components(separatedBy: "/").last ?? cvUrl)
                                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    if hasWebsite, let webUrl = profile.websiteUrl, let url = URL(string: webUrl) {
                        if hasCv { Divider() }
                        Link(destination: url) {
                            HStack(spacing: 10) {
                                Image(systemName: "globe")
                                    .font(.title3).foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localized("홈페이지", "Website", "Webseite")).font(.subheadline.weight(.medium))
                                    Text(webUrl).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    // MARK: - Recommendations card

    private func recommendationsCard(_ profile: Profile) -> some View {
        SectionCard(
            title: recommendations.isEmpty
                ? ProfileSection.recommendations.title
                : ProfileSection.recommendations.title + " (\(recommendations.count))",
            onAdd: { showRecommendationAdd = true }
        ) {
            if recommendations.isEmpty {
                Button { showRecommendationAdd = true } label: {
                    Label(localized("추천서 추가", "Add recommendation", "Empfehlung hinzufügen"), systemImage: "plus.circle")
                        .font(.subheadline).foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(recommendations) { rec in
                    Button { showRecommendationEdit = rec } label: {
                        RecommendationRow(rec: rec)
                    }
                    .foregroundStyle(.primary)
                    if rec.id != recommendations.last?.id { Divider() }
                }
            }
        }
    }

    // MARK: - Org card

    private var orgCard: some View {
        SectionCard(title: ProfileSection.org.title, onAdd: { showCreateOrg = true }) {
            if myOrgs.isEmpty {
                Button {
                    showCreateOrg = true
                } label: {
                    Label(localized("기관 페이지 만들기", "Create organization page", "Organisationsseite erstellen"), systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(myOrgs) { org in
                    Button { selectedOrg = org } label: {
                        HStack(spacing: 12) {
                            OrgAvatar(category: org.category, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(org.name).font(.subheadline.weight(.medium))
                                Text(org.category.label).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showCreateOrg, onDismiss: { Task { await load() } }) {
            CreateOrgView { org in
                myOrgs.append(org)
            }
        }
    }
}

// MARK: - Shared section card container

struct SectionCard<Content: View>: View {
    var title: String? = nil
    var onAdd: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || onAdd != nil || onEdit != nil {
                HStack {
                    // Text(verbatim:) is intentional — the caller provides an
                    // already-localized string via localized() or a xcstrings key
                    // resolved through the swizzled LanguageBundle.
                    if let title { Text(verbatim: title).font(.headline) }
                    Spacer()
                    if let onAdd {
                        Button(action: onAdd) {
                            Image(systemName: "plus")
                                .font(.subheadline.weight(.medium))
                                .padding(7)
                                .background(Color.secondary.opacity(0.1), in: Circle())
                        }
                        .foregroundStyle(.primary)
                        .accessibilityLabel(Text((title ?? "") + localized(" 추가", " add", " hinzufuegen")))
                    }
                    if let onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.subheadline)
                                .padding(7)
                                .background(Color.secondary.opacity(0.1), in: Circle())
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        .padding(.horizontal, 16)
    }
}

// MARK: - Activity pager card (compact)

struct ActivityPagerCard: View {
    let item: ActivityWithAuthor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ActivityTypeLabel(type: item.type)
                Spacer()
                if item.verification != .pending {
                    BadgeChip(status: item.verification)
                }
            }
            Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            HStack(spacing: 6) {
                Text(item.activityDate).font(.caption).foregroundStyle(.secondary)
                if let loc = item.location, !loc.isEmpty {
                    Text("·").foregroundStyle(.tertiary)
                    Text(loc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            if let role = item.role, !role.isEmpty {
                Text(role).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Career row

struct CareerRow: View {
    let career: Career
    var showsDisclosure = false
    var interactiveLinks = true

    private var yearRange: String {
        let start = career.startYear.map(String.init) ?? "?"
        let end = career.isCurrent ? NSLocalizedString("profile.career.current.short", comment: "") : (career.endYear.map(String.init) ?? "?")
        return "\(start) – \(end)"
    }

    private var attachments: [(title: String, icon: String, url: String)] {
        var values: [(title: String, icon: String, url: String)] = []
        if let link = career.linkUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty {
            values.append((title: localized("관련 링크", "Related link", "Relevanter Link"), icon: "link", url: link))
        }
        if let media = career.mediaUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !media.isEmpty {
            values.append((title: localized("영상", "Video", "Video"), icon: "play.rectangle", url: media))
        }
        return values
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(career.organization).font(.subheadline.weight(.semibold))
                    Text(career.role).font(.caption).foregroundStyle(.secondary)
                    Text(yearRange).font(.caption).foregroundStyle(.tertiary)
                }

                if let description = career.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let contribution = career.contribution, !contribution.isEmpty {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "diamond")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(localized("기여", "Contribution", "Beitrag"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(contribution)
                                .font(.caption)
                                .foregroundStyle(.primary.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !attachments.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(attachments, id: \.url) { attachment in
                            CareerAttachmentRow(
                                title: attachment.title,
                                icon: attachment.icon,
                                urlString: attachment.url,
                                interactive: interactiveLinks
                            )
                        }
                    }
                    .padding(.top, 1)
                }
            }
            Spacer()
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
            }
        }
        .padding(.vertical, 8)
    }
}

struct CareerAttachmentRow: View {
    let title: String
    let icon: String
    let urlString: String
    var interactive: Bool

    private var hostText: String {
        guard let url = URL(string: urlString),
              let host = url.host(percentEncoded: false) else {
            return urlString
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

    var body: some View {
        Group {
            if interactive, let url = URL(string: urlString) {
                Link(destination: url) {
                    rowContent
                }
            } else {
                rowContent
            }
        }
        .foregroundStyle(.primary)
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(hostText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if interactive {
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Affiliation row

struct AffiliationRow: View {
    let affiliation: Affiliation

    private var yearRange: String {
        var parts: [String] = []
        if let s = affiliation.enrollmentYear { parts.append(String(s)) }
        if affiliation.isCurrent {
            if let g = affiliation.graduationYear {
                parts.append("\(g) (\(NSLocalizedString("profile.education.expected", comment: "")))")
            } else {
                parts.append(NSLocalizedString("profile.career.current.short", comment: ""))
            }
        } else if let e = affiliation.graduationYear ?? affiliation.enrollmentYear.map({ $0 + 4 }) {
            parts.append(String(e))
        }
        return parts.joined(separator: " – ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(affiliation.institutionName).font(.subheadline.weight(.medium))
                if let ct = affiliation.courseType,
                   let opt = OnboardingData.courseOptions.first(where: { $0.id == ct }) {
                    Text(opt.label).font(.caption).foregroundStyle(.secondary)
                }
                if !yearRange.isEmpty {
                    Text(yearRange).font(.caption).foregroundStyle(.tertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Recommendation row

struct RecommendationRow: View {
    let rec: Recommendation
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption2).foregroundStyle(.tertiary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(rec.recommenderName).font(.subheadline.weight(.semibold))
                    if let title = rec.recommenderTitle, !title.isEmpty {
                        Text(title).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !rec.isVisible {
                    Image(systemName: "eye.slash")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            Text(rec.body)
                .font(.subheadline).foregroundStyle(.secondary)
                .lineLimit(expanded ? nil : 3)
                .lineSpacing(2)
            if rec.body.count > 120 {
                Button { expanded.toggle() } label: {
                    Text(expanded ? localized("접기", "Collapse", "Einklappen") : localized("더보기", "More", "Mehr"))
                        .font(.caption).foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Language chip

struct LanguageChip: View {
    let lang: ProfileLanguage

    private var levelLabel: String {
        switch lang.level {
        case "native":       return NSLocalizedString("profile.language.native", comment: "")
        case "fluent":       return NSLocalizedString("profile.language.fluent", comment: "")
        case "intermediate": return NSLocalizedString("profile.language.intermediate", comment: "")
        default:             return NSLocalizedString("profile.language.basic", comment: "")
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(lang.language).font(.subheadline.weight(.medium))
            Text(levelLabel).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }
}
