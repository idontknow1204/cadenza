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
import com.cadenza.android.ui.common.CadenzaPullToRefresh
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
import androidx.compose.ui.unit.sp
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
        CadenzaPullToRefresh(
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
                    // 스크롤 가능한 컨테이너여야 빈 상태에서도 당겨서 새로고침이 동작한다
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        item {
                            Column(
                                modifier = Modifier.fillParentMaxSize(),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
                            ) {
                                Icon(Icons.Outlined.Notifications, contentDescription = null, modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(AppLocale.localized("새 알림이 없어요", "No new notifications", "Keine neuen Benachrichtigungen"), style = MaterialTheme.typography.bodyLarge)
                                Text(AppLocale.localized("활동이 생기면 여기에 표시돼요", "Activity will appear here", "Aktivitäten erscheinen hier"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                else -> {
                    LazyColumn(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
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
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
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

    // iOS: .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)) + HStack(spacing: 12)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        // iOS: Circle icon .frame(width: 40, height: 40) + .font(.system(size: 15, weight: .semibold))
        Box(
            modifier = Modifier.size(40.dp).clip(CircleShape).background(iconColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(15.dp), tint = iconColor)
        }
        // iOS: VStack(spacing: 3)
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            // iOS: .font(.subheadline) = 15sp
            Text(
                notif.bodyText,
                style = MaterialTheme.typography.bodyMedium,
                color = if (notif.isRead) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
            )
            // iOS: .font(.caption2) = 11sp
            Text(
                notif.timeAgo,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (!notif.isRead) {
            // iOS: Circle .fill(Color.accentColor).frame(width: 8, height: 8)
            Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary).padding(top = 6.dp))
        }
    }
}

// ─── Connection request row ───────────────────────────────────────────────────

// 수락/거절 버튼 높이 (M3 기본 40dp보다 키움)
private val RequestButtonHeight = 46.dp

@Composable
private fun ConnectionRequestRow(
    person: ConnectedProfile,
    isActing: Boolean,
    onAccept: suspend () -> Unit,
    onDecline: suspend () -> Unit,
) {
    // iOS: .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    val scope = rememberCoroutineScope()
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
        // iOS: VStack(spacing: 8) inside connection request row
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // iOS: HStack(spacing: 10)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            // iOS: Circle icon .frame(width: 40, height: 40) + .font(.system(size: 15, weight: .semibold))
            Box(
                modifier = Modifier.size(40.dp).clip(CircleShape).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Outlined.PersonAddAlt, contentDescription = null, modifier = Modifier.size(15.dp), tint = MaterialTheme.colorScheme.primary)
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
        // iOS: HStack(spacing: 10) with .padding(.vertical, 8) buttons + RoundedRectangle(10)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(
                onClick = { scope.launch { onDecline() } },
                enabled = !isActing,
                modifier = Modifier.weight(1f).height(RequestButtonHeight),
                shape = RoundedCornerShape(10.dp),
            ) { Text(AppLocale.localized("거절", "Decline", "Ablehnen"), style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium)) }
            Button(
                onClick = { scope.launch { onAccept() } },
                enabled = !isActing,
                modifier = Modifier.weight(1f).height(RequestButtonHeight),
                shape = RoundedCornerShape(10.dp),
            ) { Text(AppLocale.localized("수락", "Accept", "Annehmen"), style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold)) }
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
    // iOS: .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
        // iOS: VStack(spacing: 8)
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // iOS: HStack(spacing: 10)
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            // iOS: Circle .fill(Color.orange.opacity(0.12)) + icon .font(.system(size: 15)) .frame(width: 40, height: 40)
            Box(
                modifier = Modifier.size(40.dp).clip(CircleShape).background(Color(0xFFFB8C00).copy(alpha = 0.12f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Outlined.AlternateEmail, contentDescription = null, modifier = Modifier.size(15.dp), tint = Color(0xFFFB8C00))
            }
            Column(modifier = Modifier.weight(1f)) {
                // iOS: .font(.subheadline) = 15sp
                Text(
                    AppLocale.localized(
                        "${item.author?.realName ?: "누군가"} 님이 활동 기록에 태그했어요",
                        "${item.author?.realName ?: "Someone"} tagged you in an activity",
                        "${item.author?.realName ?: "Jemand"} hat dich in einer Aktivität markiert"
                    ),
                    style = MaterialTheme.typography.bodyMedium,
                )
                // iOS: .font(.caption) = 12sp
                Text(item.title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        // iOS: HStack(spacing: 10) + buttons with .padding(.vertical, 8).background(…, RoundedRectangle(10))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(
                onClick = onDecline,
                enabled = !isActing,
                modifier = Modifier.weight(1f).height(RequestButtonHeight),
                shape = RoundedCornerShape(10.dp),
            ) { Text(AppLocale.localized("거절", "Decline", "Ablehnen"), style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium)) }
            Button(
                onClick = onAccept,
                enabled = !isActing,
                modifier = Modifier.weight(1f).height(RequestButtonHeight),
                shape = RoundedCornerShape(10.dp),
            ) { Text(AppLocale.localized("기록 공유", "Share activity", "Aktivität teilen"), style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold), maxLines = 1, overflow = TextOverflow.Ellipsis) }
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
    // iOS SuggestedPersonCard: RoundedRectangle(16) + .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // iOS: profileContent - .padding(.top, 16) avatar + spacings
            Column(
                modifier = Modifier.fillMaxWidth().clickable(onClick = onOpen).padding(top = 16.dp, bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // iOS: UserAvatarView(size: 60)
                UserAvatarView(url = person.avatarUrl, name = person.realName, size = 60.dp)
                // iOS: .font(.subheadline.weight(.semibold)) + .padding(.top, 8).padding(.horizontal, 12)
                Spacer(Modifier.height(8.dp))
                Text(person.realName, style = MaterialTheme.typography.bodyMedium.copy(fontSize = 16.sp, fontWeight = FontWeight.SemiBold), maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(horizontal = 12.dp))
                val subtitle = person.instrument?.let { OnboardingData.instrumentDisplay(it) }
                if (subtitle != null) {
                    // iOS: .font(.caption) + .padding(.horizontal, 12).padding(.top, 2)
                    Text(subtitle, style = MaterialTheme.typography.bodySmall.copy(fontSize = 14.sp), color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1, modifier = Modifier.padding(horizontal = 12.dp).padding(top = 2.dp))
                }
                if (person.mutualCount > 0) {
                    // iOS: .padding(.horizontal, 8).padding(.vertical, 4).background(.secondary.opacity(0.12), Capsule).padding(.top, 6)
                    Spacer(Modifier.height(6.dp))
                    Surface(shape = RoundedCornerShape(50), color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.12f)) {
                        Text(
                            AppLocale.localized("공통 ${person.mutualCount}", "${person.mutualCount} mutual", "${person.mutualCount} Gemeinsame"),
                            style = MaterialTheme.typography.bodySmall,
                            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }
            // iOS connect button: .padding(.horizontal, 12).padding(.bottom, 12) + Spacer(minLength: 12)
            Spacer(Modifier.height(4.dp))
            // iOS: RoundedRectangle(8) + (isSent ? .secondary : .accentColor).opacity(0.10)
            Surface(
                onClick = onConnect,
                enabled = !isUpdating,
                shape = RoundedCornerShape(8.dp),
                color = if (isSent) MaterialTheme.colorScheme.onSurface.copy(alpha = 0.10f)
                        else MaterialTheme.colorScheme.primary.copy(alpha = 0.10f),
                modifier = Modifier.padding(horizontal = 12.dp).fillMaxWidth(),
            ) {
                Text(
                    if (isSent) AppLocale.localized("신청됨", "Requested", "Angefragt") else AppLocale.localized("연결 신청", "Connect", "Verbinden"),
                    // iOS는 11pt semibold이지만 Android에서는 너무 작아 15sp로 키움 (수동 조정)
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = if (isSent) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.primary,
                    modifier = Modifier.padding(vertical = 9.dp).fillMaxWidth(),
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
