import SwiftUI

struct Step4TeacherView: View {
    var coordinator: OnboardingCoordinator
    @Environment(SessionStore.self) private var session

    @State private var searchQuery = ""
    @State private var results: [ProfileLite] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    searchSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            Spacer(minLength: 0)
            OnboardingBottomBar(
                primaryLabel: "onboarding.next",
                primaryAction: {
                    Task { await coordinator.saveStep4(repo: session.repo, userID: session.currentUserID!) }
                },
                primaryDisabled: false,
                skipLabel: "onboarding.skip",
                skipAction: { coordinator.advance() },
                isBusy: coordinator.isBusy
            )
        }
        .onAppear { searchQuery = coordinator.teacherName }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("onboarding.step4.title").font(.largeTitle.bold())
            Text("onboarding.step4.desc").foregroundStyle(.secondary)
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("onboarding.teacher.name").font(.headline)
            TextField("onboarding.teacher.hint", text: $searchQuery)
                .textFieldStyle(.roundedBorder)
                .onChange(of: searchQuery) { _, v in
                    coordinator.teacherName = v
                    coordinator.teacherID = nil
                    Task { await search(v) }
                }

            if !results.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(results) { person in
                        Button {
                            let name = person.realName
                            let pid = person.id
                            coordinator.teacherName = name
                            coordinator.teacherID = pid
                            searchQuery = name
                            results = []
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(person.realName).font(.subheadline.weight(.medium))
                                    if let inst = person.instrument {
                                        Text(inst).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        }
                        .foregroundStyle(.primary)
                        Divider()
                    }
                }
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(radius: 4, y: 2)
            }

            if coordinator.teacherID != nil {
                Label("onboarding.teacher.matched", systemImage: "checkmark.seal.fill")
                    .font(.caption).foregroundStyle(.green)
            } else if !coordinator.teacherName.isEmpty {
                Text("onboarding.teacher.unmatched")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func search(_ query: String) async {
        guard query.count >= 2, let me = session.currentUserID else {
            results = []; return
        }
        results = (try? await session.repo.searchProfiles(query: query, excluding: me)) ?? []
    }
}
