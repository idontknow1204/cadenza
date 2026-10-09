package com.cadenza.android.ui.org

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Album
import androidx.compose.material.icons.outlined.Apartment
import androidx.compose.material.icons.outlined.Business
import androidx.compose.material.icons.outlined.Group
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.School
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.cadenza.android.core.data.model.OrgCategory
import com.cadenza.android.core.data.model.Organization
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.feed.components.ActivityCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OrgPageScreen(
    orgId: String,
    onBack: () -> Unit,
    onNavigateToUser: (String) -> Unit = {},
    session: SessionViewModel = hiltViewModel(),
    viewModel: OrgPageViewModel = hiltViewModel(),
) {
    val org by viewModel.org.collectAsState()
    val activities by viewModel.activities.collectAsState()
    val followerCount by viewModel.followerCount.collectAsState()
    val isFollowing by viewModel.isFollowing.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val followBusy by viewModel.followBusy.collectAsState()

    LaunchedEffect(orgId) { viewModel.load(orgId, session.currentUserId) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(org?.name ?: AppLocale.localized("기관 페이지", "Organization", "Organisation")) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                    }
                },
                windowInsets = WindowInsets.statusBars,
            )
        },
        contentWindowInsets = WindowInsets(0),
    ) { innerPadding ->
        PullToRefreshBox(
            isRefreshing = isLoading && org != null,
            onRefresh = { viewModel.load(orgId, session.currentUserId) },
            modifier = Modifier.fillMaxSize().padding(innerPadding),
        ) {
            when {
                isLoading && org == null -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                org != null -> {
                    LazyColumn(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
                        item("header") {
                            OrgHeader(
                                org = org!!,
                                followerCount = followerCount,
                                isFollowing = isFollowing,
                                followBusy = followBusy,
                                onToggleFollow = {
                                    session.currentUserId?.let { uid ->
                                        viewModel.toggleFollow(orgId, uid)
                                    }
                                },
                            )
                        }
                        item("divider") { HorizontalDivider() }
                        if (activities.isEmpty() && !isLoading) {
                            item("empty") {
                                Box(Modifier.fillMaxWidth().padding(48.dp), contentAlignment = Alignment.Center) {
                                    Text(AppLocale.localized("아직 게시물이 없습니다", "No posts yet", "Noch keine Beiträge"), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        }
                        itemsIndexed(activities, key = { _, item -> item.id }) { idx, item ->
                            if (idx > 0) HorizontalDivider(thickness = 8.dp, color = MaterialTheme.colorScheme.surfaceVariant)
                            ActivityCard(
                                item = item,
                                repository = viewModel.repository,
                                connectionStore = viewModel.connectionStore,
                                currentUserId = session.currentUserId,
                                onNavigateToUser = onNavigateToUser,
                                onNavigateToOrg = { /* already here */ },
                            )
                        }
                        item { Spacer(Modifier.height(24.dp)) }
                    }
                }
                else -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text(AppLocale.localized("기관 정보를 불러오지 못했어요", "Failed to load organization", "Organisation konnte nicht geladen werden"), style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }
        }
    }
}

// ─── Header ───────────────────────────────────────────────────────────────────

@Composable
private fun OrgHeader(
    org: Organization,
    followerCount: Int,
    isFollowing: Boolean,
    followBusy: Boolean,
    onToggleFollow: () -> Unit,
) {
    val uriHandler = LocalUriHandler.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            OrgAvatarView(category = org.category, size = 64.dp)
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(org.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Text(org.category?.label ?: AppLocale.localized("기관", "Organization", "Organisation"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                val website = org.websiteUrl
                if (!website.isNullOrEmpty()) {
                    Text(
                        website,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.clickable { runCatching { uriHandler.openUri(website) } },
                    )
                }
            }
        }

        if (!org.bio.isNullOrEmpty()) {
            Text(org.bio, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Outlined.Group, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(
                " ${AppLocale.localized("${followerCount}명 팔로워", "$followerCount followers", "$followerCount Follower")}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.weight(1f),
            )
            if (isFollowing) {
                OutlinedButton(
                    onClick = onToggleFollow,
                    enabled = !followBusy,
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp, vertical = 7.dp),
                ) { Text(AppLocale.localized("팔로잉", "Following", "Folgt"), style = MaterialTheme.typography.labelMedium) }
            } else {
                Button(
                    onClick = onToggleFollow,
                    enabled = !followBusy,
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp, vertical = 7.dp),
                ) { Text(AppLocale.localized("팔로우", "Follow", "Folgen"), style = MaterialTheme.typography.labelMedium) }
            }
        }
    }
}

// ─── Org avatar ───────────────────────────────────────────────────────────────

@Composable
fun OrgAvatarView(category: OrgCategory?, size: Dp = 42.dp) {
    val (icon, color) = orgIconAndColor(category)
    Box(
        modifier = Modifier
            .size(size)
            .clip(RoundedCornerShape(size * 0.22f))
            .background(color.copy(alpha = 0.15f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon,
            contentDescription = null,
            modifier = Modifier.size(size * 0.4f),
            tint = color,
        )
    }
}

fun orgIconAndColor(category: OrgCategory?): Pair<ImageVector, Color> = when (category) {
    OrgCategory.ORCHESTRA -> Icons.Outlined.MusicNote to Color(0xFF9C27B0)
    OrgCategory.SCHOOL    -> Icons.Outlined.School    to Color(0xFF1565C0)
    OrgCategory.LABEL     -> Icons.Outlined.Album     to Color(0xFFE65100)
    OrgCategory.VENUE     -> Icons.Outlined.Apartment to Color(0xFF2E7D32)
    OrgCategory.AGENCY    -> Icons.Outlined.Business  to Color(0xFFAD1457)
    OrgCategory.OTHER,
    null                  -> Icons.Outlined.Group     to Color(0xFF546E7A)
}
