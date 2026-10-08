package com.cadenza.android.ui.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.outlined.AlternateEmail
import androidx.compose.material.icons.outlined.Comment
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.PersonAddAlt
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.model.AppNotification
import com.cadenza.android.core.data.model.ConnectedProfile
import com.cadenza.android.core.data.model.ConnectionAction
import com.cadenza.android.core.data.model.ConnectionStatus
import com.cadenza.android.core.data.model.SuggestedProfile
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.common.UserAvatarView
import java.time.OffsetDateTime
import java.time.temporal.ChronoUnit
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(
    contentPadding: PaddingValues = PaddingValues(),
    session: SessionViewModel,
    onNavigateToUser: (String) -> Unit = {},
    viewModel: NotificationsViewModel = hiltViewModel(),
) {
    val notifications   by viewModel.notifications.collectAsState()
    val pendingTags     by viewModel.pendingTags.collectAsState()
    val suggestedProfiles by viewModel.suggestedProfiles.collectAsState()
    val isLoading       by viewModel.isLoading.collectAsState()
    val actingTagIds    by viewModel.actingTagIds.collectAsState()
    val pendingConnections by viewModel.connectionStore.pending.collectAsState()
    val connectionStatuses by viewModel.connectionStore.statuses.collectAsState()
    val updatingConnections by viewModel.connectionStore.updating.collectAsState()
    val hasLoaded       by viewModel.connectionStore.hasLoaded.collectAsState()
    val refreshFailed   by viewModel.connectionStore.refreshFailed.collectAsState()

    val userId = session.currentUserId

    LaunchedEffect(userId) { userId?.let { viewModel.load(it) } }

    val isEmpty = notifications.isEmpty() && pendingTags.isEmpty() &&
        pendingConnections.isEmpty() && suggestedProfiles.isEmpty()

    Scaffold(
        topBar = {
            TopAppBar(title = { Text(AppLocale.localized("알림", "Notifications", "Benachrichtigungen")) })
        },
    ) { innerPadding ->
        PullToRefreshBox(
            isRefreshing = isLoading && !isEmpty,
            onRefresh = { userId?.let { viewModel.load(it) } },
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(bottom = contentPadding.calculateBottomPadding()),
        ) {
            when {
                isLoading && isEmpty -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                isEmpty && !refreshFailed -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(Icons.Outlined.Notifications, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(AppLocale.localized("새 알림이 없어요", "No new notifications", "Keine neuen Benachrichtigungen"), style = MaterialTheme.typography.bodyLarge)
                            Text(AppLocale.localized("활동이 생기면 여기에 표시돼요", "Activity will appear here", "Aktivitäten erscheinen hier"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                else -> {
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        // ── Retry banner ──────────────────────────────────
                        if (refreshFailed) {
                            item {
                                Surface(
                                    modifier = Modifier.fillMaxWidth().clickable { viewModel.connectionStore.refresh(viewModel.viewModelScope, force = true) },
                                    color = MaterialTheme.colorScheme.errorContainer,
                                ) {
                                    Text(
                                        AppLocale.localized("연결 요청을 불러오지 못했어요. 탭하여 재시도", "Couldn't load connection requests. Tap to retry.", "Kontaktanfragen konnten nicht geladen werden."),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onErrorContainer,
                                        modifier = Modifier.padding(16.dp),
                                    )
                                }
                            }
                        }

                        // ── Connection requests ────────────────────────────
                        if (pendingConnections.isNotEmpty()) {
                            item {
                                SectionHeader(
                                    icon = Icons.Outlined.PersonAddAlt,
                                    title = AppLocale.localized("연결 요청", "Connection Requests", "Kontaktanfragen"),
                                )
                            }
                            items(pendingConnections, key = { it.id }) { person ->
                                ConnectionRequestRow(
                                    person = person,
                                    isActing = person.id in updatingConnections,
                                    onAccept = { viewModel.connectionStore.perform(ConnectionAction.ACCEPT, person.id) },
                                    onDecline = { viewModel.connectionStore.perform(ConnectionAction.DECLINE, person.id) },
                                )
                                HorizontalDivider(modifier = Modifier.padding(start = 72.dp))
                            }
                        }

                        // ── Tag requests ───────────────────────────────────
                        if (pendingTags.isNotEmpty()) {
                            item {
                                SectionHeader(
                                    icon = Icons.Outlined.AlternateEmail,
                                    title = AppLocale.localized("태그 요청", "Tag Requests", "Markierungsanfragen"),
                                )
                            }
                            items(pendingTags, key = { it.id }) { item ->
                                TagRequestRow(
                                    item = item,
                                    isActing = item.id in actingTagIds,
                                    onAccept = { userId?.let { viewModel.acceptTag(item.id, it) } },
                                    onDecline = { userId?.let { viewModel.declineTag(item.id, it) } },
                                )
                                HorizontalDivider(modifier = Modifier.padding(start = 72.dp))
                            }
                        }

                        // ── Notifications ──────────────────────────────────
                        if (notifications.isNotEmpty()) {
                            if (pendingTags.isNotEmpty() || pendingConnections.isNotEmpty()) {
                                item {
                                    SectionHeader(
                                        icon = Icons.Outlined.Notifications,
                                        title = AppLocale.localized("최근 알림", "Recent", "Zuletzt"),
                                    )
                                }
                            }
                            items(notifications, key = { it.id }) { notif ->
                                NotificationRow(notif = notif)
                                HorizontalDivider(modifier = Modifier.padding(start = 72.dp))
                            }
                        }

                        // ── Suggested people ───────────────────────────────
                        if (suggestedProfiles.isNotEmpty()) {
                            val visible = suggestedProfiles.filter {
                                val status = connectionStatuses[it.id]
                                status !is ConnectionStatus.Connected && status !is ConnectionStatus.RequestReceived
                            }
                            if (visible.isNotEmpty()) {
                                item {
                                    SectionHeader(
                                        icon = Icons.Outlined.PersonAddAlt,
                                        title = AppLocale.localized("알 수도 있는 사람", "People you may know", "Personen, die du kennen könntest"),
                                    )
                                }
                                item {
                                    SuggestedPeopleGrid(
                                        people = visible.take(4),
                                        connectionStatuses = connectionStatuses,
                                        updatingIds = updatingConnections,
                                        hasLoaded = hasLoaded,
                                        onNavigateTo = onNavigateToUser,
                                        onConnect = { viewModel.toggleSuggestedConnection(it) },
                                    )
                                }
                            }
                        }

                        item { Spacer(Modifier.height(24.dp)) }
                    }
                }
            }
        }
    }
}

// ─── Section header ───────────────────────────────────────────────────────────

@Composable
private fun SectionHeader(icon: ImageVector, title: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(title, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
    }
}

// ─── Notification row ─────────────────────────────────────────────────────────

@Composable
private fun NotificationRow(notif: AppNotification) {
    val (icon, iconColor) = when (notif.type) {
        "like"    -> Icons.Default.Favorite to Color(0xFFE53935)
        "comment" -> Icons.Outlined.Comment  to Color(0xFF1E88E5)
        "follow"  -> Icons.Default.PersonAdd  to MaterialTheme.colorScheme.primary
        "tag"     -> Icons.Outlined.AlternateEmail to Color(0xFFFB8C00)
        else      -> Icons.Outlined.Notifications to MaterialTheme.colorScheme.onSurfaceVariant
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Box(
            modifier = Modifier.size(40.dp).clip(CircleShape).background(iconColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp), tint = iconColor)
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                notif.bodyText,
                style = MaterialTheme.typography.bodyMedium,
                color = if (notif.isRead) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
            )
            Text(
                notif.timeAgo,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (!notif.isRead) {
            Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary).padding(top = 6.dp))
        }
    }
}

// ─── Connection request row ───────────────────────────────────────────────────

@Composable
private fun ConnectionRequestRow(
    person: ConnectedProfile,
    isActing: Boolean,
    onAccept: suspend () -> Unit,
    onDecline: suspend () -> Unit,
) {
    val scope = rememberCoroutineScope()
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(40.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Outlined.PersonAddAlt, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    AppLocale.localized("${person.realName} 님이 연결을 요청했어요", "${person.realName} sent you a connection request", "${person.realName} möchte sich mit dir verbinden"),
                    style = MaterialTheme.typography.bodyMedium,
                )
                if (!person.instrument.isNullOrEmpty()) {
                    Text(OnboardingData.instrumentDisplay(person.instrument), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(
                onClick = { scope.launch { onDecline() } },
                enabled = !isActing,
                modifier = Modifier.weight(1f),
            ) { Text(AppLocale.localized("거절", "Decline", "Ablehnen")) }
            Button(
                onClick = { scope.launch { onAccept() } },
                enabled = !isActing,
                modifier = Modifier.weight(1f),
            ) { Text(AppLocale.localized("수락", "Accept", "Annehmen")) }
        }
    }
}

// ─── Tag request row ──────────────────────────────────────────────────────────

@Composable
private fun TagRequestRow(
    item: ActivityWithAuthor,
    isActing: Boolean,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier.size(40.dp).clip(CircleShape).background(Color(0xFFFB8C00).copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Outlined.AlternateEmail, contentDescription = null, modifier = Modifier.size(18.dp), tint = Color(0xFFFB8C00))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    AppLocale.localized(
                        "${item.author?.realName ?: "누군가"} 님이 활동 기록에 태그했어요",
                        "${item.author?.realName ?: "Someone"} tagged you in an activity",
                        "${item.author?.realName ?: "Jemand"} hat dich in einer Aktivität markiert"
                    ),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(item.title, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(
                onClick = onDecline,
                enabled = !isActing,
                modifier = Modifier.weight(1f),
            ) { Text(AppLocale.localized("거절", "Decline", "Ablehnen")) }
            Button(
                onClick = onAccept,
                enabled = !isActing,
                modifier = Modifier.weight(1f),
            ) { Text(AppLocale.localized("기록 공유", "Share activity", "Aktivität teilen"), maxLines = 1, overflow = TextOverflow.Ellipsis) }
        }
    }
}

// ─── Suggested people grid ────────────────────────────────────────────────────

@Composable
private fun SuggestedPeopleGrid(
    people: List<SuggestedProfile>,
    connectionStatuses: Map<String, ConnectionStatus>,
    updatingIds: Set<String>,
    hasLoaded: Boolean,
    onNavigateTo: (String) -> Unit,
    onConnect: (String) -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // 2-column grid using rows of 2
        people.chunked(2).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                row.forEach { person ->
                    val isSent = connectionStatuses[person.id] is ConnectionStatus.RequestSent
                    SuggestedPersonCard(
                        person = person,
                        isSent = isSent,
                        isUpdating = person.id in updatingIds || !hasLoaded,
                        onOpen = { onNavigateTo(person.id) },
                        onConnect = { onConnect(person.id) },
                        modifier = Modifier.weight(1f),
                    )
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun SuggestedPersonCard(
    person: SuggestedProfile,
    isSent: Boolean,
    isUpdating: Boolean,
    onOpen: () -> Unit,
    onConnect: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 2.dp,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                modifier = Modifier.fillMaxWidth().clickable(onClick = onOpen).padding(top = 16.dp, bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                UserAvatarView(url = person.avatarUrl, name = person.realName, size = 60.dp)
                Text(person.realName, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(horizontal = 12.dp))
                val subtitle = person.instrument?.let { OnboardingData.instrumentDisplay(it) }
                if (subtitle != null) {
                    Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, modifier = Modifier.padding(horizontal = 12.dp))
                }
                if (person.mutualCount > 0) {
                    Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.surfaceVariant) {
                        Text(
                            AppLocale.localized("공통 ${person.mutualCount}", "${person.mutualCount} mutual", "${person.mutualCount} Gemeinsame"),
                            style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            Surface(
                onClick = onConnect,
                enabled = !isUpdating,
                shape = RoundedCornerShape(8.dp),
                color = if (isSent) MaterialTheme.colorScheme.surfaceVariant else MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                modifier = Modifier.padding(horizontal = 12.dp).fillMaxWidth(),
            ) {
                Text(
                    if (isSent) AppLocale.localized("신청됨", "Requested", "Angefragt") else AppLocale.localized("연결 신청", "Connect", "Verbinden"),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = if (isSent) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(vertical = 8.dp).fillMaxWidth(),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// ─── AppNotification extension properties ────────────────────────────────────

val AppNotification.bodyText: String get() {
    val name = actor?.realName ?: AppLocale.localized("누군가", "Someone", "Jemand")
    return when (type) {
        "like"    -> AppLocale.localized("$name 님이 활동 기록을 좋아합니다.", "$name liked your activity.", "$name hat deine Aktivität gemocht.")
        "comment" -> AppLocale.localized("$name 님이 댓글을 달았습니다.", "$name commented on your activity.", "$name hat deine Aktivität kommentiert.")
        "follow"  -> AppLocale.localized("$name 님이 팔로우를 시작했습니다.", "$name started following you.", "$name folgt dir jetzt.")
        "tag"     -> AppLocale.localized("$name 님이 활동 기록에 태그했습니다.", "$name tagged you in an activity.", "$name hat dich in einer Aktivität markiert.")
        else      -> message ?: AppLocale.localized("새 알림", "New notification", "Neue Benachrichtigung")
    }
}

val AppNotification.timeAgo: String get() = try {
    val created = OffsetDateTime.parse(createdAt)
    val secs = ChronoUnit.SECONDS.between(created, OffsetDateTime.now())
    when {
        secs < 60     -> AppLocale.localized("방금", "Just now", "Gerade eben")
        secs < 3600   -> "${secs / 60}${AppLocale.localized("분 전", "m ago", " Min. ago")}"
        secs < 86400  -> "${secs / 3600}${AppLocale.localized("시간 전", "h ago", " Std. ago")}"
        secs < 604800 -> "${secs / 86400}${AppLocale.localized("일 전", "d ago", " T. ago")}"
        else          -> "${secs / 604800}${AppLocale.localized("주 전", "w ago", " W. ago")}"
    }
} catch (_: Exception) { "" }
