import SwiftUI

struct OrgRoute: Hashable { let id: UUID }

struct OrgPageView: View {
    let orgId: UUID

    @Environment(SessionStore.self) private var session
    @State private var org: Organization?
    @State private var activities: [ActivityWithAuthor] = []
    @State private var followerCount = 0
    @State private var isFollowing = false
    @State private var isAdmin = false
    @State private var loading = true
    @State private var followBusy = false

    var body: some View {
        ScrollView {
            if let org {
                LazyVStack(spacing: 0) {
                    orgHeader(org)
                        .padding(.bottom, 12)

                    Divider()

                    if activities.isEmpty && !loading {
                        ContentUnavailableView("아직 게시물이 없습니다", systemImage: "tray")
                            .padding(.top, 40)
                    } else {
                        ForEach(Array(activities.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 { PostSeparator() }
                            ActivityCard(item: item)
                                .listRowInsets(EdgeInsets())
                        }
                    }
                }
                .adaptiveContentWidth()
            } else if loading {
                ProgressView().padding(60)
            }
        }
        .navigationTitle(org?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.secondarySystemBackground))
        .task { await load() }
    }

    // MARK: - Header

    private func orgHeader(_ org: Organization) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                OrgAvatar(category: org.category, size: 64)

                VStack(alignment: .leading, spacing: 4) {
                    Text(org.name)
                        .font(.title3.weight(.bold))
                    Text(org.category.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let website = org.website, !website.isEmpty {
                        Text(website)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Spacer()
            }

            if let desc = org.description, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label("\(followerCount)명 팔로워", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await toggleFollow() }
                } label: {
                    Text(isFollowing ? "팔로잉" : "팔로우")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(
                            isFollowing
                                ? Color.secondary.opacity(0.12)
                                : Color.accentColor,
                            in: Capsule()
                        )
                        .foregroundStyle(isFollowing ? Color.primary : .white)
                }
                .disabled(followBusy)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func load() async {
        loading = true
        defer { loading = false }
        guard let me = session.currentUserID else { return }
        async let orgTask      = session.repo.fetchOrg(id: orgId)
        async let actsTask     = session.repo.orgActivities(orgId: orgId)
        async let countTask    = session.repo.orgFollowerCount(orgId: orgId)
        async let followTask   = session.repo.isFollowingOrg(orgId: orgId, userId: me)
        async let adminTask    = session.repo.myOrgs(userId: me)

        org            = try? await orgTask
        activities     = (try? await actsTask) ?? []
        followerCount  = (try? await countTask) ?? 0
        isFollowing    = (try? await followTask) ?? false
        let myOrgs     = (try? await adminTask) ?? []
        isAdmin        = myOrgs.contains(where: { $0.id == orgId })
    }

    private func toggleFollow() async {
        guard let me = session.currentUserID else { return }
        followBusy = true
        defer { followBusy = false }
        do {
            if isFollowing {
                try await session.repo.unfollowOrg(orgId: orgId, userId: me)
                isFollowing = false
                followerCount -= 1
            } else {
                try await session.repo.followOrg(orgId: orgId, userId: me)
                isFollowing = true
                followerCount += 1
            }
        } catch {}
    }
}

// MARK: - Org avatar

struct OrgAvatar: View {
    let category: OrgCategory
    var size: CGFloat = 42

    private var color: Color {
        switch category {
        case .orchestra: return .purple
        case .school:    return .blue
        case .label:     return .orange
        case .venue:     return .green
        case .agency:    return .pink
        case .other:     return .gray
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(color.opacity(0.15))
            Image(systemName: category.symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}
