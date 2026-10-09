import SwiftUI

struct ConfirmInboxView: View {
    @Environment(SessionStore.self) private var session

    @State private var pending: [ActivityWithAuthor] = []
    @State private var accepted: [ActivityWithAuthor] = []
    @State private var loading = false
    @State private var acting: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                if pending.isEmpty && accepted.isEmpty && !loading {
                    ContentUnavailableView(
                        "태그된 게시물이 없어요",
                        systemImage: "at",
                        description: Text("다른 사람이 회원님을 태그하면 여기에 표시됩니다")
                    )
                }

                if !pending.isEmpty {
                    Section {
                        ForEach(pending) { item in
                            TagPendingRow(
                                item: item,
                                isActing: acting.contains(item.id),
                                onAccept: { Task { await accept(item) } },
                                onDecline: { Task { await decline(item) } }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("수락 대기 중")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }

                if !accepted.isEmpty {
                    Section {
                        ForEach(accepted) { item in
                            TaggedActivityRow(item: item)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("내 프로필에 공유됨")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("태그")
            .overlay { if loading && pending.isEmpty && accepted.isEmpty { ProgressView() } }
            .cadenzaRefreshable { await load() }
            .task { await load() }
        }
    }

    // MARK: - Actions

    private func accept(_ item: ActivityWithAuthor) async {
        guard let me = session.currentUserID else { return }
        acting.insert(item.id)
        defer { acting.remove(item.id) }
        try? await session.repo.acceptTag(activityId: item.id, userId: me)
        withAnimation {
            pending.removeAll { $0.id == item.id }
            if !accepted.contains(where: { $0.id == item.id }) {
                accepted.insert(item, at: 0)
            }
        }
    }

    private func decline(_ item: ActivityWithAuthor) async {
        guard let me = session.currentUserID else { return }
        acting.insert(item.id)
        defer { acting.remove(item.id) }
        try? await session.repo.declineTag(activityId: item.id, userId: me)
        withAnimation { pending.removeAll { $0.id == item.id } }
    }

    // MARK: - Load

    private func load() async {
        guard let me = session.currentUserID else { return }
        loading = true; defer { loading = false }
        async let p = session.repo.pendingTags(userId: me)
        async let a = session.repo.taggedActivities(userId: me)
        pending  = (try? await p) ?? []
        accepted = (try? await a) ?? []
    }
}

// MARK: - Pending tag row (수락 / 거절 버튼 포함)

struct TagPendingRow: View {
    let item: ActivityWithAuthor
    let isActing: Bool
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "at")
                    .font(.caption2).foregroundStyle(Color.accentColor)
                Text("\(item.author?.realName ?? "—")님이 회원님을 태그했습니다")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    ActivityTypeLabel(type: item.type)
                    Text(item.activityDate.replacingOccurrences(of: "-", with: "."))
                        .font(.caption).foregroundStyle(.secondary)
                    if let loc = item.location, !loc.isEmpty {
                        Text("·").font(.caption2).foregroundStyle(.tertiary)
                        Text(loc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)

            // Accept / Decline buttons
            HStack(spacing: 10) {
                Button(action: onAccept) {
                    if isActing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("수락하고 공유")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isActing)

                Button(action: onDecline) {
                    Text("거절")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(.secondary)
                .disabled(isActing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 12)

            Divider()
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Accepted tag row

struct TaggedActivityRow: View {
    let item: ActivityWithAuthor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2).foregroundStyle(.green)
                Text("\(item.author?.realName ?? "—")님의 게시물에 태그됨")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    ActivityTypeLabel(type: item.type)
                    Text(item.activityDate.replacingOccurrences(of: "-", with: "."))
                        .font(.caption).foregroundStyle(.secondary)
                    if let loc = item.location, !loc.isEmpty {
                        Text("·").font(.caption2).foregroundStyle(.tertiary)
                        Text(loc).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()
        }
        .background(Color(.systemBackground))
    }
}
