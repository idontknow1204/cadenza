import SwiftUI

struct PublicProfileView: View {
    let userId: UUID
    /// 본인이 "다른 사람에게 보이는 모습"을 점검하는 미리보기 모드.
    /// 안내 배너를 띄우고, 번역 저장 여부와 무관하게 전 언어 전환을 허용한다.
    var isPreview: Bool = false

    @Environment(SessionStore.self) private var session

    @State private var profile: Profile?
    @State private var activities: [ActivityWithAuthor] = []
    @State private var affiliations: [Affiliation] = []
    @State private var careers: [Career] = []
    @State private var awards: [ProfileAward] = []
    @State private var languages: [ProfileLanguage] = []
    @State private var contactCount = 0
    private var connStatus: ConnectionStatus { session.connections.status(for: userId) }
    @State private var loading = false
    @State private var showConnections = false
    @State private var showDisconnectConfirm = false

    // 다국어: 방문자 언어로 프로필 표시. 베이스(ko) 위에 cv_i18n 오버레이를 덮어씀.
    @State private var viewerLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "ko"
    @State private var didInitLang = false
    // 오버레이 미적용 원본 — 언어 전환 시 재조회 없이 다시 덮어쓰기 위해 보관.
    @State private var rawProfile: Profile?
    @State private var rawActivities: [ActivityWithAuthor] = []
    @State private var rawAffiliations: [Affiliation] = []
    @State private var rawCareers: [Career] = []
    @State private var rawAwards: [ProfileAward] = []

    private var isOwnProfile: Bool { userId == session.currentUserID }

    /// 전환 칩에 노출할 언어 목록.
    /// 실제 방문자: ko 베이스 + 작성자가 제공한 오버레이 언어 (1개뿐이면 칩 숨김).
    /// 미리보기: 번역 저장 여부와 무관하게 앱 지원 전 언어를 보여줘, 각 언어로
    /// 외국인에게 어떻게 보일지(폴백 포함) 점검할 수 있게 한다.
    private var availableLangs: [String] {
        isPreview ? ["ko", "en", "de"] : ["ko"] + (profile?.profileLangs ?? [])
    }
    private func langLabel(_ code: String) -> String {
        switch code {
        case "ko": return "한국어"
        case "en": return "English"
        case "de": return "Deutsch"
        default:   return code.uppercased()
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if loading && profile == nil {
                    ProgressView().padding(40)
                } else if let profile {
                    if isPreview {
                        previewBanner
                    }
                    headerCard(profile)
                    if profile.showsSection(.bio), let bio = profile.bio, !bio.isEmpty {
                        bioCard(bio)
                    }
                    if profile.showsSection(.education), !affiliations.isEmpty {
                        educationCard
                    }
                    if profile.showsSection(.activities), !activities.isEmpty {
                        activitySection
                    }
                    if profile.showsSection(.career), !careers.isEmpty {
                        careerCard
                    }
                    if profile.showsSection(.awards), !awards.isEmpty {
                        awardsCard
                    }
                    if profile.showsSection(.languages), !languages.isEmpty {
                        languageCard
                    }
                }
            }
            .padding(.vertical, 12)
            .adaptiveContentWidth()
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle(isPreview
                         ? localized("미리보기", "Preview", "Vorschau")
                         : (profile?.realName ?? "프로필"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isPreview || availableLangs.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(availableLangs, id: \.self) { code in
                            Button {
                                guard code != viewerLang else { return }
                                viewerLang = code
                                Task { await applyLanguage() }
                            } label: {
                                if code == viewerLang {
                                    Label(langLabel(code), systemImage: "checkmark")
                                } else {
                                    Text(langLabel(code))
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(localized("언어 선택", "Choose language", "Sprache wählen"))
                }
            }
        }
        .task { await load() }
        .task(id: session.connections.revision) {
            await refreshCount()
        }
        .navigationDestination(isPresented: $showConnections) {
            ConnectionsListView(userId: userId)
        }
    }

    // MARK: - Header card

    private func headerCard(_ profile: Profile) -> some View {
        SectionCard {
            HStack(alignment: .top, spacing: 14) {
                UserAvatarView(url: profile.avatarUrl, name: profile.realName, size: 68)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.realName).font(.title2.bold())
                    if let inst = profile.instrument, !inst.isEmpty {
                        // One concatenated string so long localized majors
                        // (e.g. "Instrumentalmusik") reflow cleanly instead of
                        // each Text wrapping in its own narrow column.
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
                if !isOwnProfile {
                    connectionButton
                        .disabled(session.connections.updating.contains(userId) || !session.connections.hasLoaded)
                }
            }

            Button { showConnections = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(contactCount)명과 연결됨")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .buttonStyle(.plain)

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
    private var connectionButton: some View {
        switch connStatus {
        case .none:
            Button { Task { await sendRequest() } } label: {
                Text("연결")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
        case .requestSent:
            Button { Task { await cancelRequest() } } label: {
                Text("요청 보냄")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }
        case .requestReceived:
            HStack(spacing: 8) {
                Button { Task { await acceptRequest() } } label: {
                    Text("수락")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                }
                Button { Task { await declineRequest() } } label: {
                    Text("거절")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                        .foregroundStyle(.primary)
                }
            }
        case .connected:
            Button { showDisconnectConfirm = true } label: {
                Text("연결됨")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.primary)
            }
            .confirmationDialog(
                localized("연결을 끊으시겠어요?", "Disconnect?", "Verbindung trennen?"),
                isPresented: $showDisconnectConfirm,
                titleVisibility: .visible
            ) {
                Button(localized("연결 해제", "Disconnect", "Trennen"), role: .destructive) {
                    Task { await disconnectUser() }
                }
            }
        }
    }

    // MARK: - Preview banner

    private var previewBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "eye")
                .font(.subheadline).foregroundStyle(Color.accentColor)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(localized("미리보기", "Preview", "Vorschau"))
                    .font(.subheadline.weight(.semibold))
                Text(localized("다른 사람에게 이렇게 보입니다. 우측 상단에서 언어를 전환해 각 언어 버전을 확인하세요.",
                               "This is how others see your profile. Switch languages from the top-right to check each version.",
                               "So sehen andere Ihr Profil. Wechseln Sie oben rechts die Sprache, um jede Version zu prüfen."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Bio card

    private func bioCard(_ bio: String) -> some View {
        SectionCard(title: ProfileSection.bio.title) {
            Text(bio).font(.subheadline).lineSpacing(3)
        }
    }

    // MARK: - Activity section

    private var activitySection: some View {
        SectionCard(title: ProfileSection.activities.title) {
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

    // MARK: - Career card

    private var careerCard: some View {
        SectionCard(title: ProfileSection.career.title) {
            ForEach(careers) { c in
                CareerRow(career: c)
                if c.id != careers.last?.id { Divider() }
            }
        }
    }

    // MARK: - Education card

    private var educationCard: some View {
        SectionCard(title: ProfileSection.education.title) {
            ForEach(affiliations) { aff in
                AffiliationRow(affiliation: aff)
                if aff.id != affiliations.last?.id { Divider() }
            }
        }
    }

    private var awardsCard: some View {
        SectionCard(title: ProfileSection.awards.title) {
            ForEach(awards) { award in
                ProfileAwardRow(award: award)
                if award.id != awards.last?.id { Divider() }
            }
        }
    }

    // MARK: - Language card

    private var languageCard: some View {
        SectionCard(title: ProfileSection.languages.title) {
            FlowLayout(spacing: 8) {
                ForEach(languages) { lang in
                    LanguageChip(lang: lang)
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Load

    private func load() async {
        guard session.currentUserID != nil else { return }
        loading = true; defer { loading = false }
        async let p    = session.repo.profile(id: userId)
        async let acts = session.repo.activities(byAuthor: userId)
        async let affs = session.repo.affiliations(forUser: userId)
        async let cars = session.repo.careers(forUser: userId)
        async let awardRecords = session.repo.awards(forUser: userId)
        async let lang = session.repo.languages(forUser: userId)
        async let cnt  = session.repo.connectionCount(userId: userId)
        async let cs: Void = session.connections.refresh()
        rawProfile      = try? await p
        rawActivities   = (try? await acts) ?? []
        rawAffiliations = (try? await affs) ?? []
        rawCareers      = (try? await cars) ?? []
        rawAwards       = (try? await awardRecords) ?? []
        languages       = (try? await lang) ?? []
        if let count = try? await cnt { contactCount = count }
        await cs

        // 최초 1회: 방문자 앱 언어가 작성자 제공 언어에 있으면 그 언어로, 없으면 ko.
        if !didInitLang {
            let offered = ["ko"] + (rawProfile?.profileLangs ?? [])
            viewerLang = offered.contains(viewerLang) ? viewerLang : "ko"
            didInitLang = true
        }
        await applyLanguage()
    }

    /// viewerLang 에 맞춰 원본에 오버레이를 덮어써 표시용 상태를 갱신.
    private func applyLanguage() async {
        // 원본에서 시작 (ko 베이스)
        profile      = rawProfile
        activities   = rawActivities
        affiliations = rawAffiliations
        careers      = rawCareers
        awards       = rawAwards

        guard viewerLang != "ko", let uid = rawProfile?.id else { return }
        let overlays = (try? await session.repo.profileOverlays(userId: uid, lang: viewerLang)) ?? [:]
        guard !overlays.isEmpty else { return }

        // profile-level (이름/소개/악기)
        if let patch = overlays["profile:\(uid.uuidString)"] {
            if let v = patch["name"], !v.isEmpty { profile?.realName = v }
            if let v = patch["instrument"], !v.isEmpty { profile?.instrument = v }
            if let v = patch["bio"], !v.isEmpty { profile?.bio = v }
        }
        activities   = rawActivities.map   { applyActivity($0, overlays: overlays) }
        affiliations = rawAffiliations.map { applyAffiliation($0, overlays: overlays) }
        careers      = rawCareers.map      { applyCareer($0, overlays: overlays) }
        awards       = rawAwards.map       { applyAward($0, overlays: overlays) }
    }

    private func applyActivity(_ a: ActivityWithAuthor,
                               overlays: [String: [String: String]]) -> ActivityWithAuthor {
        guard let patch = overlays["activity:\(a.id.uuidString)"], !patch.isEmpty else { return a }
        func v(_ k: String) -> String? { patch[k].flatMap { $0.isEmpty ? nil : $0 } }
        var title = a.title, location = a.location, role = a.role, organizer = a.organizer, prize = a.prize
        switch a.type {
        case .performance:
            if let x = v("title") { title = x }
            if let x = v("org")   { organizer = x }
            if let x = v("place") { location = x }
            if let x = v("detail") { role = x }
        case .competition:
            if let x = v("title")  { title = x }
            if let x = v("place")  { location = x }
            if let x = v("result") { prize = x }
        case .education:
            if let x = v("institution") { title = x }
            if let x = v("place")       { location = x }
            if let x = v("teacher")     { role = x }
        case .recording:
            break
        }
        return ActivityWithAuthor(
            id: a.id, userId: a.userId, type: a.type, title: title,
            activityDate: a.activityDate, location: location, role: role, program: a.program,
            prize: prize, organizer: organizer, personalNote: a.personalNote, imageUrls: a.imageUrls,
            verification: a.verification, createdAt: a.createdAt, author: a.author, org: a.org,
            feedReason: a.feedReason, linkUrl: a.linkUrl, linkTitle: a.linkTitle,
            linkDescription: a.linkDescription, linkImageUrl: a.linkImageUrl, linkSiteName: a.linkSiteName)
    }

    private func applyAffiliation(_ a: Affiliation,
                                  overlays: [String: [String: String]]) -> Affiliation {
        var a = a
        if let patch = overlays["affiliation:\(a.id.uuidString)"],
           let v = patch["institution"], !v.isEmpty { a.institutionName = v }
        return a
    }

    private func applyCareer(_ c: Career, overlays: [String: [String: String]]) -> Career {
        var c = c
        if let patch = overlays["career:\(c.id.uuidString)"] {
            if let v = patch["organization"], !v.isEmpty { c.organization = v }
            if let v = patch["role"], !v.isEmpty { c.role = v }
            if let v = patch["description"], !v.isEmpty { c.description = v }
            if let v = patch["contribution"], !v.isEmpty { c.contribution = v }
        }
        return c
    }

    private func applyAward(_ aw: ProfileAward, overlays: [String: [String: String]]) -> ProfileAward {
        var aw = aw
        if let patch = overlays["award:\(aw.id.uuidString)"] {
            if let v = patch["title"], !v.isEmpty { aw.title = v }
            if let v = patch["prize"], !v.isEmpty { aw.prize = v }
            if let v = patch["issuer"], !v.isEmpty { aw.issuer = v }
            if let v = patch["details"], !v.isEmpty { aw.details = v }
        }
        return aw
    }

    // MARK: - Connection actions

    private func sendRequest() async {
        await session.connections.perform(.request, with: userId)
    }

    private func cancelRequest() async {
        await session.connections.perform(.cancel, with: userId)
    }

    private func acceptRequest() async {
        await session.connections.perform(.accept, with: userId)
    }

    private func declineRequest() async {
        await session.connections.perform(.decline, with: userId)
    }

    private func disconnectUser() async {
        await session.connections.perform(.disconnect, with: userId)
    }

    private func refreshCount() async {
        if let count = try? await session.repo.connectionCount(userId: userId) { contactCount = count }
    }
}
