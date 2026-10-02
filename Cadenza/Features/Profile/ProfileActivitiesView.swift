import SwiftUI

struct ProfileActivitiesView: View {
    let userId: UUID
    @Environment(SessionStore.self) private var session
    @State private var activities: [ActivityWithAuthor]
    @State private var selectedType: ActivityType?
    @State private var expandedIDs: Set<UUID> = []
    @State private var loading = false
    @State private var loadFailed = false

    init(userId: UUID, initialActivities: [ActivityWithAuthor]) {
        self.userId = userId
        _activities = State(initialValue: initialActivities)
    }

    private var filteredActivities: [ActivityWithAuthor] {
        activities.filter { selectedType == nil || $0.type == selectedType }
            .sorted {
                if $0.activityDate == $1.activityDate { return $0.id.uuidString < $1.id.uuidString }
                return $0.activityDate > $1.activityDate
            }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if loadFailed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(localized("활동을 불러오지 못했습니다.", "Unable to load activities.", "Aktivitäten konnten nicht geladen werden."))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button { Task { await load() } } label: {
                            Label(localized("다시 시도", "Retry", "Erneut versuchen"), systemImage: "arrow.clockwise")
                        }
                        .disabled(loading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }

                ForEach(filteredActivities) { activity in
                    ProfileActivityHistoryRow(
                        activity: activity,
                        isExpanded: Binding(
                            get: { expandedIDs.contains(activity.id) },
                            set: { expanded in
                                if expanded { expandedIDs.insert(activity.id) }
                                else { expandedIDs.remove(activity.id) }
                            }
                        )
                    )
                    .padding(16)
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay {
            if loading && activities.isEmpty {
                ProgressView()
            } else if filteredActivities.isEmpty && !loadFailed {
                ContentUnavailableView {
                    Label(
                        selectedType.map { localized("\($0.localizedLabel) 활동이 없어요", "No \($0.localizedLabel.lowercased()) activities", "Keine Aktivitäten: \($0.localizedLabel)") }
                            ?? localized("아직 기록한 활동이 없어요", "No activities yet", "Noch keine Aktivitäten"),
                        systemImage: selectedType?.symbol ?? "music.note.list"
                    )
                }
                .accessibilityIdentifier("profile.activities.empty")
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { filterHeader }
        .navigationTitle(localized("나의 활동", "My Activities", "Meine Aktivitäten"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .cadenzaRefreshable { await load() }
    }

    private var filterHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(type: nil)
                    ForEach(ActivityType.allCases) { type in
                        filterChip(type: type)
                    }
                }
                .padding(.horizontal, 16)
            }
            HStack {
                Text(localized("총 \(filteredActivities.count)개", "\(filteredActivities.count) activities", "\(filteredActivities.count) Aktivitäten"))
                    .accessibilityIdentifier("profile.activities.count")
                Spacer()
                Text(localized("활동일 최신순", "Latest activity first", "Neueste zuerst"))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func filterChip(type: ActivityType?) -> some View {
        let isSelected = selectedType == type
        return Button { selectedType = type } label: {
            Text(type?.localizedLabel ?? localized("전체", "All", "Alle"))
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("profile.activities.filter.\(type?.rawValue ?? "all")")
    }

    private func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            activities = try await session.repo.activities(byAuthor: userId)
            expandedIDs.formIntersection(Set(activities.map(\.id)))
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }
}

private struct ProfileActivityHistoryRow: View {
    let activity: ActivityWithAuthor
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hasDetails: Bool {
        [activity.program, activity.organizer, activity.personalNote].contains { !($0?.isEmpty ?? true) }
            || !activity.imageUrls.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(activity.type.localizedLabel, systemImage: activity.type.symbol)
                    .foregroundStyle(Color.accentColor)
                Spacer(minLength: 8)
                Text(activity.activityDate.replacingOccurrences(of: "-", with: "."))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Text(activity.title)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("profile.activities.row.\(activity.type.rawValue)")
            if let role = activity.role, !role.isEmpty {
                Text(role).font(.subheadline).foregroundStyle(.secondary)
            }
            if let prize = activity.prize, !prize.isEmpty {
                Label(prize, systemImage: "trophy")
                    .font(.subheadline).foregroundStyle(Color("BrandGold"))
            }
            if let location = activity.location, !location.isEmpty {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if hasDetails {
                VStack(spacing: 0) {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text(localized("상세 내용", "Details", "Details"))
                                .font(.caption)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                .frame(width: 24, height: 24)
                        }
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(Text(isExpanded
                        ? localized("펼쳐짐", "Expanded", "Ausgeklappt")
                        : localized("접힘", "Collapsed", "Eingeklappt")))
                    .accessibilityIdentifier("profile.activities.details.\(activity.id)")

                    VStack(alignment: .leading, spacing: 12) {
                        if let program = activity.program, !program.isEmpty {
                            detail(activity.type == .recording
                                   ? localized("수록곡", "Track list", "Trackliste")
                                   : localized("레퍼토리", "Repertoire", "Repertoire"), text: program)
                        }
                        if let organizer = activity.organizer, !organizer.isEmpty {
                            detail(localized("주최", "Organizer", "Veranstalter"), text: organizer)
                        }
                        if let note = activity.personalNote, !note.isEmpty {
                            detail(localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"), text: note)
                        }
                        if !activity.imageUrls.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(activity.imageUrls.enumerated()), id: \.offset) { _, url in
                                        AsyncImage(url: URL(string: url)) { image in
                                            image.resizable().scaledToFit()
                                        } placeholder: {
                                            Image(systemName: "photo").foregroundStyle(.secondary)
                                        }
                                        .frame(width: 144, height: 108)
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .accessibilityLabel(Text(activity.title))
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    // Keep text at its natural size and reveal it vertically.
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: isExpanded ? nil : 0, alignment: .top)
                    .clipped()
                    .allowsHitTesting(isExpanded)
                    .accessibilityHidden(!isExpanded)
                }
            }
        }
    }

    private func detail(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}
