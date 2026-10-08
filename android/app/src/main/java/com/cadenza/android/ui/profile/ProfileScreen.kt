package com.cadenza.android.ui.profile

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.MusicNote
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SuggestionChip
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.cadenza.android.core.data.model.Affiliation
import com.cadenza.android.core.data.model.Career
import com.cadenza.android.core.data.model.Organization
import com.cadenza.android.core.data.model.Profile
import com.cadenza.android.core.data.model.ProfileAward
import com.cadenza.android.core.data.model.ProfileSection
import com.cadenza.android.core.data.model.Recommendation
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.common.UserAvatarView
import com.cadenza.android.ui.profile.components.ActivityPager
import com.cadenza.android.ui.profile.components.AffiliationRow
import com.cadenza.android.ui.profile.components.CareerRow
import com.cadenza.android.ui.profile.components.RecommendationRow
import com.cadenza.android.ui.profile.components.SectionCard
import com.cadenza.android.ui.profile.sheets.AffiliationEditSheet
import com.cadenza.android.ui.profile.sheets.AwardEditSheet
import com.cadenza.android.ui.profile.sheets.CareerEditSheet
import com.cadenza.android.ui.profile.sheets.CvWebsiteEditSheet
import com.cadenza.android.ui.profile.sheets.EditProfileSheet
import com.cadenza.android.ui.profile.sheets.LanguageEditSheet
import com.cadenza.android.ui.profile.sheets.ManageSectionsSheet
import com.cadenza.android.ui.profile.sheets.RecommendationEditSheet

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun ProfileScreen(
    contentPadding: PaddingValues = PaddingValues(),
    onNavigateToUser: (String) -> Unit = {},
    session: SessionViewModel = hiltViewModel(),
    viewModel: ProfileViewModel = hiltViewModel(),
) {
    val profile by session.profile.collectAsState()
    val activities by viewModel.activities.collectAsState()
    val affiliations by viewModel.affiliations.collectAsState()
    val careers by viewModel.careers.collectAsState()
    val awards by viewModel.awards.collectAsState()
    val languages by viewModel.languages.collectAsState()
    val orgs by viewModel.orgs.collectAsState()
    val recommendations by viewModel.recommendations.collectAsState()
    val connectionCount by viewModel.connectionCount.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    var showConnectionsList by remember { mutableStateOf(false) }
    var showBasicEdit by remember { mutableStateOf(false) }
    var showAffiliationAdd by remember { mutableStateOf(false) }
    var showAffiliationEdit by remember { mutableStateOf<Affiliation?>(null) }
    var showCareerAdd by remember { mutableStateOf(false) }
    var showCareerEdit by remember { mutableStateOf<Career?>(null) }
    var showAwardAdd by remember { mutableStateOf(false) }
    var showAwardEdit by remember { mutableStateOf<ProfileAward?>(null) }
    var showLanguageEdit by remember { mutableStateOf(false) }
    var showCvWebsiteEdit by remember { mutableStateOf(false) }
    var showRecommendationAdd by remember { mutableStateOf(false) }
    var showRecommendationEdit by remember { mutableStateOf<Recommendation?>(null) }
    var showManageSections by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }

    val userId = session.currentUserId

    LaunchedEffect(userId) {
        if (userId != null) viewModel.load(userId, profile)
    }
    LaunchedEffect(profile) {
        if (userId != null && profile != null) viewModel.load(userId, profile)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(AppLocale.localized("프로필", "Profile", "Profil")) },
                actions = {
                    IconButton(onClick = { showManageSections = true }, enabled = profile != null) {
                        Icon(Icons.Outlined.Tune, contentDescription = null)
                    }
                    IconButton(onClick = { showSettings = true }) {
                        Icon(Icons.Outlined.Settings, contentDescription = null)
                    }
                },
                windowInsets = WindowInsets.statusBars,
            )
        },
        contentWindowInsets = WindowInsets(0),
    ) { innerPadding ->
        PullToRefreshBox(
            isRefreshing = isLoading,
            onRefresh = { if (userId != null) { session.refreshProfile(); viewModel.load(userId, profile) } },
            modifier = Modifier.padding(innerPadding),
        ) {
            if (profile == null && !isLoading) {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(AppLocale.localized("프로필을 불러오지 못했어요", "Couldn't load profile", "Profil konnte nicht geladen werden"))
                        Button(onClick = { if (userId != null) { session.refreshProfile(); viewModel.load(userId, profile) } }) {
                            Text(AppLocale.localized("다시 시도", "Retry", "Erneut versuchen"))
                        }
                    }
                }
            } else {
                LazyColumn(
                    contentPadding = PaddingValues(
                        bottom = contentPadding.calculateBottomPadding() + 16.dp,
                        top = 8.dp,
                    ),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    profile?.let { p ->
                        item("header") {
                            ProfileHeaderCard(
                                profile = p,
                                affiliations = affiliations,
                                connectionCount = connectionCount,
                                onEditBasic = { showBasicEdit = true },
                                onShowConnections = { showConnectionsList = true },
                            )
                        }
                        if (p.showsSection(ProfileSection.BIO)) {
                            item("bio") {
                                SectionCard(
                                    title = ProfileSection.BIO.title,
                                    onEdit = { showBasicEdit = true },
                                ) {
                                    if (!p.bio.isNullOrEmpty()) {
                                        Text(p.bio, style = MaterialTheme.typography.bodyMedium)
                                    } else {
                                        Text(
                                            AppLocale.localized("소개글을 작성해보세요", "Add a bio", "Bio hinzufügen"),
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = MaterialTheme.colorScheme.outlineVariant,
                                        )
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.EDUCATION)) {
                            item("education") {
                                SectionCard(
                                    title = ProfileSection.EDUCATION.title,
                                    onAdd = { showAffiliationAdd = true },
                                ) {
                                    if (affiliations.isEmpty()) {
                                        EmptyRow(AppLocale.localized("학력을 추가해보세요", "Add your education", "Ausbildung hinzufügen"))
                                    } else {
                                        affiliations.forEachIndexed { i, aff ->
                                            AffiliationRow(
                                                affiliation = aff,
                                                showsDisclosure = true,
                                                onSelect = { showAffiliationEdit = aff },
                                            )
                                            if (i < affiliations.lastIndex) HorizontalDivider()
                                        }
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.ACTIVITIES)) {
                            item("activities") {
                                SectionCard(
                                    title = ProfileSection.ACTIVITIES.title,
                                    viewAllAction = { /* TODO: ProfileActivitiesScreen */ },
                                    viewAllLabel = AppLocale.localized("전체 보기", "View all", "Alle anzeigen"),
                                ) {
                                    if (activities.isEmpty()) {
                                        Text(
                                            AppLocale.localized("아직 기록한 활동이 없어요.", "No activities yet.", "Noch keine Aktivitäten."),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                    } else {
                                        ActivityPager(activities = activities)
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.CAREER)) {
                            item("career") {
                                SectionCard(
                                    title = ProfileSection.CAREER.title,
                                    onAdd = { showCareerAdd = true },
                                ) {
                                    if (careers.isEmpty()) {
                                        EmptyRow(AppLocale.localized("경력을 추가해보세요", "Add your career history", "Berufserfahrung hinzufügen"))
                                    } else {
                                        careers.forEachIndexed { i, c ->
                                            CareerRow(career = c, showsDisclosure = true, onSelect = { showCareerEdit = c })
                                            if (i < careers.lastIndex) HorizontalDivider()
                                        }
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.AWARDS)) {
                            item("awards") {
                                SectionCard(
                                    title = ProfileSection.AWARDS.title,
                                    onAdd = { showAwardAdd = true },
                                ) {
                                    if (awards.isEmpty()) {
                                        EmptyRow(AppLocale.localized("수상 경력을 추가해보세요", "Add your honors and awards", "Auszeichnungen hinzufügen"))
                                    } else {
                                        awards.forEachIndexed { i, award ->
                                            AwardRow(
                                                award = award,
                                                showsDisclosure = true,
                                                onSelect = { showAwardEdit = award },
                                            )
                                            if (i < awards.lastIndex) HorizontalDivider()
                                        }
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.LANGUAGES)) {
                            item("languages") {
                                SectionCard(
                                    title = ProfileSection.LANGUAGES.title,
                                    onEdit = { showLanguageEdit = true },
                                ) {
                                    if (languages.isEmpty()) {
                                        EmptyRow(AppLocale.localized("사용 언어를 추가해보세요", "Add languages you speak", "Sprachen hinzufügen"))
                                    } else {
                                        FlowRow(
                                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                                            verticalArrangement = Arrangement.spacedBy(8.dp),
                                        ) {
                                            languages.forEach { lang ->
                                                LanguageChipView(lang.language, lang.level)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.CV_WEBSITE)) {
                            item("cv_website") {
                                CvWebsiteCard(
                                    profile = p,
                                    onEdit = { showCvWebsiteEdit = true },
                                )
                            }
                        }
                        if (p.showsSection(ProfileSection.RECOMMENDATIONS)) {
                            item("recommendations") {
                                val title = if (recommendations.isEmpty()) ProfileSection.RECOMMENDATIONS.title
                                            else "${ProfileSection.RECOMMENDATIONS.title} (${recommendations.size})"
                                SectionCard(
                                    title = title,
                                    onAdd = { showRecommendationAdd = true },
                                ) {
                                    if (recommendations.isEmpty()) {
                                        TextButton(onClick = { showRecommendationAdd = true }) {
                                            Icon(Icons.Outlined.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                                            Text(AppLocale.localized("추천서 추가", "Add recommendation", "Empfehlung hinzufügen"))
                                        }
                                    } else {
                                        recommendations.forEachIndexed { i, rec ->
                                            RecommendationRow(rec = rec, onEdit = { showRecommendationEdit = rec })
                                            if (i < recommendations.lastIndex) HorizontalDivider()
                                        }
                                    }
                                }
                            }
                        }
                        if (p.showsSection(ProfileSection.ORG)) {
                            item("orgs") {
                                OrgCard(orgs = orgs, onNavigateToOrg = { /* TODO */ }, onCreateOrg = { /* TODO */ })
                            }
                        }
                        item("manage_sections") {
                            ManageSectionsButton(onClick = { showManageSections = true })
                        }
                    }
                }
            }
        }
    }

    // ── Sheets ──────────────────────────────────────────────────────────────────

    if (showConnectionsList && userId != null) {
        ConnectionsListSheet(
            userId = userId,
            repository = viewModel.repository,
            onNavigateToUser = onNavigateToUser,
            onDismiss = { showConnectionsList = false },
        )
    }
    if (showBasicEdit && profile != null && userId != null) {
        EditProfileSheet(
            profile = profile!!,
            existingAffiliation = affiliations.firstOrNull(),
            userId = userId,
            repository = viewModel.repository,
            onDismiss = { showBasicEdit = false },
            onSaved = { updatedProfile, updatedAff ->
                session.refreshProfile()
                if (updatedAff != null) viewModel.mergeAffiliation(updatedAff)
                showBasicEdit = false
            },
        )
    }
    if (showAffiliationAdd && userId != null) {
        AffiliationEditSheet(
            existing = null,
            userId = userId,
            repository = viewModel.repository,
            onDismiss = { showAffiliationAdd = false },
            onSaved = { aff -> viewModel.mergeAffiliation(aff) },
            onDeleted = { id -> viewModel.removeAffiliation(id) },
        )
    }
    showAffiliationEdit?.let { aff ->
        if (userId != null) {
            AffiliationEditSheet(
                existing = aff,
                userId = userId,
                repository = viewModel.repository,
                onDismiss = { showAffiliationEdit = null },
                onSaved = { updated -> viewModel.mergeAffiliation(updated) },
                onDeleted = { id -> viewModel.removeAffiliation(id) },
            )
        }
    }
    if (showCareerAdd && userId != null) {
        CareerEditSheet(
            existing = null,
            userId = userId,
            repository = viewModel.repository,
            onDismiss = { showCareerAdd = false },
            onSaved = { viewModel.mergeCareer(it) },
            onDeleted = { viewModel.removeCareer(it) },
        )
    }
    showCareerEdit?.let { career ->
        if (userId != null) {
            CareerEditSheet(
                existing = career,
                userId = userId,
                repository = viewModel.repository,
                onDismiss = { showCareerEdit = null },
                onSaved = { viewModel.mergeCareer(it) },
                onDeleted = { viewModel.removeCareer(it) },
            )
        }
    }
    if (showAwardAdd && userId != null) {
        AwardEditSheet(
            existing = null,
            userId = userId,
            repository = viewModel.repository,
            onDismiss = { showAwardAdd = false },
            onSaved = { viewModel.mergeAward(it) },
            onDeleted = { viewModel.removeAward(it) },
        )
    }
    showAwardEdit?.let { award ->
        if (userId != null) {
            AwardEditSheet(
                existing = award,
                userId = userId,
                repository = viewModel.repository,
                onDismiss = { showAwardEdit = null },
                onSaved = { viewModel.mergeAward(it) },
                onDeleted = { viewModel.removeAward(it) },
            )
        }
    }
    if (showLanguageEdit && userId != null) {
        LanguageEditSheet(
            userId = userId,
            current = languages,
            repository = viewModel.repository,
            onDismiss = { showLanguageEdit = false },
            onSaved = { viewModel.updateLanguages(it) },
        )
    }
    if (showCvWebsiteEdit && profile != null && userId != null) {
        CvWebsiteEditSheet(
            userId = userId,
            currentCvUrl = profile!!.cvUrl,
            currentWebsiteUrl = profile!!.websiteUrl,
            repository = viewModel.repository,
            onDismiss = { showCvWebsiteEdit = false },
            onSaved = { session.refreshProfile() },
        )
    }
    if (showRecommendationAdd && profile != null && userId != null) {
        RecommendationEditSheet(
            existing = null,
            recipientId = userId,
            repository = viewModel.repository,
            onDismiss = { showRecommendationAdd = false },
            onSaved = { viewModel.mergeRecommendation(it) },
        )
    }
    showRecommendationEdit?.let { rec ->
        if (userId != null) {
            RecommendationEditSheet(
                existing = rec,
                recipientId = userId,
                repository = viewModel.repository,
                onDismiss = { showRecommendationEdit = null },
                onSaved = { viewModel.mergeRecommendation(it) },
                onDeleted = { viewModel.removeRecommendation(rec.id) },
            )
        }
    }
    if (showManageSections && profile != null && userId != null) {
        ManageSectionsSheet(
            visibleSections = profile!!.visibleSections,
            onDismiss = { showManageSections = false },
            onSave = { sections ->
                viewModel.repository.updateVisibleSections(userId, sections)
                session.refreshProfile()
                showManageSections = false
            },
        )
    }
    if (showSettings) {
        ProfileSettingsSheet(
            onDismiss = { showSettings = false },
            onSignOut = { session.signOut(); showSettings = false },
        )
    }
}

// ── Private composables ──────────────────────────────────────────────────────

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ProfileHeaderCard(
    profile: Profile,
    affiliations: List<Affiliation>,
    connectionCount: Int,
    onEditBasic: () -> Unit,
    onShowConnections: () -> Unit,
) {
    SectionCard {
        Row(
            horizontalArrangement = Arrangement.spacedBy(14.dp),
            verticalAlignment = Alignment.Top,
            modifier = Modifier.fillMaxWidth(),
        ) {
            UserAvatarView(url = profile.avatarUrl, name = profile.realName, size = 68.dp)
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(profile.realName, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                val subtitle = listOfNotNull(
                    profile.major?.let { OnboardingData.majorDisplay(it) },
                    profile.instrument?.let { OnboardingData.instrumentDisplay(it) },
                ).joinToString(" · ")
                if (subtitle.isNotEmpty()) {
                    Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (affiliations.isNotEmpty()) {
                    Text(affiliations.first().institutionName, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            IconButton(onClick = onEditBasic, modifier = Modifier.size(36.dp)) {
                Icon(Icons.Outlined.Settings, contentDescription = null, modifier = Modifier.size(18.dp))
            }
        }
        Spacer(Modifier.height(4.dp))
        TextButton(onClick = onShowConnections, contentPadding = PaddingValues(0.dp)) {
            Text(
                AppLocale.localized("${connectionCount}명과 연결됨", "Connected with $connectionCount", "Verbunden mit $connectionCount"),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        if (profile.homeCities.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                profile.homeCities.forEach { id ->
                    val city = OnboardingData.cityOptions.firstOrNull { it.id == id }
                    if (city != null) {
                        SuggestionChip(
                            onClick = {},
                            label = { Text(city.localizedName, style = MaterialTheme.typography.labelSmall) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyRow(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.outlineVariant, modifier = Modifier.padding(vertical = 2.dp))
}

@Composable
private fun AwardRow(
    award: com.cadenza.android.core.data.model.ProfileAward,
    showsDisclosure: Boolean = false,
    onSelect: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onSelect != null) Modifier.clickable { onSelect() } else Modifier)
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(award.title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
            Text(award.prize, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("${award.issuer} · ${award.year}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
        }
        if (showsDisclosure) {
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.outline,
                modifier = Modifier.size(20.dp).padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun LanguageChipView(language: String, level: String) {
    val levelLabel = when (level) {
        "native"       -> AppLocale.localized("모국어", "Native",        "Muttersprache")
        "fluent"       -> AppLocale.localized("유창",   "Fluent",        "Fließend")
        "intermediate" -> AppLocale.localized("중급",   "Intermediate",  "Mittel")
        else           -> AppLocale.localized("기초",   "Basic",         "Grundkenntnisse")
    }
    SuggestionChip(
        onClick = {},
        label = {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(language, style = MaterialTheme.typography.labelMedium)
                Text(levelLabel, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CvWebsiteCard(profile: Profile, onEdit: () -> Unit) {
    val context = LocalContext.current
    val hasCv = !profile.cvUrl.isNullOrEmpty()
    val hasWebsite = !profile.websiteUrl.isNullOrEmpty()
    SectionCard(title = ProfileSection.CV_WEBSITE.title, onEdit = onEdit) {
        if (!hasCv && !hasWebsite) {
            TextButton(onClick = onEdit, contentPadding = PaddingValues(0.dp)) {
                Icon(Icons.Outlined.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                Text(AppLocale.localized("CV 또는 홈페이지 추가", "Add CV or Website", "CV oder Webseite hinzufügen"))
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (hasCv) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(profile.cvUrl))) },
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Outlined.Description, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(24.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(AppLocale.localized("CV / 이력서", "CV / Resume", "CV / Lebenslauf"), style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
                            Text(profile.cvUrl!!.split("/").lastOrNull() ?: profile.cvUrl!!, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                        }
                    }
                }
                if (hasWebsite) {
                    if (hasCv) HorizontalDivider()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(profile.websiteUrl))) },
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(Icons.Outlined.Language, contentDescription = null, tint = MaterialTheme.colorScheme.tertiary, modifier = Modifier.size(24.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text(AppLocale.localized("홈페이지", "Website", "Webseite"), style = MaterialTheme.typography.bodySmall, fontWeight = FontWeight.Medium)
                            Text(profile.websiteUrl!!, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 1)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun OrgCard(
    orgs: List<Organization>,
    onNavigateToOrg: (String) -> Unit,
    onCreateOrg: () -> Unit,
) {
    SectionCard(title = ProfileSection.ORG.title, onAdd = onCreateOrg) {
        if (orgs.isEmpty()) {
            TextButton(onClick = onCreateOrg, contentPadding = PaddingValues(0.dp)) {
                Icon(Icons.Outlined.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                Text(AppLocale.localized("기관 페이지 만들기", "Create organization page", "Organisationsseite erstellen"))
            }
        } else {
            orgs.forEachIndexed { i, org ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onNavigateToOrg(org.id) }
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Outlined.MusicNote, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(38.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(org.name, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                        if (org.category != null) {
                            Text(org.category.label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Icon(
                        Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.outline,
                        modifier = Modifier.size(18.dp),
                    )
                }
                if (i < orgs.lastIndex) HorizontalDivider()
            }
        }
    }
}

@Composable
private fun ManageSectionsButton(onClick: () -> Unit) {
    FilledTonalButton(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        colors = ButtonDefaults.filledTonalButtonColors(
            containerColor = MaterialTheme.colorScheme.secondaryContainer,
        ),
    ) {
        Icon(Icons.Outlined.Tune, contentDescription = null, modifier = Modifier.size(18.dp))
        Spacer(Modifier.size(8.dp))
        Text(AppLocale.localized("프로필 섹션 관리", "Profile Sections", "Profilabschnitte"))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProfileSettingsSheet(
    onDismiss: () -> Unit,
    onSignOut: () -> Unit,
) {
    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = androidx.compose.material3.rememberModalBottomSheetState(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(
                AppLocale.localized("설정", "Settings", "Einstellungen"),
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(bottom = 8.dp),
            )
            HorizontalDivider()
            TextButton(
                onClick = onSignOut,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
            ) {
                Text(AppLocale.localized("로그아웃", "Sign Out", "Abmelden"))
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
