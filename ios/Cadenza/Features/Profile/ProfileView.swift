import SwiftUI

// MARK: - Main Profile View

struct ProfileView: View {
    var activityRevision = 0
    var scrollToTop: Int = 0
    @Environment(SessionStore.self) private var session

    @State private var activities: [ActivityWithAuthor] = []
    @State private var affiliations: [Affiliation] = []
    @State private var careers: [Career] = []
    @State private var awards: [ProfileAward] = []
    @State private var awardsLoadFailed = false
    @State private var languages: [ProfileLanguage] = []
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
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    Color.clear.frame(height: 0).id("profile-top")
                    if let profile {
                        headerCard(profile)
                        if profile.showsSection(.bio) { bioCard(profile) }
                        if profile.showsSection(.education) { educationCard }
                        if profile.showsSection(.activities) { activityPager }
                        if profile.showsSection(.career) { careerCard }
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
                .adaptiveContentWidth()
            }
            .cadenzaRefreshable { await load() }
            .task(id: "\(session.authenticatedDataRevision):\(activityRevision)") { await load() }
            .onChange(of: scrollToTop) {
                withAnimation { proxy.scrollTo("profile-top", anchor: .top) }
            }
            } // ScrollViewReader
            .navigationTitle("tab.profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showAllActivities) {
                if let profile {
                    ProfileActivitiesView(
                        userId: profile.id,
                        initialActivities: activities,
                        activityRevision: activityRevision
                    )
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
        .sheet(isPresented: $showBasicEdit) {
            EditProfileView { updatedProfile, updatedAffiliation in
                session.profile = updatedProfile
                if let updatedAffiliation { mergeAffiliation(updatedAffiliation) }
            }
        }
        .sheet(isPresented: $showBioEdit) {
            BioEditSheet()
        }
        .sheet(isPresented: $showAffiliationAdd) {
            AffiliationEditSheet(existing: nil) { saved in
                mergeAffiliation(saved)
            } onDelete: { id in
                affiliations.removeAll { $0.id == id }
            }
        }
        .sheet(item: $showAffiliationEdit) { aff in
            AffiliationEditSheet(existing: aff) { saved in
                mergeAffiliation(saved)
            } onDelete: { id in
                affiliations.removeAll { $0.id == id }
            }
        }
        .sheet(isPresented: $showCareerAdd) {
            CareerEditSheet(existing: nil) { saved in
                mergeCareer(saved)
            } onDelete: { id in
                careers.removeAll { $0.id == id }
            }
        }
        .sheet(item: $showCareerEdit) { career in
            CareerEditSheet(existing: career) { saved in
                mergeCareer(saved)
            } onDelete: { id in
                careers.removeAll { $0.id == id }
            }
        }
        .sheet(isPresented: $showLanguageEdit) {
            LanguageEditSheet(current: languages) { updated in
                languages = updated
            }
        }
        .sheet(isPresented: $showAwardAdd) {
            AwardEditSheet(existing: nil) { saved in
                mergeAward(saved)
            } onDelete: { id in
                awards.removeAll { $0.id == id }
            }
        }
        .sheet(item: $showAwardEdit) { award in
            AwardEditSheet(existing: award) { saved in
                mergeAward(saved)
            } onDelete: { id in
                awards.removeAll { $0.id == id }
            }
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
        .sheet(isPresented: $showCvWebsiteEdit) {
            if let profile {
                CvWebsiteEditSheet(
                    userId: profile.id,
                    currentCvUrl: profile.cvUrl,
                    currentWebsiteUrl: profile.websiteUrl
                ) { _, _ in
                    // The sheet installs the authoritative returned Profile in
                    // SessionStore before dismissing, so no second fetch is needed.
                }
            }
        }
        .sheet(isPresented: $showRecommendationAdd) {
            if let profile {
                RecommendationEditSheet(recipientId: profile.id) { rec in
                    recommendations.insert(rec, at: 0)
                }
            }
        }
        .sheet(item: $showRecommendationEdit) { rec in
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
                        // Single string so long localized majors reflow cleanly.
                        Text([profile.major.map { OnboardingData.majorDisplay($0) },
                              OnboardingData.instrumentDisplay(inst)]
                                .compactMap { $0 }
                                .joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
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
                    Text(localized("\(session.connections.connectedCount)명과 연결됨", "Connected with \(session.connections.connectedCount)", "Verbunden mit \(session.connections.connectedCount)"))
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
        SectionCard(
            title: ProfileSection.activities.title,
            viewAllAction: { showAllActivities = true },
            viewAllLabel: localized("전체 보기", "View all", "Alle anzeigen")
        ) {
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
                            .padding(.bottom, 20)
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
                    CareerRow(
                        career: c,
                        showsDisclosure: true,
                        interactiveLinks: false,
                        onSelect: { showCareerEdit = c }
                    )
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
                    .buttonStyle(.plain)
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
            return
        }
        loading = true; defer { loading = false }
        await session.refreshProfile()
        guard session.currentUserID == me, session.profile != nil else { return }
        await session.connections.refresh(force: true)

        // Sections are independent. A newly deployed optional column or one
        // unavailable endpoint must not fail the whole profile screen.
        async let loadedActivities: [ActivityWithAuthor]? = try? session.repo.activities(byAuthor: me)
        async let loadedAffiliations: [Affiliation]? = try? session.repo.affiliations(forUser: me)
        async let loadedCareers: [Career]? = try? session.repo.careers(forUser: me)
        async let loadedLanguages: [ProfileLanguage]? = try? session.repo.languages(forUser: me)
        async let loadedOrgs: [Organization]? = try? session.repo.myOrgs(userId: me)

        if let value = await loadedActivities { activities = value }
        if let value = await loadedAffiliations { affiliations = value }
        if let value = await loadedCareers { careers = value }
        if let value = await loadedLanguages { languages = value }
        if let value = await loadedOrgs { myOrgs = value }
        await loadRecommendations()
        await loadAwards()
    }

    private func mergeAffiliation(_ affiliation: Affiliation) {
        if let index = affiliations.firstIndex(where: { $0.id == affiliation.id }) {
            affiliations[index] = affiliation
        } else {
            affiliations.append(affiliation)
        }
        affiliations.sort { ($0.enrollmentYear ?? 0) > ($1.enrollmentYear ?? 0) }
    }

    private func mergeCareer(_ career: Career) {
        if let index = careers.firstIndex(where: { $0.id == career.id }) {
            careers[index] = career
        } else {
            careers.append(career)
        }
        careers.sort { ($0.startYear ?? 0) > ($1.startYear ?? 0) }
    }

    private func mergeAward(_ award: ProfileAward) {
        if let index = awards.firstIndex(where: { $0.id == award.id }) {
            awards[index] = award
        } else {
            awards.append(award)
        }
        awards.sort { $0.year > $1.year }
        awardsLoadFailed = false
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
                    RecommendationRow(rec: rec, onEdit: { showRecommendationEdit = rec })
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
    var viewAllAction: (() -> Void)? = nil
    var viewAllLabel: String = ""
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || onAdd != nil || onEdit != nil || viewAllAction != nil {
                HStack {
                    // Text(verbatim:) is intentional — the caller provides an
                    // already-localized string via localized() or a xcstrings key
                    // resolved through the swizzled LanguageBundle.
                    if let title { Text(verbatim: title).font(.title3.weight(.semibold)) }
                    Spacer()
                    if let viewAllAction {
                        Button(action: viewAllAction) {
                            HStack(spacing: 3) {
                                Text(viewAllLabel)
                                    .font(.subheadline.weight(.medium))
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
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
    var onSelect: (() -> Void)?

    init(career: Career, showsDisclosure: Bool = false,
         interactiveLinks: Bool = true, onSelect: (() -> Void)? = nil) {
        self.career = career
        self.showsDisclosure = showsDisclosure
        self.interactiveLinks = interactiveLinks
        self.onSelect = onSelect
    }

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
        VStack(alignment: .leading, spacing: 10) {
            if let onSelect {
                Button(action: onSelect) { headerContent }
                    .buttonStyle(.plain)
            } else {
                headerContent
            }

            if let description = career.description, !description.isEmpty {
                ExpandableText(
                    text: description,
                    collapsedLineLimit: 3
                )
            }

            if let contribution = career.contribution, !contribution.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "diamond")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localized("기여", "Contribution", "Beitrag"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.primary)
                        ExpandableText(
                            text: contribution,
                            collapsedLineLimit: 3
                        )
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    private var headerContent: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(career.organization).font(.body.weight(.semibold))
                Text(career.role).font(.subheadline).foregroundStyle(.secondary)
                Text(yearRange).font(.footnote).foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
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
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(affiliation.institutionName).font(.body.weight(.semibold))
                if let ct = affiliation.courseType,
                   let opt = OnboardingData.courseOptions.first(where: { $0.id == ct }) {
                    Text(opt.label).font(.subheadline).foregroundStyle(.secondary)
                }
                if !yearRange.isEmpty {
                    Text(yearRange).font(.footnote).foregroundStyle(.tertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Recommendation row

struct RecommendationRow: View {
    let rec: Recommendation
    var onEdit: (() -> Void)? = nil
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "quote.opening")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 40, height: 40)
                        .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rec.recommenderName).font(.subheadline.weight(.semibold))
                        if let title = rec.recommenderTitle, !title.isEmpty {
                            Text(title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 6) {
                        if !rec.isVisible {
                            Image(systemName: "eye.slash").font(.caption2).foregroundStyle(.tertiary)
                        }
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(rec.body)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let onEdit {
                        Button(action: onEdit) {
                            Label(localized("편집", "Edit", "Bearbeiten"), systemImage: "pencil")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 52)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
