package com.cadenza.android.ui.feed.components

import android.content.Intent
import android.content.Intent.ACTION_SEND
import android.content.Intent.EXTRA_TEXT
import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.outlined.EmojiEvents
import androidx.compose.material.icons.outlined.EyeOff
import androidx.compose.material.icons.outlined.GraphicEq
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.PersonAdd
import androidx.compose.material.icons.outlined.School
import androidx.compose.material.icons.outlined.Share
import androidx.compose.material.icons.outlined.ThumbUp
import androidx.compose.material.icons.outlined.Translate
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.cadenza.android.core.data.model.ActivityStats
import com.cadenza.android.core.data.model.ActivityType
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.model.ConnectionAction
import com.cadenza.android.core.data.model.ConnectionStatus
import com.cadenza.android.core.data.model.ProfileLite
import com.cadenza.android.core.data.model.VerificationStatus
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.ConnectionStore
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.common.ExpandableText
import com.cadenza.android.ui.common.UserAvatarView
import com.cadenza.android.ui.theme.CadenzaAccent
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.TranslatorOptions
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.time.Instant
import java.time.format.DateTimeParseException
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@Composable
fun ActivityCard(
    item: ActivityWithAuthor,
    repository: Repository,
    connectionStore: ConnectionStore,
    currentUserId: String?,
    onNavigateToUser: (String) -> Unit = {},
    onNavigateToOrg: (String) -> Unit = {},
    onDeleted: (() -> Unit)? = null,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    // Stats
    var likeCount by remember(item.id) { mutableIntStateOf(0) }
    var commentCount by remember(item.id) { mutableIntStateOf(0) }
    var isLiked by remember(item.id) { mutableStateOf(false) }
    var isSaved by remember(item.id) { mutableStateOf(false) }
    var tags by remember(item.id) { mutableStateOf<List<ProfileLite>>(emptyList()) }

    // UI state
    var showComments by remember { mutableStateOf(false) }
    var showMeatball by remember { mutableStateOf(false) }
    var showReport by remember { mutableStateOf(false) }
    var isHidden by remember { mutableStateOf(false) }
    var isDeleted by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var viewerUrls by remember { mutableStateOf<List<String>?>(null) }
    var viewerIndex by remember { mutableIntStateOf(0) }

    // Translation
    var showTranslation by remember { mutableStateOf(false) }
    var isTranslating by remember { mutableStateOf(false) }
    var translatedText by remember { mutableStateOf<String?>(null) }
    var translationError by remember { mutableStateOf<String?>(null) }

    // Connection state
    val statuses by connectionStore.statuses.collectAsState()
    val updating by connectionStore.updating.collectAsState()
    val authorConnectionStatus = item.author?.id?.let { statuses[it] }
    val isUpdatingConnection = item.author?.id?.let { updating.contains(it) } == true

    LaunchedEffect(item.id) {
        if (currentUserId == null) return@LaunchedEffect
        try {
            val stats: ActivityStats = repository.activityStats(item.id, currentUserId)
            likeCount = stats.likeCount
            commentCount = stats.commentCount
            isLiked = stats.isLiked
            isSaved = stats.isSaved
        } catch (_: Throwable) {}
        try { tags = repository.tags(item.id) } catch (_: Throwable) {}
    }

    fun reloadStats() {
        scope.launch {
            if (currentUserId == null) return@launch
            try {
                val stats = repository.activityStats(item.id, currentUserId)
                likeCount = stats.likeCount
                commentCount = stats.commentCount
                isLiked = stats.isLiked
                isSaved = stats.isSaved
            } catch (_: Throwable) {}
        }
    }

    if (isDeleted) return

    if (isHidden) {
        HiddenBanner(onUndo = { isHidden = false })
        return
    }

    // Card
    Column(modifier = Modifier.background(MaterialTheme.colorScheme.surface)) {
        // Social context (feed reason)
        val (feedBase, feedName) = parseFeedReason(item.feedReason)
        if (feedBase == "connection_commented") {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Icon(Icons.AutoMirrored.Outlined.Chat, contentDescription = null,
                    modifier = Modifier.size(12.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    text = if (feedName != null) "${feedName}님이 댓글을 달았습니다"
                           else "연결된 사람이 댓글을 달았습니다",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        // Author header
        AuthorHeader(
            item = item,
            authorConnectionStatus = authorConnectionStatus,
            isUpdatingConnection = isUpdatingConnection,
            currentUserId = currentUserId,
            showConnectButton = shouldShowConnect(item, authorConnectionStatus, currentUserId),
            onNavigateToUser = onNavigateToUser,
            onNavigateToOrg = onNavigateToOrg,
            onConnectTap = {
                scope.launch {
                    val action = if (authorConnectionStatus is ConnectionStatus.RequestSent)
                        ConnectionAction.CANCEL else ConnectionAction.REQUEST
                    item.author?.id?.let { connectionStore.perform(action, it) }
                }
            },
            onMeatballTap = { showMeatball = true },
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
        )

        // Activity content
        ActivityContent(
            item = item,
            showTranslation = showTranslation,
            isTranslating = isTranslating,
            translatedText = translatedText,
            translationError = translationError,
            modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 8.dp),
        )

        // Translation button
        val postBody = postBodyText(item)
        if (postBody.isNotBlank()) {
            val targetName = when (AppLocale.language) {
                "en" -> "English"
                "de" -> "Deutsch"
                else -> "한국어"
            }
            TextButton(
                onClick = {
                    showTranslation = !showTranslation
                    if (showTranslation && translatedText == null) {
                        scope.launch {
                            isTranslating = true
                            translationError = null
                            try {
                                translatedText = mlKitTranslate(postBody, AppLocale.language)
                            } catch (_: Throwable) {
                                translationError = "번역을 불러오지 못했습니다."
                            } finally {
                                isTranslating = false
                            }
                        }
                    }
                },
                modifier = Modifier.padding(horizontal = 8.dp),
            ) {
                Icon(Icons.Outlined.Translate, contentDescription = null,
                    modifier = Modifier.size(14.dp).padding(end = 2.dp))
                Text(
                    text = if (showTranslation) "원문 보기"
                           else "$targetName 번역 보기",
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }

        // Tagged people
        if (tags.isNotEmpty()) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Icon(Icons.Outlined.PersonAdd, contentDescription = null,
                    modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                tags.forEach { p ->
                    Surface(
                        shape = RoundedCornerShape(50),
                        color = CadenzaAccent.copy(alpha = 0.12f),
                    ) {
                        Text(
                            text = p.realName,
                            style = MaterialTheme.typography.labelSmall,
                            color = CadenzaAccent,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        )
                    }
                }
            }
        }

        // Images
        if (item.imageUrls.isNotEmpty()) {
            ImageGrid(
                urls = item.imageUrls,
                onTap = { index ->
                    viewerIndex = index
                    viewerUrls = item.imageUrls
                },
                modifier = Modifier.padding(bottom = 8.dp),
            )
        }

        // Link preview
        if (!item.linkUrl.isNullOrBlank()) {
            LinkPreviewCard(
                urlString = item.linkUrl,
                title = item.linkTitle,
                siteName = item.linkSiteName,
                imageUrl = item.linkImageUrl,
                modifier = Modifier.padding(horizontal = 16.dp).padding(bottom = 12.dp),
            )
        }

        // Stats row
        if (likeCount > 0 || commentCount > 0) {
            Row(
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (likeCount > 0) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Box(
                            modifier = Modifier
                                .size(18.dp)
                                .background(CadenzaAccent, CircleShape),
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(Icons.Outlined.ThumbUp, contentDescription = null,
                                modifier = Modifier.size(10.dp), tint = Color.White)
                        }
                        Text("$likeCount", style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
                if (commentCount > 0) {
                    Text(
                        text = "댓글 ${commentCount}개",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.clickable { showComments = true },
                    )
                }
            }
        }

        HorizontalDivider()

        // Action bar
        Row(modifier = Modifier.fillMaxWidth()) {
            ActionButton(
                icon = if (isLiked) Icons.Outlined.ThumbUp else Icons.Outlined.ThumbUp,
                label = "좋아요",
                tint = if (isLiked) CadenzaAccent else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
                onClick = {
                    scope.launch {
                        if (currentUserId == null) return@launch
                        val was = isLiked
                        isLiked = !was
                        likeCount += if (isLiked) 1 else -1
                        try {
                            if (was) repository.unlikeActivity(item.id, currentUserId)
                            else repository.likeActivity(item.id, currentUserId)
                        } catch (_: Throwable) {
                            isLiked = was
                            likeCount += if (was) 1 else -1
                        }
                    }
                },
            )
            ActionButton(
                icon = Icons.AutoMirrored.Outlined.Chat,
                label = "댓글",
                modifier = Modifier.weight(1f),
                onClick = { showComments = true },
            )
            ActionButton(
                icon = Icons.Outlined.Share,
                label = "공유",
                modifier = Modifier.weight(1f),
                onClick = {
                    val text = buildString {
                        append(item.title)
                        item.role?.let { append("\n$it") }
                        append("\n${item.activityDate}")
                        item.location?.let { if (it.isNotBlank()) append("\n$it") }
                        append("\n— Cadenza")
                    }
                    val intent = Intent(ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(EXTRA_TEXT, text)
                    }
                    context.startActivity(Intent.createChooser(intent, null))
                },
            )
        }
    }

    // Sheets and dialogs
    if (showComments) {
        CommentsSheet(
            activity = item,
            currentUserId = currentUserId,
            repository = repository,
            onDismiss = { showComments = false },
            onStatsChanged = { reloadStats() },
        )
    }

    if (showMeatball) {
        PostMeatballSheet(
            isSaved = isSaved,
            isOwnPost = item.author?.id == currentUserId,
            onDismiss = { showMeatball = false },
            onSave = {
                scope.launch {
                    if (currentUserId == null) return@launch
                    val was = isSaved
                    isSaved = !was
                    try {
                        if (was) repository.unsaveActivity(currentUserId, item.id)
                        else repository.saveActivity(currentUserId, item.id)
                    } catch (_: Throwable) { isSaved = was }
                }
            },
            onUnfollow = {
                scope.launch { item.author?.id?.let { connectionStore.perform(ConnectionAction.DISCONNECT, it) } }
            },
            onHide = { isHidden = true },
            onReport = { showReport = true },
            onEdit = { /* TODO: EditActivitySheet */ },
            onDelete = { showDeleteConfirm = true },
        )
    }

    if (showReport) {
        AlertDialog(
            onDismissRequest = { showReport = false },
            title = { Text("신고") },
            text = { Text("신고 이유를 선택해 주세요") },
            confirmButton = {
                TextButton(onClick = { isHidden = true; showReport = false }) { Text("스팸") }
            },
            dismissButton = {
                TextButton(onClick = { showReport = false }) { Text("취소") }
            },
        )
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("게시글을 삭제하시겠어요?") },
            text = { Text("삭제 후에는 복구할 수 없습니다.") },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirm = false
                    scope.launch {
                        try {
                            repository.deleteActivity(item.id)
                            if (onDeleted != null) onDeleted()
                            else isDeleted = true
                        } catch (_: Throwable) {}
                    }
                }) { Text("삭제", color = Color.Red) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text("취소") }
            },
        )
    }

    viewerUrls?.let {
        ImageViewerDialog(
            urls = it,
            initialIndex = viewerIndex,
            onDismiss = { viewerUrls = null },
        )
    }
}

// ── Sub-composables ────────────────────────────────────────────────────────────

@Composable
private fun HiddenBanner(onUndo: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Outlined.EyeOff, contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(18.dp).padding(end = 8.dp))
        Text(
            text = "관심없음으로 표시됨",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
        )
        TextButton(onClick = onUndo) { Text("실행 취소") }
    }
}

@Composable
private fun AuthorHeader(
    item: ActivityWithAuthor,
    authorConnectionStatus: ConnectionStatus?,
    isUpdatingConnection: Boolean,
    currentUserId: String?,
    showConnectButton: Boolean,
    onNavigateToUser: (String) -> Unit,
    onNavigateToOrg: (String) -> Unit,
    onConnectTap: () -> Unit,
    onMeatballTap: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (item.org != null) {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onNavigateToOrg(item.org.id) },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                OrgAvatarIcon(size = 42.dp)
                Column {
                    Text(item.org.name, style = MaterialTheme.typography.titleSmall)
                    Text(
                        text = postTimeText(item.createdAt),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        } else {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .then(
                        if (item.author?.id != null)
                            Modifier.clickable { onNavigateToUser(item.author.id) }
                        else Modifier
                    ),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                UserAvatarView(
                    url = item.author?.avatarUrl,
                    name = item.author?.realName ?: "?",
                    size = 42.dp,
                )
                Column {
                    Text(item.author?.realName ?: "—", style = MaterialTheme.typography.titleSmall)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        item.author?.instrument?.let { inst ->
                            Text(inst, style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text("·", style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.outlineVariant)
                        }
                        Text(
                            text = postTimeText(item.createdAt),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
        }

        if (item.org == null && showConnectButton) {
            if (isUpdatingConnection) {
                CircularProgressIndicator(modifier = Modifier.size(24.dp), strokeWidth = 2.dp)
            } else {
                FilterChip(
                    selected = authorConnectionStatus is ConnectionStatus.RequestSent,
                    onClick = onConnectTap,
                    label = {
                        Text(
                            if (authorConnectionStatus is ConnectionStatus.RequestSent) "요청됨" else "연결",
                            style = MaterialTheme.typography.labelSmall,
                        )
                    },
                    modifier = Modifier.height(28.dp),
                )
            }
            Spacer(Modifier.width(4.dp))
        }

        IconButton(onClick = onMeatballTap, modifier = Modifier.size(32.dp)) {
            Icon(Icons.Outlined.MoreHoriz, contentDescription = "더보기",
                tint = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun ActivityContent(
    item: ActivityWithAuthor,
    showTranslation: Boolean,
    isTranslating: Boolean,
    translatedText: String?,
    translationError: String?,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(item.title, style = MaterialTheme.typography.titleMedium)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (item.verification == VerificationStatus.INSTITUTION_VERIFIED) {
                Surface(
                    shape = RoundedCornerShape(4.dp),
                    color = Color(0xFF2E7D32),
                ) {
                    Text(
                        "인증됨",
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                        modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp),
                    )
                }
            }
            ActivityTypeChip(item.type)
            item.location?.let { loc ->
                if (loc.isNotBlank()) {
                    Text("·", style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.outlineVariant)
                    Text(loc, style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                }
            }
        }

        val bodyText = postBodyText(item)
        if (bodyText.isNotBlank()) {
            if (showTranslation) {
                AnimatedContent(targetState = isTranslating, label = "translation") { translating ->
                    if (translating) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
                            Text("번역 중...", style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    } else if (!translatedText.isNullOrBlank()) {
                        ExpandableText(
                            text = translatedText,
                            collapsedLineLimit = 3,
                            style = MaterialTheme.typography.bodyMedium.copy(
                                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.8f),
                            ),
                        )
                    } else if (translationError != null) {
                        Text(translationError, style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error)
                    }
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    if (!item.personalNote.isNullOrBlank()) {
                        Text(
                            AppLocale.localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte"),
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                            color = CadenzaAccent,
                        )
                    }
                    ExpandableText(text = bodyText, collapsedLineLimit = 3)
                }
            }
        }
    }
}

@Composable
private fun ImageGrid(
    urls: List<String>,
    onTap: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val count = urls.size
    val gridH = if (count == 2) 240.dp else 300.dp
    val gap = 2.dp

    BoxWithConstraints(modifier = modifier.fillMaxWidth()) {
        val w = maxWidth
        when {
            count == 1 -> {
                PhotoCell(url = urls[0], width = w, height = gridH, onClick = { onTap(0) })
            }
            count == 2 -> {
                val cw = (w - gap) / 2
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    PhotoCell(url = urls[0], width = cw, height = gridH, onClick = { onTap(0) })
                    PhotoCell(url = urls[1], width = cw, height = gridH, onClick = { onTap(1) })
                }
            }
            count == 3 -> {
                val mainW = w * 0.6f - gap / 2
                val rightW = w - mainW - gap
                val rh = (gridH - gap) / 2
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    PhotoCell(url = urls[0], width = mainW, height = gridH, onClick = { onTap(0) })
                    Column(verticalArrangement = Arrangement.spacedBy(gap)) {
                        PhotoCell(url = urls[1], width = rightW, height = rh, onClick = { onTap(1) })
                        PhotoCell(url = urls[2], width = rightW, height = rh, onClick = { onTap(2) })
                    }
                }
            }
            else -> {
                val mainW = w * 0.6f - gap / 2
                val rightW = w - mainW - gap
                val rh = (gridH - gap * 2) / 3
                val extra = count - 4
                Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                    PhotoCell(url = urls[0], width = mainW, height = gridH, onClick = { onTap(0) })
                    Column(verticalArrangement = Arrangement.spacedBy(gap)) {
                        PhotoCell(url = urls[1], width = rightW, height = rh, onClick = { onTap(1) })
                        PhotoCell(url = urls[2], width = rightW, height = rh, onClick = { onTap(2) })
                        Box(modifier = Modifier.width(rightW).height(rh)) {
                            PhotoCell(url = urls[3], width = rightW, height = rh, onClick = { onTap(3) })
                            if (extra > 0) {
                                Box(
                                    modifier = Modifier.matchParentSize()
                                        .background(Color.Black.copy(alpha = 0.45f)),
                                    contentAlignment = Alignment.Center,
                                ) {
                                    Text("+$extra", style = MaterialTheme.typography.titleMedium,
                                        color = Color.White, fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PhotoCell(
    url: String,
    width: Dp,
    height: Dp,
    onClick: () -> Unit,
) {
    AsyncImage(
        model = url,
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = Modifier
            .width(width)
            .height(height)
            .clickable(onClick = onClick),
    )
}

@Composable
private fun ActionButton(
    icon: ImageVector,
    label: String,
    tint: Color = MaterialTheme.colorScheme.onSurfaceVariant,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Row(
        modifier = modifier
            .clickable(onClick = onClick)
            .padding(vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp), tint = tint)
        Spacer(Modifier.width(5.dp))
        Text(label, style = MaterialTheme.typography.bodyMedium, color = tint)
    }
}

@Composable
private fun OrgAvatarIcon(size: Dp) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(RoundedCornerShape(8.dp))
            .background(MaterialTheme.colorScheme.secondaryContainer),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Outlined.MusicNote,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSecondaryContainer,
            modifier = Modifier.size(size * 0.55f),
        )
    }
}

@Composable
private fun ActivityTypeChip(type: ActivityType) {
    val (icon, color) = when (type) {
        ActivityType.PERFORMANCE -> Icons.Outlined.MusicNote to Color(0xFF1565C0)
        ActivityType.COMPETITION -> Icons.Outlined.EmojiEvents to Color(0xFFE65100)
        ActivityType.EDUCATION   -> Icons.Outlined.School to Color(0xFF2E7D32)
        ActivityType.RECORDING   -> Icons.Outlined.GraphicEq to Color(0xFF6A1B9A)
    }
    Surface(
        shape = RoundedCornerShape(4.dp),
        color = color.copy(alpha = 0.1f),
        border = androidx.compose.foundation.BorderStroke(0.5.dp, color.copy(alpha = 0.3f)),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 5.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(10.dp), tint = color)
            Text(type.localizedLabel, style = MaterialTheme.typography.labelSmall, color = color)
        }
    }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

private fun parseFeedReason(reason: String?): Pair<String, String?> {
    if (reason == null) return "" to null
    val sep = reason.indexOf('|')
    return if (sep >= 0) reason.substring(0, sep) to reason.substring(sep + 1).ifEmpty { null }
    else reason to null
}

private fun shouldShowConnect(
    item: ActivityWithAuthor,
    status: ConnectionStatus?,
    currentUserId: String?,
): Boolean {
    if (item.feedReason == null) return false
    if (item.author?.id == currentUserId) return false
    return status != null && status !is ConnectionStatus.Connected && status !is ConnectionStatus.RequestReceived
}

private fun postBodyText(item: ActivityWithAuthor): String =
    listOfNotNull(
        item.personalNote?.trim()?.ifBlank { null },
        item.role?.trim()?.ifBlank { null },
        item.program?.trim()?.ifBlank { null },
    ).joinToString("\n\n")

private fun postTimeText(createdAt: String?): String {
    if (createdAt == null) return ""
    return try {
        val instant = Instant.parse(createdAt)
        val diff = (System.currentTimeMillis() - instant.toEpochMilli()) / 1000L
        when {
            diff < 60    -> "방금"
            diff < 3600  -> "${diff / 60}분 전"
            diff < 86400 -> "${diff / 3600}시간 전"
            diff < 86400 * 7 -> "${diff / 86400}일 전"
            diff < 86400 * 30L -> "${diff / (86400 * 7)}주 전"
            diff < 86400 * 365L -> "${diff / (86400 * 30)}개월 전"
            else -> "${diff / (86400 * 365)}년 전"
        }
    } catch (_: DateTimeParseException) { "" }
    catch (_: Exception) { "" }
}

// ── ML Kit Translation ────────────────────────────────────────────────────────

private suspend fun mlKitTranslate(text: String, targetLangCode: String): String {
    val sourceLang = detectLanguage(text)
    val target = when (targetLangCode) {
        "en" -> TranslateLanguage.ENGLISH
        "de" -> TranslateLanguage.GERMAN
        else -> TranslateLanguage.KOREAN
    }
    val source = when {
        sourceLang == "und" || sourceLang == target ->
            if (target == TranslateLanguage.KOREAN) TranslateLanguage.ENGLISH
            else TranslateLanguage.KOREAN
        else -> sourceLang
    }
    val options = TranslatorOptions.Builder()
        .setSourceLanguage(source)
        .setTargetLanguage(target)
        .build()
    val translator = Translation.getClient(options)
    return try {
        suspendCancellableCoroutine { cont ->
            translator.downloadModelIfNeeded(DownloadConditions.Builder().build())
                .addOnSuccessListener {
                    translator.translate(text)
                        .addOnSuccessListener { result -> cont.resume(result) }
                        .addOnFailureListener { e -> cont.resumeWithException(e) }
                }
                .addOnFailureListener { e -> cont.resumeWithException(e) }
            cont.invokeOnCancellation { translator.close() }
        }
    } finally {
        translator.close()
    }
}

private suspend fun detectLanguage(text: String): String =
    suspendCancellableCoroutine { cont ->
        LanguageIdentification.getClient()
            .identifyLanguage(text)
            .addOnSuccessListener { lang -> cont.resume(lang) }
            .addOnFailureListener { cont.resume("und") }
    }

// ── LinkPreviewCard overload with Modifier ────────────────────────────────────
@Composable
private fun LinkPreviewCard(
    urlString: String,
    title: String?,
    siteName: String?,
    imageUrl: String?,
    modifier: Modifier = Modifier,
) {
    Box(modifier = modifier) {
        com.cadenza.android.ui.feed.components.LinkPreviewCard(
            urlString = urlString,
            title = title,
            siteName = siteName,
            imageUrl = imageUrl,
        )
    }
}
