package com.cadenza.android.ui.feed.components

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.isImeVisible
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Reply
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.ActivityComment
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.common.CadenzaLoadingView
import com.cadenza.android.ui.common.UserAvatarView
import com.cadenza.android.ui.theme.CadenzaAccent
import kotlinx.coroutines.launch
import java.time.OffsetDateTime

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun CommentsSheet(
    activity: ActivityWithAuthor,
    currentUserId: String?,
    repository: Repository,
    onDismiss: () -> Unit,
    onStatsChanged: () -> Unit = {},
) {
    val scope = rememberCoroutineScope()
    val comments = remember { mutableStateListOf<ActivityComment>() }
    var isLoading by remember { mutableStateOf(false) }
    var newComment by remember { mutableStateOf("") }
    var isPosting by remember { mutableStateOf(false) }
    var replyingTo by remember { mutableStateOf<ActivityComment?>(null) }

    fun topLevel() = comments.filter { it.parentCommentId == null }
    fun replies(id: String) = comments.filter { it.parentCommentId == id }

    suspend fun loadComments() {
        if (currentUserId == null) return
        isLoading = true
        try {
            val loaded = repository.comments(activity.id, currentUserId)
            comments.clear()
            comments.addAll(loaded)
        } catch (_: Throwable) {
        } finally {
            isLoading = false
        }
    }

    LaunchedEffect(activity.id) { loadComments() }

    // 화면 절반 높이로 열고, 키보드가 올라오면 위로 늘어난다.
    // (M3 반쯤-열림 상태는 안의 입력창이 화면 밖에 걸리므로, 시트 높이를 내용 높이로 직접 정한다)
    val screenHeight = LocalConfiguration.current.screenHeightDp.dp
    val imeVisible = WindowInsets.isImeVisible
    val sheetHeight by animateDpAsState(
        targetValue = if (imeVisible) screenHeight * 0.92f else screenHeight * 0.5f,
        label = "commentsSheetHeight",
    )

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        // 하단 인셋(내비게이션 바·키보드)은 입력창에서 직접 처리한다
        contentWindowInsets = { WindowInsets(0.dp, 0.dp, 0.dp, 0.dp) },
    ) {
        Column(modifier = Modifier.fillMaxWidth().height(sheetHeight)) {
            // iOS: inline 제목 + 오른쪽 "완료"
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
                    .padding(horizontal = 8.dp),
            ) {
                Text(
                    text = AppLocale.localized("댓글", "Comments", "Kommentare"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.align(Alignment.Center),
                )
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.align(Alignment.CenterEnd),
                ) {
                    Text(
                        AppLocale.localized("완료", "Done", "Fertig"),
                        style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                        color = CadenzaAccent,
                    )
                }
            }
            HorizontalDivider()

            if (isLoading && comments.isEmpty()) {
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    CadenzaLoadingView(size = 28.dp)
                }
            } else if (comments.isEmpty()) {
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.padding(horizontal = 32.dp),
                    ) {
                        Icon(
                            Icons.Outlined.ChatBubbleOutline, contentDescription = null,
                            modifier = Modifier.size(44.dp),
                            tint = MaterialTheme.colorScheme.outlineVariant,
                        )
                        Text(
                            AppLocale.localized("아직 댓글이 없어요", "No comments yet", "Noch keine Kommentare"),
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Text(
                            AppLocale.localized("첫 번째 댓글을 남겨보세요", "Be the first to comment", "Schreibe den ersten Kommentar"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
            } else {
                LazyColumn(modifier = Modifier.weight(1f)) {
                    items(topLevel(), key = { it.id }) { comment ->
                        CommentBlock(
                            comment = comment,
                            replies = replies(comment.id),
                            currentUserId = currentUserId,
                            replyingToId = replyingTo?.id,
                            onReplyToggle = {
                                replyingTo = if (replyingTo?.id == comment.id) null else comment
                            },
                            onLikeToggle = { c ->
                                scope.launch {
                                    val idx = comments.indexOfFirst { it.id == c.id }
                                    if (idx < 0 || currentUserId == null) return@launch
                                    val wasLiked = comments[idx].isLiked
                                    comments[idx] = comments[idx].copy(
                                        isLiked = !wasLiked,
                                        likeCount = comments[idx].likeCount + (if (wasLiked) -1 else 1),
                                    )
                                    try {
                                        if (wasLiked) repository.unlikeComment(c.id, currentUserId)
                                        else repository.likeComment(c.id, currentUserId)
                                    } catch (_: Throwable) {
                                        comments[idx] = comments[idx].copy(
                                            isLiked = wasLiked,
                                            likeCount = comments[idx].likeCount + (if (wasLiked) 1 else -1),
                                        )
                                    }
                                }
                            },
                            onDelete = { c ->
                                scope.launch {
                                    try {
                                        repository.deleteComment(c.id)
                                        comments.removeAll { it.id == c.id || it.parentCommentId == c.id }
                                        onStatsChanged()
                                    } catch (_: Throwable) {}
                                }
                            },
                        )
                    }
                }
            }

            // 입력 영역: 내비게이션 바 + 키보드 인셋을 여기서만 처리
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
                    .navigationBarsPadding()
                    .imePadding(),
            ) {
                HorizontalDivider()

                // Reply indicator (iOS: 옅은 배경 줄)
                replyingTo?.let { target ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.07f))
                            .padding(horizontal = 16.dp, vertical = 7.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        Icon(
                            Icons.AutoMirrored.Outlined.Reply,
                            contentDescription = null,
                            modifier = Modifier.size(14.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        val name = target.author?.realName ?: "—"
                        Text(
                            text = AppLocale.localized("${name}님에게 답글", "Replying to $name", "Antwort an $name"),
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f),
                            maxLines = 1,
                        )
                        Icon(
                            Icons.Outlined.Close,
                            contentDescription = AppLocale.localized("취소", "Cancel", "Abbrechen"),
                            modifier = Modifier
                                .size(28.dp)
                                .clickable(role = Role.Button) { replyingTo = null }
                                .padding(7.dp),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    HorizontalDivider()
                }

                val canSend = newComment.isNotBlank() && !isPosting
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    // iOS: secondary 10% 배경의 둥근 입력창 (padding 12/8, radius 20)
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .background(MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f), RoundedCornerShape(20.dp))
                            .padding(horizontal = 14.dp, vertical = 9.dp),
                        contentAlignment = Alignment.CenterStart,
                    ) {
                        if (newComment.isEmpty()) {
                            Text(
                                text = if (replyingTo != null)
                                    AppLocale.localized("답글을 남겨보세요...", "Write a reply...", "Antwort schreiben...")
                                else
                                    AppLocale.localized("댓글을 남겨보세요...", "Write a comment...", "Kommentar schreiben..."),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                        BasicTextField(
                            value = newComment,
                            onValueChange = { newComment = it },
                            modifier = Modifier.fillMaxWidth(),
                            maxLines = 4,
                            textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.colorScheme.onSurface),
                            cursorBrush = SolidColor(CadenzaAccent),
                        )
                    }

                    // iOS: 32pt 원형 위쪽 화살표, 비활성은 회색 40%
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .background(
                                if (canSend) CadenzaAccent else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.18f),
                                CircleShape,
                            )
                            .clickable(
                                enabled = canSend,
                                role = Role.Button,
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) {
                                val content = newComment.trim()
                                if (content.isEmpty() || currentUserId == null) return@clickable
                                scope.launch {
                                    isPosting = true
                                    try {
                                        repository.addComment(
                                            activityId = activity.id,
                                            userId = currentUserId,
                                            content = content,
                                            parentCommentId = replyingTo?.id,
                                        )
                                        newComment = ""
                                        replyingTo = null
                                        loadComments()
                                        onStatsChanged()
                                    } catch (_: Throwable) {
                                    } finally {
                                        isPosting = false
                                    }
                                }
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        if (isPosting) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.onPrimary,
                            )
                        } else {
                            Icon(
                                Icons.Filled.ArrowUpward,
                                contentDescription = AppLocale.localized("전송", "Send", "Senden"),
                                modifier = Modifier.size(20.dp),
                                tint = MaterialTheme.colorScheme.onPrimary,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CommentBlock(
    comment: ActivityComment,
    replies: List<ActivityComment>,
    currentUserId: String?,
    replyingToId: String?,
    onReplyToggle: () -> Unit,
    onLikeToggle: (ActivityComment) -> Unit,
    onDelete: (ActivityComment) -> Unit,
) {
    Column(modifier = Modifier.padding(horizontal = 16.dp)) {
        CommentRow(
            comment = comment,
            currentUserId = currentUserId,
            size = CommentSize.REGULAR,
            onLikeToggle = { onLikeToggle(comment) },
            onDelete = { onDelete(comment) },
        )
        val isReplying = replyingToId == comment.id
        Text(
            text = if (isReplying)
                AppLocale.localized("답글 취소", "Cancel reply", "Antwort abbrechen")
            else
                AppLocale.localized("답글 달기", "Reply", "Antworten"),
            style = MaterialTheme.typography.labelMedium,
            color = if (isReplying) CadenzaAccent else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .padding(start = 36.dp)
                .clickable(role = Role.Button, onClick = onReplyToggle)
                .padding(vertical = 6.dp),
        )
        if (replies.isNotEmpty()) {
            // iOS: 왼쪽 옅은 세로선으로 답글 묶음 표시
            Row(modifier = Modifier.padding(start = 20.dp, bottom = 4.dp).height(IntrinsicSize.Min)) {
                Box(
                    modifier = Modifier
                        .padding(start = 14.dp, top = 2.dp, bottom = 2.dp)
                        .width(1.5.dp)
                        .fillMaxHeight()
                        .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.18f), RoundedCornerShape(1.dp)),
                )
                Column(modifier = Modifier.weight(1f).padding(start = 8.dp)) {
                    replies.forEach { reply ->
                        CommentRow(
                            comment = reply,
                            currentUserId = currentUserId,
                            size = CommentSize.SMALL,
                            onLikeToggle = { onLikeToggle(reply) },
                            onDelete = { onDelete(reply) },
                        )
                    }
                }
            }
        }
        HorizontalDivider(modifier = Modifier.padding(vertical = 2.dp))
    }
}

private enum class CommentSize { REGULAR, SMALL }

@Composable
private fun CommentRow(
    comment: ActivityComment,
    currentUserId: String?,
    size: CommentSize,
    onLikeToggle: () -> Unit,
    onDelete: () -> Unit,
) {
    val avatarSize = if (size == CommentSize.REGULAR) 30.dp else 24.dp
    val nameStyle = if (size == CommentSize.REGULAR)
        MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold)
    else
        MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold)
    val bodyStyle = if (size == CommentSize.REGULAR)
        MaterialTheme.typography.bodyMedium
    else
        MaterialTheme.typography.bodySmall

    Column(
        modifier = Modifier.padding(vertical = if (size == CommentSize.REGULAR) 8.dp else 6.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            UserAvatarView(
                url = comment.author?.avatarUrl,
                name = comment.author?.realName ?: "?",
                size = avatarSize,
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(comment.author?.realName ?: "—", style = nameStyle, maxLines = 1)
                comment.author?.instrument?.let {
                    Text(it, style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                }
            }
            Text(
                text = relativeTime(comment.createdAt),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
            )
            Row(
                modifier = Modifier
                    .clickable(role = Role.Button, onClick = onLikeToggle)
                    .padding(horizontal = 4.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Icon(
                    imageVector = if (comment.isLiked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = AppLocale.localized("좋아요", "Like", "Gefällt mir"),
                    modifier = Modifier.size(16.dp),
                    tint = if (comment.isLiked) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (comment.likeCount > 0) {
                    Text(
                        "${comment.likeCount}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            if (comment.userId == currentUserId) {
                Text(
                    text = AppLocale.localized("삭제", "Delete", "Löschen"),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier
                        .clickable(role = Role.Button, onClick = onDelete)
                        .padding(horizontal = 4.dp, vertical = 6.dp),
                )
            }
        }
        Text(
            text = comment.content,
            style = bodyStyle,
            modifier = Modifier.padding(start = avatarSize + 6.dp),
        )
    }
}

private fun relativeTime(isoString: String): String {
    return try {
        // Postgres는 "+00:00" 오프셋으로 내려주므로 Instant.parse(Z 전용) 대신 OffsetDateTime 사용
        val instant = OffsetDateTime.parse(isoString).toInstant()
        val diff = (System.currentTimeMillis() - instant.toEpochMilli()) / 1000L
        when {
            diff < 60    -> AppLocale.localized("방금", "Just now", "Gerade eben")
            diff < 3600  -> (diff / 60).let { AppLocale.localized("${it}분 전", "${it}m ago", "vor $it Min.") }
            diff < 86400 -> (diff / 3600).let { AppLocale.localized("${it}시간 전", "${it}h ago", "vor $it Std.") }
            else         -> (diff / 86400).let { AppLocale.localized("${it}일 전", "${it}d ago", "vor $it T.") }
        }
    } catch (_: Exception) { "" }
}
