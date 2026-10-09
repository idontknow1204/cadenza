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
        .task(id: session.connections.revision) { await load() }
    }

    private func personRow(_ person: ConnectedProfile) -> some View {
        HStack(spacing: 12) {
            Group {
                if let urlStr = person.avatarUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase { img.resizable().scaledToFill() }
                        else { placeholder }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(person.realName).font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    if let major = person.major {
                        Text(major).font(.caption).foregroundStyle(.secondary)
                    }
                    if person.major != nil, let inst = person.instrument {
                        Text("·").font(.caption2).foregroundStyle(.tertiary)
                        Text(inst).font(.caption).foregroundStyle(.secondary)
                    } else if let inst = person.instrument {
                        Text(inst).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var placeholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .foregroundStyle(.secondary.opacity(0.35))
    }

    private func load() async {
        loading = true; defer { loading = false }
        if let result = try? await session.repo.connections(userId: userId), !Task.isCancelled {
            connections = result
        }
    }
}
