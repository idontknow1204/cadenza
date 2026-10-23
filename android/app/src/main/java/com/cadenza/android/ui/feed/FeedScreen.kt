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
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.style.TextOverflow
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
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.AlertDialog
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
import com.cadenza.android.ui.common.CadenzaPullToRefresh
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.cadenza.android.core.data.model.Job
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.ui.jobs.JobDetailSheet
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
    val unreadNotificationCount by viewModel.unreadNotificationCount.collectAsState()
    val affiliations by viewModel.affiliations.collectAsState()
    var selectedJob by remember { mutableStateOf<Job?>(null) }
    val coroutineScope = rememberCoroutineScope()

    errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { viewModel.clearError() },
            title = { Text(AppLocale.localized("오류", "Error", "Fehler")) },
            text = { Text(message) },
            confirmButton = {
                TextButton(onClick = {
                    viewModel.clearError()
                    if (currentUserId != null) viewModel.refresh(currentUserId)
                }) { Text(AppLocale.localized("다시 시도", "Retry", "Erneut versuchen")) }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.clearError() }) {
                    Text(AppLocale.localized("확인", "OK", "OK"))
                }
            },
        )
    }

    val listState = rememberLazyListState()
    var searchFocused by remember { mutableStateOf(false) }
    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(currentUserId) {
        if (currentUserId != null) {
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
            modifier = Modifier.weight(1f),
        ) {
            // 탭바가 콘텐츠 위에 떠 있으므로, 목록 하단을 비워 마지막 항목이 가리지 않게 한다
            val listBottomPad = PaddingValues(bottom = contentPadding.calculateBottomPadding())
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
                                Text(AppLocale.localized("검색 결과가 없어요", "No results", "Keine Ergebnisse"),
                                    style = MaterialTheme.typography.bodyLarge,
                                    modifier = Modifier.padding(top = 8.dp))
                            }
                        }
                    } else {
                        LazyColumn(contentPadding = listBottomPad) {
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
                                        showMetadataLine = false,
                                        onNavigateToUser = onNavigateToUser,
                                        onNavigateToOrg = onNavigateToOrg,
                                        authorAffiliation = affiliations[act.author?.id],
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
                                item { SearchSectionHeader(AppLocale.localized("채용", "Jobs", "Stellen")) }
                                items(searchJobs) { job ->
                                    Row(
                                        modifier = Modifier
                                            .fillMaxWidth()
                                            .clickable { selectedJob = job }
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
                    LazyColumn(contentPadding = listBottomPad) {
                        if (recentSearches.isNotEmpty()) {
                            item {
                                Row(
                                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(AppLocale.localized("최근 검색", "Recent", "Zuletzt gesucht"),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.weight(1f),
                                    )
                                    TextButton(onClick = { viewModel.clearRecent() }) {
                                        Text(AppLocale.localized("지우기", "Clear", "Löschen"),
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
                                        modifier = Modifier.size(48.dp),
                                    ) {
                                        Icon(Icons.Default.Close,
                                            contentDescription = AppLocale.localized("삭제", "Remove", "Entfernen"),
                                            modifier = Modifier.size(14.dp),
                                            tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                HorizontalDivider(modifier = Modifier.padding(start = 16.dp))
                            }
                        }
                        if (suggestedProfiles.isNotEmpty()) {
                            item { SearchSectionHeader(AppLocale.localized("추천 프로필", "Suggested", "Vorschläge")) }
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
                                            p.mutualCount > 0 -> AppLocale.localized(
                                                "${p.mutualCount}명의 공통 연결",
                                                "${p.mutualCount} mutual connections",
                                                "${p.mutualCount} gemeinsame Kontakte",
                                            )
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
                    CadenzaPullToRefresh(
                        isRefreshing = isLoading && items.isNotEmpty(),
                        onRefresh = { if (currentUserId != null) viewModel.refresh(currentUserId) },
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        if (isLoading && items.isEmpty()) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator()
                            }
                        } else if (items.isEmpty()) {
                            // 스크롤 가능한 컨테이너여야 당겨서 새로고침이 동작한다
                            LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = listBottomPad) {
                                item {
                                    Column(
                                        modifier = Modifier.fillParentMaxSize().padding(horizontal = 32.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally,
                                        verticalArrangement = Arrangement.Center,
                                    ) {
                                        Icon(Icons.Outlined.MusicNote, contentDescription = null,
                                            modifier = Modifier.size(48.dp), tint = MaterialTheme.colorScheme.outlineVariant)
                                        Text(AppLocale.localized("아직 기록이 없어요", "No activity yet", "Noch keine Aktivität"),
                                            style = MaterialTheme.typography.titleMedium,
                                            modifier = Modifier.padding(top = 8.dp))
                                        Text(
                                            AppLocale.localized(
                                                "함께한 사람을 태그해 첫 기록을 남겨보세요.",
                                                "Tag a collaborator to make your first record.",
                                                "Markiere Mitwirkende für deinen ersten Eintrag.",
                                            ),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            textAlign = TextAlign.Center,
                                            modifier = Modifier.padding(top = 4.dp),
                                        )
                                    }
                                }
                            }
                        } else {
                            LazyColumn(state = listState, contentPadding = listBottomPad, modifier = Modifier.background(MaterialTheme.colorScheme.background)) {
                                items(items, key = { it.id }) { item ->
                                    ActivityCard(
                                        item = item,
                                        repository = viewModel.repository,
                                        connectionStore = viewModel.connectionStore,
                                        currentUserId = currentUserId,
                                        showMetadataLine = false,
                                        onNavigateToUser = onNavigateToUser,
                                        onNavigateToOrg = onNavigateToOrg,
                                        onDeleted = { viewModel.remove(item.id) },
                                        authorAffiliation = affiliations[item.author?.id],
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

    selectedJob?.let { job ->
        JobDetailSheet(
            job = job,
            isOwner = currentUserId != null && job.userId == currentUserId,
            onDismiss = { selectedJob = null },
            onJobClosed = {
                coroutineScope.launch { runCatching { viewModel.repository.closeJob(job.id) } }
                selectedJob = null
            },
        )
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
            .padding(top = 24.dp, bottom = 14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // iOS FeedHeader: logo + title in HStack(spacing:7)
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(7.dp),
                // 로고+타이틀만 5dp 아래로 (버튼들은 그대로)
                modifier = Modifier.weight(1f).offset(y = 5.dp),
            ) {
                Image(
                    painter = painterResource(R.drawable.cadenza_logo),
                    contentDescription = null,
                    contentScale = ContentScale.Fit,
                    modifier = Modifier
                        .size(34.dp)
                        .background(Color.White, RoundedCornerShape(7.dp)),
                )
                Text(
                    text = "Cadenza",
                    style = MaterialTheme.typography.titleLarge.copy(
                        fontSize = 25.sp,
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
                IconButton(onClick = onNotifications, modifier = Modifier.size(46.dp)) {
                    Icon(Icons.Outlined.Notifications,
                        contentDescription = AppLocale.localized("알림", "Notifications", "Benachrichtigungen"),
                        modifier = Modifier.size(27.dp))
                }
            }
            Spacer(Modifier.width(4.dp))
            Surface(
                onClick = onCreateActivity,
                shape = RoundedCornerShape(8.dp),
                color = CadenzaAccent.copy(alpha = 0.1f),
                modifier = Modifier.size(46.dp),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.Outlined.EditNote,
                        contentDescription = AppLocale.localized("활동 기록", "Record activity", "Aktivität"),
                        tint = CadenzaAccent,
                        // EditNote 글리프의 잉크 중심 쏠림 보정 (수동 조정값)
                        modifier = Modifier.size(26.dp).offset(x = 2.5.dp, y = 1.5.dp),
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
            // M3 TextField는 최소 높이 56dp라 44dp 바 안에서 세로 중앙이 어긋나므로 BasicTextField 사용
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                    ) { focusRequester.requestFocus() }
                    .padding(horizontal = 9.dp),
                contentAlignment = Alignment.CenterStart,
            ) {
                if (searchQuery.isEmpty()) {
                    Text(
                        AppLocale.localized("사람, 활동 검색", "Search people or activities", "Personen oder Aktivitäten suchen"),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                BasicTextField(
                    value = searchQuery,
                    onValueChange = onSearchQueryChange,
                    modifier = Modifier
                        .fillMaxWidth()
                        .focusRequester(focusRequester)
                        .onFocusChanged { onFocusChange(it.isFocused) },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodyMedium.copy(color = MaterialTheme.colorScheme.onSurface),
                    cursorBrush = SolidColor(CadenzaAccent),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    keyboardActions = KeyboardActions(onSearch = { onSearchSubmit(searchQuery) }),
                )
            }
            if (searchQuery.isNotEmpty() || searchFocused) {
                IconButton(onClick = onClearSearch, modifier = Modifier.size(44.dp)) {
                    Icon(Icons.Default.Close,
                        contentDescription = AppLocale.localized("지우기", "Clear", "Löschen"),
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
