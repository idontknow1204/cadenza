package com.cadenza.android.ui.profile

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.background
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.IconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.Affiliation
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.model.Career
import com.cadenza.android.core.data.model.ConnectionAction
import com.cadenza.android.core.data.model.ConnectionStatus
import com.cadenza.android.core.data.model.Profile
import com.cadenza.android.core.data.model.ProfileAward
import com.cadenza.android.core.data.model.ProfileLanguage
import com.cadenza.android.core.data.model.ProfileSection
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.ConnectionStore
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.common.UserAvatarView
import com.cadenza.android.ui.profile.components.ActivityPager
import com.cadenza.android.ui.profile.components.AffiliationRow
import com.cadenza.android.ui.profile.components.CareerRow
import com.cadenza.android.ui.profile.components.SectionCard
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

// ── ViewModel ────────────────────────────────────────────────────────────────

@HiltViewModel
class PublicProfileViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    val repository: Repository,
    val connectionStore: ConnectionStore,
) : ViewModel() {

    val userId: String = savedStateHandle.get<String>("userId") ?: ""

    private val _profile = MutableStateFlow<Profile?>(null)
    val profile: StateFlow<Profile?> = _profile.asStateFlow()

    private val _activities = MutableStateFlow<List<ActivityWithAuthor>>(emptyList())
    val activities: StateFlow<List<ActivityWithAuthor>> = _activities.asStateFlow()

    private val _affiliations = MutableStateFlow<List<Affiliation>>(emptyList())
    val affiliations: StateFlow<List<Affiliation>> = _affiliations.asStateFlow()

    private val _careers = MutableStateFlow<List<Career>>(emptyList())
    val careers: StateFlow<List<Career>> = _careers.asStateFlow()

    private val _awards = MutableStateFlow<List<ProfileAward>>(emptyList())
    val awards: StateFlow<List<ProfileAward>> = _awards.asStateFlow()

    private val _languages = MutableStateFlow<List<ProfileLanguage>>(emptyList())
    val languages: StateFlow<List<ProfileLanguage>> = _languages.asStateFlow()

    private val _connectionCount = MutableStateFlow(0)
    val connectionCount: StateFlow<Int> = _connectionCount.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    init {
        if (userId.isNotEmpty()) load()
    }

    fun load() {
        if (userId.isEmpty()) return
        viewModelScope.launch {
            _isLoading.value = true
            try {
                coroutineScope {
                    val p   = async { runCatching { repository.profile(id = userId) }.getOrNull() }
                    val a   = async { runCatching { repository.activities(byAuthor = userId) }.getOrElse { emptyList() } }
                    val af  = async { runCatching { repository.affiliations(forUser = userId) }.getOrElse { emptyList() } }
                    val c   = async { runCatching { repository.careers(forUser = userId) }.getOrElse { emptyList() } }
                    val aw  = async { runCatching { repository.awards(forUser = userId) }.getOrElse { emptyList() } }
                    val l   = async { runCatching { repository.languages(forUser = userId) }.getOrElse { emptyList() } }
                    val cnt = async { runCatching { repository.connectionCount(userId = userId) }.getOrElse { 0 } }
                    _profile.value = p.await()
                    _activities.value = a.await()
                    _affiliations.value = af.await()
                    _careers.value = c.await()
                    _awards.value = aw.await()
                    _languages.value = l.await()
                    _connectionCount.value = cnt.await()
                }
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun reloadConnectionCount() {
        viewModelScope.launch {
            _connectionCount.value = runCatching { repository.connectionCount(userId = userId) }.getOrElse { 0 }
        }
    }
}

// ── Screen ───────────────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun PublicProfileScreen(
    userId: String,
    onBack: () -> Unit,
    onNavigateToUser: (String) -> Unit = {},
    session: SessionViewModel = hiltViewModel(),
    viewModel: PublicProfileViewModel = hiltViewModel(),
) {
    val profile by viewModel.profile.collectAsState()
    val activities by viewModel.activities.collectAsState()
    val affiliations by viewModel.affiliations.collectAsState()
    val careers by viewModel.careers.collectAsState()
    val awards by viewModel.awards.collectAsState()
    val languages by viewModel.languages.collectAsState()
    val connectionCount by viewModel.connectionCount.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    val statuses by viewModel.connectionStore.statuses.collectAsState()
    val updating by viewModel.connectionStore.updating.collectAsState()
    val hasLoaded by viewModel.connectionStore.hasLoaded.collectAsState()
    val connStatus = statuses[userId] ?: ConnectionStatus.None

    val currentUserId = session.currentUserId
    val isOwnProfile = currentUserId == userId
    val scope = rememberCoroutineScope()
    var showConnectionsList by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(profile?.realName ?: AppLocale.localized("프로필", "Profile", "Profil")) },
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
            isRefreshing = isLoading,
            onRefresh = { viewModel.load() },
            modifier = Modifier.padding(innerPadding),
        ) {
            if (isLoading && profile == null) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else {
                LazyColumn(
                    modifier = Modifier.background(MaterialTheme.colorScheme.background),
                    contentPadding = PaddingValues(
                        start = 0.dp, end = 0.dp,
                        // iOS: LazyVStack + .padding(.vertical, 12)
                        top = 12.dp,
                        bottom = 12.dp,
                    ),
                    // iOS: LazyVStack(spacing: 12)
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    profile?.let { p ->
                        item("header") {
                            SectionCard {
                                // iOS: HStack(alignment: .top, spacing: 14)
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                                    verticalAlignment = Alignment.Top,
                                    modifier = Modifier.fillMaxWidth(),
                                ) {
                                    // iOS: UserAvatarView(size: 68)
                                    UserAvatarView(url = p.avatarUrl, name = p.realName, size = 68.dp)
                                    // iOS: VStack(alignment: .leading, spacing: 3)
                                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                        // iOS: .font(.title2.bold()) = 22sp bold
                                        Text(p.realName, style = MaterialTheme.typography.headlineSmall)
                                        val subtitle = listOfNotNull(
                                            p.major?.let { OnboardingData.majorDisplay(it) },
                                            p.instrument?.let { OnboardingData.instrumentDisplay(it) },
                                        ).joinToString(" · ")
                                        if (subtitle.isNotEmpty()) {
                                            // iOS: .font(.subheadline).foregroundStyle(.secondary) = 15sp
                                            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                        if (affiliations.isNotEmpty()) {
                                            // iOS: .font(.subheadline).foregroundStyle(.secondary) = 15sp
                                            Text(affiliations.first().institutionName, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                    }
                                    if (!isOwnProfile) {
                                        ConnectionButton(
                                            status = connStatus,
                                            isUpdating = updating.contains(userId),
                                            hasLoaded = hasLoaded,
                                            onRequest = {
                                                scope.launch {
                                                    viewModel.connectionStore.perform(ConnectionAction.REQUEST, userId)
                                                }
                                            },
                                            onCancel = {
                                                scope.launch {
                                                    viewModel.connectionStore.perform(ConnectionAction.CANCEL, userId)
                                                    viewModel.reloadConnectionCount()
                                                }
                                            },
                                            onAccept = {
                                                scope.launch {
                                                    viewModel.connectionStore.perform(ConnectionAction.ACCEPT, userId)
                                                    viewModel.reloadConnectionCount()
                                                }
                                            },
                                            onDecline = {
                                                scope.launch {
                                                    viewModel.connectionStore.perform(ConnectionAction.DECLINE, userId)
                                                }
                                            },
                                            onDisconnect = {
                                                scope.launch {
                                                    viewModel.connectionStore.perform(ConnectionAction.DISCONNECT, userId)
                                                    viewModel.reloadConnectionCount()
                                                }
                                            },
                                        )
                                    }
                                }
                                // iOS: .padding(.top, 4) for connection row
                                Spacer(Modifier.height(4.dp))
                                // iOS: .font(.subheadline) = 15sp
                                Text(
                                    AppLocale.localized("${connectionCount}명과 연결됨", "Connected with $connectionCount", "Verbunden mit $connectionCount"),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.clickable(enabled = connectionCount > 0) { showConnectionsList = true },
                                )
                                if (p.homeCities.isNotEmpty()) {
                                    // iOS: .padding(.top, 3)
                                    Spacer(Modifier.height(3.dp))
                                    // iOS: FlowLayout(spacing: 6)
                                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                        p.homeCities.forEach { id ->
                                            val city = OnboardingData.cityOptions.firstOrNull { it.id == id }
                                            if (city != null) {
                                                // iOS: .font(.caption).padding(.horizontal, 8).padding(.vertical, 3).background(.secondary.opacity(0.1), Capsule)
                                                Surface(
                                                    shape = RoundedCornerShape(50),
                                                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f),
                                                ) {
                                                    Text(
                                                        city.localizedName,
                                                        style = MaterialTheme.typography.labelMedium,
                                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.BIO) && !p.bio.isNullOrEmpty()) {
                            item("bio") {
                                SectionCard(title = ProfileSection.BIO.title) {
                                    // iOS: .font(.subheadline).lineSpacing(3) = 15sp
                                    Text(p.bio!!, style = MaterialTheme.typography.bodyMedium)
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.EDUCATION) && affiliations.isNotEmpty()) {
                            item("education") {
                                SectionCard(title = ProfileSection.EDUCATION.title) {
                                    affiliations.forEachIndexed { i, aff ->
                                        AffiliationRow(affiliation = aff)
                                        if (i < affiliations.lastIndex) HorizontalDivider()
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.ACTIVITIES) && activities.isNotEmpty()) {
                            item("activities") {
                                SectionCard(title = ProfileSection.ACTIVITIES.title) {
                                    ActivityPager(activities = activities)
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.CAREER) && careers.isNotEmpty()) {
                            item("career") {
                                SectionCard(title = ProfileSection.CAREER.title) {
                                    careers.forEachIndexed { i, c ->
                                        CareerRow(career = c)
                                        if (i < careers.lastIndex) HorizontalDivider()
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.AWARDS) && awards.isNotEmpty()) {
                            item("awards") {
                                SectionCard(title = ProfileSection.AWARDS.title) {
                                    awards.forEachIndexed { i, award ->
                                        Column(
                                            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                                            verticalArrangement = Arrangement.spacedBy(4.dp),
                                        ) {
                                            Text(award.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
                                            Text(award.prize, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                            Text("${award.issuer} · ${award.year}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
                                        }
                                        if (i < awards.lastIndex) HorizontalDivider()
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.LANGUAGES) && languages.isNotEmpty()) {
                            item("languages") {
                                SectionCard(title = ProfileSection.LANGUAGES.title) {
                                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        languages.forEach { lang ->
                                            val levelLabel = when (lang.level) {
                                                "native"       -> AppLocale.localized("모국어", "Native",        "Muttersprache")
                                                "fluent"       -> AppLocale.localized("유창",   "Fluent",        "Fließend")
                                                "intermediate" -> AppLocale.localized("중급",   "Intermediate",  "Mittel")
                                                else           -> AppLocale.localized("기초",   "Basic",         "Grundkenntnisse")
                                            }
                                            SuggestionChip(
                                                onClick = {},
                                                label = {
                                                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                                        Text(lang.language, style = MaterialTheme.typography.labelMedium)
                                                        Text(levelLabel, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                                    }
                                                },
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
    }

    if (showConnectionsList) {
        ConnectionsListSheet(
            userId = userId,
            repository = viewModel.repository,
            onNavigateToUser = { targetId -> showConnectionsList = false; onNavigateToUser(targetId) },
            onDismiss = { showConnectionsList = false },
        )
    }
}

// ── Connection button ────────────────────────────────────────────────────────

@Composable
private fun ConnectionButton(
    status: ConnectionStatus,
    isUpdating: Boolean,
    hasLoaded: Boolean,
    onRequest: () -> Unit,
    onCancel: () -> Unit,
    onAccept: () -> Unit,
    onDecline: () -> Unit,
    onDisconnect: () -> Unit,
) {
    val disabled = isUpdating || !hasLoaded
    when (status) {
        is ConnectionStatus.None -> {
            Button(
                onClick = onRequest,
                enabled = !disabled,
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 7.dp),
            ) {
                if (isUpdating) {
                    CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                } else {
                    Text(AppLocale.localized("연결", "Connect", "Verbinden"), style = MaterialTheme.typography.labelMedium)
                }
            }
        }
        is ConnectionStatus.RequestSent -> {
            OutlinedButton(
                onClick = onCancel,
                enabled = !disabled,
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 7.dp),
            ) {
                Text(AppLocale.localized("요청 보냄", "Requested", "Angefragt"), style = MaterialTheme.typography.labelMedium)
            }
        }
        is ConnectionStatus.RequestReceived -> {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(
                    onClick = onAccept,
                    enabled = !disabled,
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 7.dp),
                ) {
                    Text(AppLocale.localized("수락", "Accept", "Annehmen"), style = MaterialTheme.typography.labelMedium)
                }
                OutlinedButton(
                    onClick = onDecline,
                    enabled = !disabled,
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 7.dp),
                ) {
                    Text(AppLocale.localized("거절", "Decline", "Ablehnen"), style = MaterialTheme.typography.labelMedium)
                }
            }
        }
        is ConnectionStatus.Connected -> {
            OutlinedButton(
                onClick = onDisconnect,
                enabled = !disabled,
                contentPadding = PaddingValues(horizontal = 14.dp, vertical = 7.dp),
            ) {
                Text(AppLocale.localized("연결됨", "Connected", "Verbunden"), style = MaterialTheme.typography.labelMedium)
            }
        }
    }
}
