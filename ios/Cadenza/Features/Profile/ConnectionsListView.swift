import SwiftUI

struct ConnectionsListView: View {
    let userId: UUID

    @Environment(SessionStore.self) private var session
    @State private var connections: [ConnectedProfile] = []
    @State private var loading = false

    var body: some View {
        Group {
            if loading && connections.isEmpty {
                ProgressView()
            } else if connections.isEmpty {
                ContentUnavailableView(
                    localized("연결된 사람 없음", "No connections", "Keine Verbindungen"),
                    systemImage: "person.2",
                    description: Text(verbatim: localized("아직 연결된 음악인이 없습니다", "No connections yet", "Noch keine Verbindungen"))
                )
            } else {
                List {
                    ForEach(connections) { person in
                        NavigationLink(value: UserProfileRoute(id: person.id)) {
                            personRow(person)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(localized("연결됨", "Connected", "Verbunden"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: session.connections.revision) {
            guard userId == session.currentUserID else { return }
            await load()
        }
    }

    private func personRow(_ person: ConnectedProfile) -> some View {
        HStack(spacing: 12) {
            UserAvatarView(url: person.avatarUrl, name: person.realName, size: 44)
                .overlay(Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(person.realName).font(.subheadline.weight(.medium))
                let majorName = person.major.map { OnboardingData.majorDisplay($0) }
                let instrName = person.instrument.map { OnboardingData.instrumentDisplay($0) }
                if majorName != nil || instrName != nil {
                    HStack(spacing: 4) {
                        if let m = majorName { Text(m).font(.caption).foregroundStyle(.secondary) }
                        if majorName != nil, let i = instrName {
                            Text("·").font(.caption2).foregroundStyle(.tertiary)
                            Text(i).font(.caption).foregroundStyle(.secondary)
                        } else if let i = instrName {
                            Text(i).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func load() async {
        loading = true; defer { loading = false }
        if let result = try? await session.repo.connections(userId: userId), !Task.isCancelled {
            connections = result
        }
    }
}
