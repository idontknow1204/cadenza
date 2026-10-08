package com.cadenza.android.ui.feed.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.ActivityComment
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.ui.common.UserAvatarView
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.format.DateTimeParseException

@OptIn(ExperimentalMaterial3Api::class)
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

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false),
        modifier = Modifier.imePadding(),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Title row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "댓글",
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Outlined.Close, contentDescription = "닫기")
                }
            }
            HorizontalDivider()

            if (isLoading && comments.isEmpty()) {
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    androidx.compose.material3.CircularProgressIndicator()
                }
            } else if (comments.isEmpty()) {
                Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("아직 댓글이 없어요", style = MaterialTheme.typography.bodyLarge)
                        Text(
                            "첫 번째 댓글을 남겨보세요",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
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

            // Reply indicator
            if (replyingTo != null) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        Icons.Outlined.ArrowBack,
                        contentDescription = null,
                        modifier = Modifier.padding(end = 6.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = "${replyingTo?.author?.realName ?: "—"}님에게 답글",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = { replyingTo = null }) {
                        Icon(Icons.Outlined.Close, contentDescription = "취소", modifier = Modifier.padding(4.dp))
                    }
                }
                HorizontalDivider()
            }

            // Input bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.Bottom,
            ) {
                OutlinedTextField(
                    value = newComment,
                    onValueChange = { newComment = it },
                    placeholder = { Text(if (replyingTo != null) "답글을 남겨보세요..." else "댓글을 남겨보세요...") },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(20.dp),
                    maxLines = 4,
                    textStyle = MaterialTheme.typography.bodyMedium,
                )
                Spacer(Modifier.width(8.dp))
                IconButton(
                    onClick = {
                        val content = newComment.trim()
                        if (content.isEmpty() || currentUserId == null) return@IconButton
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
                    enabled = newComment.isNotBlank() && !isPosting,
                ) {
                    Icon(
                        Icons.AutoMirrored.Outlined.Send,
                        contentDescription = "전송",
                        tint = if (newComment.isNotBlank())
                            MaterialTheme.colorScheme.primary
                        else
                            MaterialTheme.colorScheme.onSurfaceVariant,
                    )
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
        TextButton(
            onClick = onReplyToggle,
            modifier = Modifier.padding(start = 36.dp),
        ) {
            Text(
                text = if (replyingToId == comment.id) "답글 취소" else "답글 달기",
                style = MaterialTheme.typography.labelSmall,
                color = if (replyingToId == comment.id)
                    MaterialTheme.colorScheme.primary
                else
                    MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (replies.isNotEmpty()) {
            Column(modifier = Modifier.padding(start = 20.dp)) {
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
        HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
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
        MaterialTheme.typography.bodySmall
    else
        MaterialTheme.typography.labelMedium

    Column(modifier = Modifier.padding(vertical = if (size == CommentSize.REGULAR) 8.dp else 6.dp)) {
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
                Text(comment.author?.realName ?: "—", style = nameStyle)
                comment.author?.instrument?.let {
                    Text(it, style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Text(
                text = relativeTime(comment.createdAt),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(
                modifier = Modifier.clickable(onClick = onLikeToggle),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(
                    imageVector = if (comment.isLiked) Icons.Outlined.Favorite else Icons.Outlined.FavoriteBorder,
                    contentDescription = null,
                    modifier = Modifier.padding(4.dp),
                    tint = if (comment.isLiked) Color.Red else MaterialTheme.colorScheme.onSurfaceVariant,
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
                    text = "삭제",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.Red,
                    modifier = Modifier
                        .clickable(onClick = onDelete)
                        .padding(4.dp),
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
        val instant = Instant.parse(isoString)
        val diff = (System.currentTimeMillis() - instant.toEpochMilli()) / 1000L
        when {
            diff < 60      -> "방금"
            diff < 3600    -> "${diff / 60}분 전"
            diff < 86400   -> "${diff / 3600}시간 전"
            else           -> "${diff / 86400}일 전"
        }
    } catch (_: DateTimeParseException) { "" }
    catch (_: Exception) { "" }
}
