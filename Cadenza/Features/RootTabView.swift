import SwiftUI

struct RootTabView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = 0
    @State private var showCreate = false
    @State private var feed = FeedStore()
    @State private var activityRevision = 0
    @State private var notifBadge = 0
    @State private var scrollToTopRevision = 0

    init() {
        #if DEBUG
        let requestedTab = ProcessInfo.processInfo.environment["CADENZA_DEV_TAB"]
            ?? CommandLine.arguments.first(where: { $0.hasPrefix("--dev-tab=") })?
                .replacingOccurrences(of: "--dev-tab=", with: "")
        let initialSelection: Int
        switch requestedTab {
        case "jobs": initialSelection = 3
        case "profile": initialSelection = 4
        default: initialSelection = 0
        }
        _selection = State(initialValue: initialSelection)
        #endif
    }

    var body: some View {
        TabView(selection: Binding(
            get: { selection },
            set: { destination in
                // Recording is an action, not a navigation destination.
                if destination == 2 { showCreate = true }
                else if destination == selection { scrollToTopRevision &+= 1 }
                else { selection = destination }
            }
        )) {
            FeedView(
                feed: feed,
                unreadNotificationCount: notifBadge + session.connections.pending.count,
                onNotifications: { selection = 1 },
                onCreate: { showCreate = true },
                scrollToTop: scrollToTopRevision
            )
                .tabItem { Label("tab.feed", systemImage: "house") }
                .tag(0)

            NotificationsView(unreadBadge: $notifBadge, scrollToTop: scrollToTopRevision)
                .tabItem { Label("tab.notifications", systemImage: "bell") }
                .badge(notifBadge + session.connections.pending.count)
                .tag(1)

            Color.clear
                .tabItem { Label("tab.record", systemImage: "plus.circle.fill") }
                .tag(2)

            JobsView(scrollToTop: scrollToTopRevision)
                .tabItem { Label("tab.jobs", systemImage: "briefcase") }
                .tag(3)

            ProfileView(activityRevision: activityRevision, scrollToTop: scrollToTopRevision)
                .tabItem { Label("tab.profile", systemImage: "person.crop.circle") }
                .tag(4)
        }
        .sheet(isPresented: $showCreate) {
            CreateActivityView { created in
                feed.upsert(created)
                activityRevision &+= 1
            }
                .environment(session)
        }
        .task(id: "\(session.currentUserID?.uuidString ?? ""):\(scenePhase)") {
            guard scenePhase == .active, let me = session.currentUserID else { return }
            session.connections.reset(for: me)
            await refreshConnectionsAndBadge(me)
            await session.repo.observeConnectionChanges(userId: me) {
                await refreshConnectionsAndBadge(me, force: true)
            }
        }
        .alert("error.title", isPresented: Binding(
            get: { session.connections.errorMessage != nil },
            set: { if !$0 { session.connections.errorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) { session.connections.errorMessage = nil }
        } message: { Text(session.connections.errorMessage ?? "") }
    }

    private func refreshConnectionsAndBadge(_ me: UUID, force: Bool = false) async {
        await session.connections.refresh(force: force)
        let count = try? await session.repo.unreadNotificationCount(userId: me)
        guard session.currentUserID == me, !Task.isCancelled, let count else { return }
        notifBadge = count
    }
}
