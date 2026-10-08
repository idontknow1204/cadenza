import SwiftUI

struct PublicProfileView: View {
    let userId: UUID

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

    private var isOwnProfile: Bool { userId == session.currentUserID }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if loading && profile == nil {
                    ProgressView().padding(40)
                } else if let profile {
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
        .navigationTitle(profile?.realName ?? "프로필")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: session.connections.revision) {
            if let count = try? await session.repo.connectionCount(userId: userId) { contactCount = count }
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
            Button { Task { await disconnectUser() } } label: {
                Text("연결됨")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.primary)
            }
        }
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
        profile      = try? await p
        activities   = (try? await acts) ?? []
        affiliations = (try? await affs) ?? []
        careers      = (try? await cars) ?? []
        awards       = (try? await awardRecords) ?? []
        languages    = (try? await lang) ?? []
        contactCount = (try? await cnt)  ?? 0
        await cs
    }

    // MARK: - Connection actions

    private func sendRequest() async {
        await session.connections.perform(.request, with: userId)
    }

    private func cancelRequest() async {
        await session.connections.perform(.cancel, with: userId)
        await refreshCount()
    }

    private func acceptRequest() async {
        await session.connections.perform(.accept, with: userId)
        await refreshCount()
    }

    private func declineRequest() async {
        await session.connections.perform(.decline, with: userId)
    }

    private func disconnectUser() async {
        await session.connections.perform(.disconnect, with: userId)
        await refreshCount()
    }

    private func refreshCount() async {
        if let count = try? await session.repo.connectionCount(userId: userId) { contactCount = count }
    }
}
