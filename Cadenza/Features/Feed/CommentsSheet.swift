import SwiftUI

struct CommentsSheet: View {
    let activity: ActivityWithAuthor

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [ActivityComment] = []
    @State private var newComment = ""
    @State private var loading = false
    @State private var posting = false
    @State private var replyingTo: ActivityComment? = nil

    private var topLevelComments: [ActivityComment] {
        comments.filter { $0.parentCommentId == nil }
    }

    private func replies(for comment: ActivityComment) -> [ActivityComment] {
        comments.filter { $0.parentCommentId == comment.id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if loading && comments.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    ContentUnavailableView("아직 댓글이 없어요", systemImage: "bubble.right",
                                          description: Text("첫 번째 댓글을 남겨보세요"))
                } else {
                    List {
                        ForEach(topLevelComments) { comment in
                            commentBlock(comment)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if comment.userId == session.currentUserID {
                                        Button(role: .destructive) {
                                            Task { await deleteComment(comment) }
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("댓글")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }.fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) { inputBar }
            .task { await loadComments() }
        }
    }

    // MARK: - Comment block (comment + its replies)

    private func commentBlock(_ comment: ActivityComment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            commentRow(comment, size: .regular)
                .padding(.vertical, 8)

            // Reply button
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    replyingTo = replyingTo?.id == comment.id ? nil : comment
                }
            } label: {
                Text(replyingTo?.id == comment.id ? "답글 취소" : "답글 달기")
                    .font(.caption2)
                    .foregroundStyle(replyingTo?.id == comment.id ? Color.accentColor : .secondary)
            }
            .padding(.leading, 36)
            .padding(.bottom, 6)

            // Nested replies
            let reps = replies(for: comment)
            if !reps.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(reps) { reply in
                        commentRow(reply, size: .small)
                            .padding(.vertical, 6)
                            .swipeActions(edge: .trailing) {
                                if reply.userId == session.currentUserID {
                                    Button(role: .destructive) {
                                        Task { await deleteComment(reply) }
                                    } label: {
                                        Label("삭제", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
                .padding(.leading, 20)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.secondary.opacity(0.18))
                        .frame(width: 1.5)
                        .padding(.leading, 14)
                        .padding(.vertical, 2)
                }
                .padding(.bottom, 4)
            }

            Divider().padding(.vertical, 2)
        }
    }

    // MARK: - Single comment/reply row

    private enum RowSize { case regular, small }

    private func commentRow(_ comment: ActivityComment, size: RowSize) -> some View {
        let avatarSize: CGFloat = size == .regular ? 30 : 24
        let nameFontWeight: Font = size == .regular ? .caption.weight(.semibold) : .caption2.weight(.semibold)
        let instFont: Font = .caption2
        let contentFont: Font = size == .regular ? .subheadline : .footnote
        let paddingLeading: CGFloat = avatarSize + 6

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                UserAvatarView(url: comment.author?.avatarUrl,
                               name: comment.author?.realName ?? "?",
                               size: avatarSize)

                VStack(alignment: .leading, spacing: 0) {
                    Text(comment.author?.realName ?? "—")
                        .font(nameFontWeight)
                    if let inst = comment.author?.instrument {
                        Text(inst).font(instFont).foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(relativeTime(comment.createdAt))
                    .font(.caption2).foregroundStyle(.tertiary)

                // Like button
                Button {
                    Task { await toggleCommentLike(comment) }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                            .font(.caption)
                            .foregroundStyle(comment.isLiked ? .red : .secondary)
                        if comment.likeCount > 0 {
                            Text("\(comment.likeCount)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Text(comment.content)
                .font(contentFont)
                .padding(.leading, paddingLeading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let r = replyingTo {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text("\(r.author?.realName ?? "—")님에게 답글")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation { replyingTo = nil }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.07))

                Divider()
            }

            HStack(spacing: 10) {
                TextField(
                    replyingTo != nil ? "답글을 남겨보세요..." : "댓글을 남겨보세요...",
                    text: $newComment,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))

                Button {
                    Task { await postComment() }
                } label: {
                    if posting {
                        ProgressView().frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                newComment.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.secondary.opacity(0.4)
                                    : Color.accentColor
                            )
                    }
                }
                .disabled(newComment.trimmingCharacters(in: .whitespaces).isEmpty || posting)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func loadComments() async {
        guard let me = session.currentUserID else { return }
        loading = true; defer { loading = false }
        comments = (try? await session.repo.comments(forActivity: activity.id, userId: me)) ?? []
    }

    private func toggleCommentLike(_ comment: ActivityComment) async {
        guard let me = session.currentUserID,
              let idx = comments.firstIndex(where: { $0.id == comment.id }) else { return }
        // Optimistic update
        let wasLiked = comments[idx].isLiked
        comments[idx].isLiked = !wasLiked
        comments[idx].likeCount += wasLiked ? -1 : 1
        do {
            if wasLiked {
                try await session.repo.unlikeComment(commentId: comment.id, userId: me)
            } else {
                try await session.repo.likeComment(commentId: comment.id, userId: me)
            }
        } catch {
            // Revert on failure
            comments[idx].isLiked = wasLiked
            comments[idx].likeCount += wasLiked ? 1 : -1
        }
    }

    private func postComment() async {
        guard let me = session.currentUserID else { return }
        let content = newComment.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }
        posting = true; defer { posting = false }
        do {
            try await session.repo.addComment(
                activityId: activity.id, userId: me,
                content: content, parentCommentId: replyingTo?.id
            )
            newComment = ""
            replyingTo = nil
            await loadComments()
        } catch {}
    }

    private func deleteComment(_ comment: ActivityComment) async {
        do {
            try await session.repo.deleteComment(id: comment.id)
            comments.removeAll { $0.id == comment.id }
            // Also remove replies to deleted comment
            comments.removeAll { $0.parentCommentId == comment.id }
        } catch {}
    }

    // MARK: - Helpers

    private func relativeTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        guard let date else { return "" }
        let diff = Int(-date.timeIntervalSinceNow)
        if diff < 60  { return "방금" }
        if diff < 3600 { return "\(diff / 60)분 전" }
        if diff < 86400 { return "\(diff / 3600)시간 전" }
        return "\(diff / 86400)일 전"
    }
}
