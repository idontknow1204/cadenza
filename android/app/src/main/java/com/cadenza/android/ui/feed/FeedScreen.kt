package com.cadenza.android.ui.feed

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.res.painterResource
import com.cadenza.android.R
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.ui.common.UserAvatarView
import com.cadenza.android.ui.feed.components.ActivityCard
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.theme.CadenzaAccent

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedScreen(
    contentPadding: PaddingValues = PaddingValues(),
    session: SessionViewModel,
    viewModel: FeedViewModel = hiltViewModel(),
    unreadNotificationCount: Int = 0,
    onNotifications: () -> Unit = {},
    onCreateActivity: () -> Unit = {},
    onNavigateToUser: (String) -> Unit = {},
    onNavigateToOrg: (String) -> Unit = {},
) {
    val currentUserId = session.currentUserId
    val items by viewModel.items.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val errorMessage by viewModel.errorMessage.collectAsState()
    val searchQuery by viewModel.searchQuery.collectAsState()
    val searchActive by viewModel.searchActive.collectAsState()
    val searchPeople by viewModel.searchPeople.collectAsState()
    val searchActivities by viewModel.searchActivities.collectAsState()
    val searchJobs by viewModel.searchJobs.collectAsState()
    val isSearching by viewModel.isSearching.collectAsState()
    val suggestedProfiles by viewModel.suggestedProfiles.collectAsState()
    val recentSearches by viewModel.recentSearches.collectAsState()

    val listState = rememberLazyListState()
    var searchFocused by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()

    LaunchedEffect(currentUserId) {
        if (currentUserId != null) {
            viewModel.connectionStore.reset(currentUserId)
            viewModel.connectionStore.refresh(scope = coroutineScope)
            viewModel.refresh(currentUserId)
        }
    }

    val isSearchMode = searchQuery.trim().isNotEmpty()

    Column(modifier = Modifier.fillMaxSize()) {
        // Custom header
        FeedHeader(
            searchQuery = searchQuery,
            onSearchQueryChange = { q ->
                viewModel.setSearchQuery(q, currentUserId ?: "")
            },
            onSearchSubmit = { q ->
                viewModel.addRecent(q)
                searchFocused = false
            },
            onClearSearch = {
                viewModel.setSearchQuery("", currentUserId ?: "")
                searchFocused = false
            },
            searchFocused = searchFocused,
            onFocusChange = { focused ->
                searchFocused = focused
                if (focused && currentUserId != null) {
                    viewModel.setSearchActive(true, currentUserId)
                } else if (!focused && searchQuery.trim().isEmpty()) {
                    viewModel.setSearchActive(false, currentUserId ?: "")
                }
            },
            focusRequester = focusRequester,
            unreadCount = unreadNotificationCount,
            onNotifications = onNotifications,
            onCreateActivity = onCreateActivity,
        )
        HorizontalDivider()

        Box(
            modifier = Modifier
                .weight(1f)
                .padding(bottom = contentPadding.calculateBottomPadding()),
        ) {
            when {
                isSearchMode -> {
                    // Search results
                    if (isSearching) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    } else if (searchPeople.isEmpty() && searchActivities.isEmpty() && searchJobs.isEmpty()) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Outlined.Search, contentDescription = null,
                                    modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.outlineVariant)
                                Text(AppLocale.localized("검색 결과가 없습니다", "No results", "Keine Ergebnisse"),
                                    style = MaterialTheme.typography.bodyLarge,
                                    modifier = Modifier.padding(top = 8.dp))
                            }
                        }
                    } else {
                        LazyColumn {
                            if (searchPeople.isNotEmpty()) {
                                item {
                                    SearchSectionHeader(AppLocale.localized("사람", "People", "Personen"))
                                }
                                items(searchPeople) { p ->
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { onNavigateToUser(p.id) }
                                            .padding(horizontal = 16.dp, vertical = 8.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        UserAvatarView(url = p.avatarUrl, name = p.realName, size = 36.dp)
                                        Spacer(Modifier.width(10.dp))
                                        Column {
                                            Text(p.realName, style = MaterialTheme.typography.bodyMedium)
                                            p.instrument?.let {
                                                Text(it, style = MaterialTheme.typography.bodySmall,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            }
                                        }
                                    }
                                    HorizontalDivider(modifier = Modifier.padding(start = 62.dp))
                                }
                            }
                            if (searchActivities.isNotEmpty()) {
                                item { SearchSectionHeader(AppLocale.localized("활동", "Activities", "Aktivitäten")) }
                                items(searchActivities) { act ->
                                    ActivityCard(
                                        item = act,
                                        repository = viewModel.repository,
                                        connectionStore = viewModel.connectionStore,
                                        currentUserId = currentUserId,
                                        onNavigateToUser = onNavigateToUser,
                                        onNavigateToOrg = onNavigateToOrg,
                                    )
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(6.dp)
                                            .background(MaterialTheme.colorScheme.background),
                                    )
                                }
                            }
                            if (searchJobs.isNotEmpty()) {
                                item { SearchSectionHeader(AppLocale.localized("공고", "Jobs", "Stellen")) }
                                items(searchJobs) { job ->
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { /* TODO: job detail */ }
                                            .padding(horizontal = 16.dp, vertical = 8.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Column(modifier = Modifier.weight(1f)) {
                                            Text(job.title, style = MaterialTheme.typography.bodyMedium)
                                            Text(
                                                "${job.type.label}${job.organization?.let { " · $it" } ?: ""}",
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        }
                                    }
                                    HorizontalDivider()
                                }
                            }
                        }
                    }
                }

                searchActive -> {
                    // Search idle (recent + suggested)
                    LazyColumn {
                        if (recentSearches.isNotEmpty()) {
                            item {
                                Row(
                                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(AppLocale.localized("최근 검색", "Recent", "Zuletzt"),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.weight(1f),
                                    )
                                    TextButton(onClick = { viewModel.clearRecent() }) {
                                        Text(AppLocale.localized("모두 삭제", "Clear all", "Alle löschen"),
                                            style = MaterialTheme.typography.labelSmall)
                                    }
                                }
                            }
                            items(recentSearches) { term ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { viewModel.setSearchQuery(term, currentUserId ?: "") }
                                        .padding(horizontal = 16.dp, vertical = 12.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(term, modifier = Modifier.weight(1f))
                                    IconButton(
                                        onClick = { viewModel.removeRecent(term) },
                                        modifier = Modifier.size(32.dp),
                                    ) {
                                        Icon(Icons.Default.Close, contentDescription = "삭제",
                                            modifier = Modifier.size(14.dp),
                                            tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                HorizontalDivider(modifier = Modifier.padding(start = 16.dp))
                            }
                        }
                        if (suggestedProfiles.isNotEmpty()) {
                            item { SearchSectionHeader(AppLocale.localized("추천 사람", "Suggested", "Vorschläge")) }
                            items(suggestedProfiles) { p ->
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable { onNavigateToUser(p.id) }
                                        .padding(horizontal = 16.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    UserAvatarView(url = p.avatarUrl, name = p.realName, size = 36.dp)
                                    Spacer(Modifier.width(10.dp))
                                    Column {
                                        Text(p.realName, style = MaterialTheme.typography.bodyMedium)
                                        val sub = when {
                                            p.mutualCount > 0 -> "${p.mutualCount}명의 공통 연결"
                                            p.instrument != null -> p.instrument
                                            else -> null
                                        }
                                        sub?.let {
                                            Text(it, style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                    }
                                }
                                HorizontalDivider(modifier = Modifier.padding(start = 62.dp))
                            }
                        }
                    }
                }

                else -> {
                    // Feed list
                    PullToRefreshBox(
                        isRefreshing = isLoading && items.isNotEmpty(),
                        onRefresh = { if (currentUserId != null) viewModel.refresh(currentUserId) },
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        if (isLoading && items.isEmpty()) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator()
                            }
                        } else if (items.isEmpty()) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Icon(Icons.Outlined.Notifications, contentDescription = null,
                                        modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.outlineVariant)
                                    Text(AppLocale.localized("아직 피드가 비어있어요", "Feed is empty", "Feed ist leer"),
                                        style = MaterialTheme.typography.bodyLarge,
                                        modifier = Modifier.padding(top = 8.dp))
                                    Text(AppLocale.localized("다른 사람들과 연결해 보세요", "Connect with others", "Verbinde dich"),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                                }
                            }
                        } else {
                            LazyColumn(state = listState, modifier = Modifier.background(MaterialTheme.colorScheme.background)) {
                                items(items, key = { it.id }) { item ->
                                    ActivityCard(
                                        item = item,
                                        repository = viewModel.repository,
                                        connectionStore = viewModel.connectionStore,
                                        currentUserId = currentUserId,
                                        onNavigateToUser = onNavigateToUser,
                                        onNavigateToOrg = onNavigateToOrg,
                                        onDeleted = { viewModel.remove(item.id) },
                                    )
                                    // Post separator
                                    Box(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .height(6.dp)
                                            .background(MaterialTheme.colorScheme.background),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FeedHeader(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    onSearchSubmit: (String) -> Unit,
    onClearSearch: () -> Unit,
    searchFocused: Boolean,
    onFocusChange: (Boolean) -> Unit,
    focusRequester: FocusRequester,
    unreadCount: Int,
    onNotifications: () -> Unit,
    onCreateActivity: () -> Unit,
) {
    // iOS CadenzaBrowseHeader: .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 14)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .windowInsetsPadding(WindowInsets.statusBars)
            .padding(horizontal = 16.dp)
            .padding(top = 4.dp, bottom = 14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // iOS FeedHeader: logo + title in HStack(spacing:7)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(7.dp),
                modifier = Modifier.weight(1f),
            ) {
                Image(
                    painter = painterResource(R.drawable.cadenza_logo),
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .size(30.dp)
                        .background(Color.White, RoundedCornerShape(6.dp)),
                )
                Text(
                    text = "Cadenza",
                    style = MaterialTheme.typography.titleLarge.copy(
                        color = MaterialTheme.colorScheme.onSurface,
                        fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                    ),
                )
            }
            BadgedBox(
                badge = {
                    if (unreadCount > 0) Badge(modifier = Modifier.size(7.dp))
                },
            ) {
                IconButton(onClick = onNotifications) {
                    Icon(Icons.Outlined.Notifications, contentDescription = "알림")
                }
            }
            Spacer(Modifier.width(4.dp))
            Surface(
                onClick = onCreateActivity,
                shape = RoundedCornerShape(8.dp),
                color = CadenzaAccent.copy(alpha = 0.1f),
                modifier = Modifier.size(44.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Outlined.Edit,
                        contentDescription = AppLocale.localized("활동 기록", "Record activity", "Aktivität"),
                        tint = CadenzaAccent,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
        }
        // iOS: VStack(spacing: 10) between title row and search
        Spacer(Modifier.height(10.dp))

        // Search field: iOS .frame(minHeight: 44) + .background(.tertiarySystemFill, RoundedRectangle(8))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(44.dp)
                .background(
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                    RoundedCornerShape(8.dp),
                ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // iOS: HStack(spacing: 9) inside search bar with .padding(.leading, 12)
            Icon(
                Icons.Outlined.Search,
                contentDescription = null,
                modifier = Modifier.padding(start = 12.dp).size(18.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            TextField(
                value = searchQuery,
                onValueChange = onSearchQueryChange,
                placeholder = { Text(AppLocale.localized("이름, 활동, 공고 검색", "Search name, activity, job", "Suchen…"), style = MaterialTheme.typography.bodySmall) },
                modifier = Modifier
                    .weight(1f)
                    .focusRequester(focusRequester)
                    .onFocusChanged { onFocusChange(it.isFocused) },
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = Color.Transparent,
                    unfocusedIndicatorColor = Color.Transparent,
                ),
                singleLine = true,
                textStyle = MaterialTheme.typography.bodySmall,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { onSearchSubmit(searchQuery) }),
            )
            if (searchQuery.isNotEmpty() || searchFocused) {
                IconButton(onClick = onClearSearch, modifier = Modifier.size(40.dp)) {
                    Icon(Icons.Default.Close, contentDescription = "지우기",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}

@Composable
private fun SearchSectionHeader(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
    )
}
