package com.cadenza.android.ui.jobs

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.FilterList
import androidx.compose.material.icons.outlined.MicNone
import androidx.compose.material.icons.outlined.School
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Videocam
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.cadenza.android.core.data.model.Job
import com.cadenza.android.core.data.model.JobType
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JobsScreen(
    contentPadding: PaddingValues = PaddingValues(),
    session: SessionViewModel,
    viewModel: JobsViewModel = hiltViewModel(),
) {
    val jobs            by viewModel.jobs.collectAsState()
    val cityById        by viewModel.cityById.collectAsState()
    val baseCityIds     by viewModel.baseCityIds.collectAsState()
    val isLoading       by viewModel.isLoading.collectAsState()
    val loadError       by viewModel.loadError.collectAsState()
    val searchResults   by viewModel.searchResults.collectAsState()
    val isSearchLoading by viewModel.isSearchLoading.collectAsState()
    val searchError     by viewModel.searchError.collectAsState()
    val filter          by viewModel.filter.collectAsState()
    val sort            by viewModel.sort.collectAsState()
    val userProfile     by session.profile.collectAsState()

    var searchQuery     by remember { mutableStateOf("") }
    var searchActive    by remember { mutableStateOf(false) }
    var showCreateSheet by remember { mutableStateOf(false) }
    var showFilterSheet by remember { mutableStateOf(false) }
    var selectedJob     by remember { mutableStateOf<Job?>(null) }

    val userId = session.currentUserId

    LaunchedEffect(userId) { userId?.let { viewModel.load(it) } }
    LaunchedEffect(searchQuery) { viewModel.search(searchQuery.trim()) }

    val isSearching  = searchQuery.trim().isNotEmpty()
    val displayJobs  = if (isSearching) searchResults else jobs
    val filteredJobs = filter.apply(displayJobs, cityById)
    val waitingSearch = isSearching && isSearchLoading

    val sections: List<JobSection> =
        if (sort == JobSort.CITY_FIRST && !isSearching)
            JobSection.build(filteredJobs, baseCityIds, cityById)
        else emptyList()

    val flatJobs: List<Job> =
        if (sections.isEmpty()) filteredJobs.sortedWith(Comparator { a, b ->
            if (sort == JobSort.RECENT)
                (b.createdAt ?: "").compareTo(a.createdAt ?: "")
            else {
                fun key(j: Job) = j.daysLeft?.let { if (it < 0) Int.MAX_VALUE - 1 else it } ?: Int.MAX_VALUE
                val ka = key(a); val kb = key(b)
                if (ka != kb) ka.compareTo(kb) else (b.createdAt ?: "").compareTo(a.createdAt ?: "")
            }
        }) else emptyList()

    val availableCountries = remember(jobs, searchResults, cityById) {
        (jobs + searchResults).mapNotNull { j -> j.cityId?.let { cityById[it]?.countryCode } }.distinct().sorted()
    }

    Scaffold(
        topBar = {
            Column {
                TopAppBar(
                    title = { Text(AppLocale.localized("채용", "Jobs", "Stellen")) },
                    actions = {
                        IconButton(onClick = {
                            searchActive = !searchActive
                            if (!searchActive) searchQuery = ""
                        }) {
                            Icon(if (searchActive) Icons.Outlined.Close else Icons.Outlined.Search, contentDescription = null)
                        }
                        FilledTonalIconButton(onClick = { showCreateSheet = true }) {
                            Icon(Icons.Default.Add, contentDescription = null)
                        }
                    },
                )
                if (searchActive) {
                    OutlinedTextField(
                        value = searchQuery,
                        onValueChange = { searchQuery = it },
                        placeholder = { Text(AppLocale.localized("기관·악기·도시 검색", "Search institution, instrument, city", "Suchen…"), style = MaterialTheme.typography.bodyMedium) },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                        trailingIcon = {
                            if (searchQuery.isNotEmpty()) {
                                IconButton(onClick = { searchQuery = "" }) {
                                    Icon(Icons.Outlined.Close, contentDescription = null, modifier = Modifier.size(18.dp))
                                }
                            }
                        },
                    )
                }
                JobFilterBar(
                    filter = filter,
                    myInstrument = userProfile?.instrument,
                    onOpenFilter = { showFilterSheet = true },
                    onToggleOpenOnly = { viewModel.updateFilter(filter.copy(openOnly = !filter.openOnly)) },
                    onToggleMyInstrument = { inst ->
                        val newInsts = if (filter.instruments == setOf(inst)) emptySet() else setOf(inst)
                        viewModel.updateFilter(filter.copy(instruments = newInsts))
                    },
                    onToggleVideoOnly = { viewModel.updateFilter(filter.copy(videoOnly = !filter.videoOnly)) },
                )
                HorizontalDivider()
            }
        },
    ) { innerPadding ->
        PullToRefreshBox(
            isRefreshing = isLoading && jobs.isNotEmpty(),
            onRefresh = { userId?.let { viewModel.load(it) } },
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(bottom = contentPadding.calculateBottomPadding()),
        ) {
            // 배경을 카드와 같은 surface로 두어, 목록 끝/짧은 목록에서 탭바 위에 회색 띠가 남지 않게 한다
            // (섹션 제목은 자체 배경색을 가지고 있어 그대로 회색 구분줄 역할)
            LazyColumn(modifier = Modifier.fillMaxSize().background(MaterialTheme.colorScheme.surface)) {
                when {
                    waitingSearch || (isLoading && jobs.isEmpty() && !isSearching) -> {
                        item {
                            Box(Modifier.fillMaxWidth().padding(top = 60.dp), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator()
                            }
                        }
                    }
                    filteredJobs.isEmpty() -> {
                        item {
                            EmptyJobsState(
                                isSearching = isSearching,
                                hasFilter = filter.activeCount > 0,
                                hasError = (if (isSearching) searchError else loadError) != null,
                                errorMessage = if (isSearching) searchError else loadError,
                                onResetFilter = { viewModel.updateFilter(JobFilter()) },
                                onClearSearch = { searchQuery = "" },
                                onRetry = { userId?.let { viewModel.load(it) } },
                                onCreate = { showCreateSheet = true },
                            )
                        }
                    }
                    sections.isNotEmpty() -> {
                        sections.forEach { section ->
                            item(key = "header-${section.id}") { SectionHeader(section) }
                            items(section.jobs, key = { it.id }) { job ->
                                JobCard(job = job, onClick = { selectedJob = job })
                                HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                            }
                        }
                    }
                    else -> {
                        items(flatJobs, key = { it.id }) { job ->
                            JobCard(job = job, onClick = { selectedJob = job })
                            HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                        }
                    }
                }
            }
        }
    }

    selectedJob?.let { job ->
        JobDetailSheet(
            job = job,
            isOwner = userId != null && job.userId == userId,
            onDismiss = { selectedJob = null },
            onJobClosed = {
                viewModel.closeJob(job.id) {}
                selectedJob = null
            },
        )
    }

    if (showCreateSheet) {
        CreateJobSheet(
            userId = userId ?: "",
            repository = viewModel.repository,
            onDismiss = { showCreateSheet = false },
            onPosted = {
                showCreateSheet = false
                userId?.let { viewModel.load(it) }
            },
        )
    }

    if (showFilterSheet) {
        JobFilterSheet(
            filter = filter,
            sort = sort,
            myInstrument = userProfile?.instrument,
            availableCountries = availableCountries,
            onDismiss = { showFilterSheet = false },
            onApply = { f, s ->
                viewModel.updateFilter(f)
                viewModel.updateSort(s)
                showFilterSheet = false
            },
        )
    }
}

// ─── Filter bar ───────────────────────────────────────────────────────────────

@Composable
private fun JobFilterBar(
    filter: JobFilter,
    myInstrument: String?,
    onOpenFilter: () -> Unit,
    onToggleOpenOnly: () -> Unit,
    onToggleMyInstrument: (String) -> Unit,
    onToggleVideoOnly: () -> Unit,
) {
    // iOS filterBar: .padding(.horizontal, 16).padding(.vertical, 4) + HStack(spacing: 8)
    Row(
        modifier = Modifier
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val badge = if (filter.activeCount > 0) filter.activeCount.toString() else null
        JobQuickChip(
            label = if (badge != null)
                AppLocale.localized("필터 $badge", "Filters ($badge)", "Filter ($badge)")
            else
                AppLocale.localized("필터", "Filters", "Filter"),
            icon = Icons.Outlined.FilterList,
            selected = filter.activeCount > 0,
            onClick = onOpenFilter,
        )
        if (!myInstrument.isNullOrEmpty()) {
            JobQuickChip(
                label = OnboardingData.instrumentDisplay(myInstrument),
                icon = Icons.Default.MusicNote,
                selected = filter.instruments == setOf(myInstrument),
                onClick = { onToggleMyInstrument(myInstrument) },
            )
        }
        JobQuickChip(
            label = AppLocale.localized("모집 중", "Open", "Offen"),
            icon = Icons.Outlined.School,
            selected = filter.openOnly,
            onClick = onToggleOpenOnly,
        )
        JobQuickChip(
            label = AppLocale.localized("영상 예선", "Video round", "Video-Vorrunde"),
            icon = Icons.Outlined.Videocam,
            selected = filter.videoOnly,
            onClick = onToggleVideoOnly,
        )
    }
}

@Composable
private fun JobQuickChip(
    label: String,
    icon: ImageVector,
    selected: Boolean,
    onClick: () -> Unit,
) {
    AssistChip(
        onClick = onClick,
        label = { Text(label, style = MaterialTheme.typography.bodyMedium) },
        leadingIcon = { Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp)) },
        colors = if (selected)
            AssistChipDefaults.assistChipColors(
                containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                labelColor = MaterialTheme.colorScheme.primary,
                leadingIconContentColor = MaterialTheme.colorScheme.primary,
            )
        else AssistChipDefaults.assistChipColors(),
    )
}

// ─── Section header ───────────────────────────────────────────────────────────

@Composable
private fun SectionHeader(section: JobSection) {
    val icon: ImageVector = when (section.kind) {
        JobSection.Kind.BASE_CITY, JobSection.Kind.BASE_COUNTRY -> Icons.Outlined.Search
        JobSection.Kind.VIDEO -> Icons.Outlined.Videocam
        JobSection.Kind.REST  -> Icons.Outlined.FilterList
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
        Text(section.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
        Text("${section.jobs.size}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// ─── Job card ─────────────────────────────────────────────────────────────────

@Composable
fun JobCard(job: Job, onClick: () -> Unit) {
    // iOS JobCard: .padding(16) + VStack(spacing: 12)
    Column(
        modifier = Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface).clickable(onClick = onClick).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // iOS cardHeader: HStack(spacing: 10)
        Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val typeIcon: ImageVector = when (job.type) {
                JobType.AUDITION -> Icons.Outlined.MicNone
                JobType.POSITION -> Icons.Default.Business
                JobType.LESSON   -> Icons.Outlined.School
                JobType.GIG      -> Icons.Default.MusicNote
            }
            // iOS: .frame(width: 40, height: 40).background(BrandSurface, RoundedRectangle(8)) + icon .font(.system(size: 18))
            Box(
                modifier = Modifier.size(40.dp).clip(RoundedCornerShape(8.dp)).background(MaterialTheme.colorScheme.primaryContainer),
                contentAlignment = Alignment.Center,
            ) {
                Icon(typeIcon, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
            }
            // iOS: VStack(spacing: 3)
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                // iOS: .font(.subheadline.weight(.semibold)) = 15sp semibold
                Text(
                    job.organization?.takeIf { it.isNotEmpty() } ?: job.type.label,
                    style = MaterialTheme.typography.bodyMedium.copy(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                // iOS는 12sp(caption)이지만 Android에서 작아 14sp로 키움
                Text(job.type.label, style = MaterialTheme.typography.bodySmall.copy(fontSize = 14.sp), color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            JobDeadlineBadge(job = job)
        }
        // iOS: .font(.headline) = 17sp semibold
        Text(job.title, style = MaterialTheme.typography.titleMedium.copy(fontSize = 19.sp), maxLines = 2, overflow = TextOverflow.Ellipsis)
        if (!job.location.isNullOrEmpty()) {
            Text(job.location, style = MaterialTheme.typography.bodyMedium.copy(fontSize = 15.sp), color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
        }
        if (job.instruments.isNotEmpty()) {
            Text(
                job.instruments.joinToString(" · ") { OnboardingData.instrumentDisplay(it) },
                style = MaterialTheme.typography.bodyMedium.copy(fontSize = 15.sp),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        val hasFacts = job.videoAudition == true || job.applicationFee == 0 || job.hasScholarship == true
        if (hasFacts) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (job.videoAudition == true) JobFactBadge(AppLocale.localized("영상 예선", "Video round", "Video-Vorrunde"))
                if (job.applicationFee == 0)   JobFactBadge(AppLocale.localized("지원료 없음", "No fee", "Kostenlos"))
                if (job.hasScholarship == true) JobFactBadge(AppLocale.localized("장학금", "Scholarship", "Stipendium"))
            }
        }
    }
}

@Composable
fun JobDeadlineBadge(job: Job) {
    val isClosed   = !job.isActive || job.status == "closed" || job.daysLeft?.let { it < 0 } == true
    val isUpcoming = !isClosed && job.status == "announced"
    val isUrgent   = job.isAcceptingApplications && job.daysLeft?.let { it <= 3 } == true
    val label = when {
        isClosed   -> AppLocale.localized("마감", "Closed", "Beendet")
        isUpcoming -> AppLocale.localized("모집 예정", "Upcoming", "Demnächst")
        else       -> job.deadlineLabel
    } ?: return
    // iOS: .padding(.horizontal, 8).padding(.vertical, 5) + RoundedRectangle(6)
    Surface(
        shape = RoundedCornerShape(6.dp),
        color = if (isUrgent) MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                else MaterialTheme.colorScheme.surfaceVariant,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.SemiBold,
            color = if (isUrgent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            // iOS: .padding(.horizontal, 8).padding(.vertical, 5)
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp),
        )
    }
}

@Composable
fun JobFactBadge(text: String) {
    Surface(shape = RoundedCornerShape(4.dp), color = MaterialTheme.colorScheme.surfaceVariant) {
        Text(text, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

@Composable
private fun EmptyJobsState(
    isSearching: Boolean,
    hasFilter: Boolean,
    hasError: Boolean,
    errorMessage: String?,
    onResetFilter: () -> Unit,
    onClearSearch: () -> Unit,
    onRetry: () -> Unit,
    onCreate: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(top = 48.dp, start = 24.dp, end = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (hasError && errorMessage != null) {
            Text(AppLocale.localized("공고를 불러오지 못했어요", "Couldn't load opportunities", "Fehler beim Laden"), style = MaterialTheme.typography.titleMedium)
            Text(errorMessage, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            TextButton(onClick = onRetry) { Text(AppLocale.localized("다시 시도", "Try again", "Erneut versuchen"), style = MaterialTheme.typography.bodyLarge) }
        } else {
            Text(
                if (isSearching || hasFilter)
                    AppLocale.localized("조건에 맞는 공고가 없어요", "No matching opportunities", "Keine passenden Ausschreibungen")
                else
                    AppLocale.localized("공고가 없어요", "No opportunities yet", "Noch keine Ausschreibungen"),
                style = MaterialTheme.typography.titleMedium,
            )
            when {
                hasFilter   -> TextButton(onClick = onResetFilter) { Text(AppLocale.localized("필터 초기화", "Reset filters", "Filter zurücksetzen"), style = MaterialTheme.typography.bodyLarge) }
                isSearching -> TextButton(onClick = onClearSearch) { Text(AppLocale.localized("검색 지우기", "Clear search", "Suche löschen"), style = MaterialTheme.typography.bodyLarge) }
                else        -> TextButton(onClick = onCreate) { Text(AppLocale.localized("첫 공고 올리기", "Post an opportunity", "Ausschreibung erstellen"), style = MaterialTheme.typography.bodyLarge) }
            }
        }
    }
}
