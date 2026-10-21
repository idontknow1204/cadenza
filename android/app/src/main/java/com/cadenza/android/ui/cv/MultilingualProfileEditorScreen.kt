package com.cadenza.android.ui.cv

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.CVOverride
import com.cadenza.android.core.data.model.Profile
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

// 다국어 프로필 편집기 — 한국어(베이스) 위에 언어별(en/de) 버전을 직접 작성한다.
// 방문자는 자기 언어 버전을 보고, 없으면 한국어 원문으로 폴백.
// 프로필 본문(이름/소개/악기)은 profile-level 오버레이, 항목은 CVEntryOverrideSheet(lang) 재사용.
// iOS: MultilingualProfileEditorView

@HiltViewModel
class MultilingualProfileEditorViewModel @Inject constructor(
    val repository: Repository,
) : ViewModel() {

    private val _lang = MutableStateFlow("en")
    val lang: StateFlow<String> = _lang.asStateFlow()

    private val _entries = MutableStateFlow<List<CVEntry>>(emptyList())
    val entries: StateFlow<List<CVEntry>> = _entries.asStateFlow()

    private val _overrides = MutableStateFlow<Map<String, CVOverride>>(emptyMap())
    val overrides: StateFlow<Map<String, CVOverride>> = _overrides.asStateFlow()

    private val _nameV = MutableStateFlow("")
    private val _bioV = MutableStateFlow("")
    private val _instrumentV = MutableStateFlow("")
    private val _eyebrowV = MutableStateFlow("")
    val nameV: StateFlow<String> = _nameV.asStateFlow()
    val bioV: StateFlow<String> = _bioV.asStateFlow()
    val instrumentV: StateFlow<String> = _instrumentV.asStateFlow()
    val eyebrowV: StateFlow<String> = _eyebrowV.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()
    private val _translating = MutableStateFlow(false)
    val translating: StateFlow<Boolean> = _translating.asStateFlow()
    private val _busy = MutableStateFlow(false)
    val busy: StateFlow<Boolean> = _busy.asStateFlow()
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    fun setName(v: String) { _nameV.value = v }
    fun setBio(v: String) { _bioV.value = v }
    fun setInstrument(v: String) { _instrumentV.value = v }
    fun setEyebrow(v: String) { _eyebrowV.value = v }
    fun clearError() { _error.value = null }

    fun load(userId: String) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                coroutineScope {
                    val actsD = async { runCatching { repository.cvActivities(userId) }.getOrElse { emptyList() } }
                    val affsD = async { runCatching { repository.affiliations(forUser = userId) }.getOrElse { emptyList() } }
                    val cesD  = async { runCatching { repository.cvEntries(userId) }.getOrElse { emptyList() } }
                    val carsD = async { runCatching { repository.careers(forUser = userId) }.getOrElse { emptyList() } }
                    val awsD  = async { runCatching { repository.awards(forUser = userId) }.getOrElse { emptyList() } }
                    _entries.value = buildCVEntries(
                        actsD.await(), affsD.await(), cesD.await(), carsD.await(), awsD.await(),
                    )
                }
                loadLang(userId)
            } finally {
                _isLoading.value = false
            }
        }
    }

    private suspend fun loadLang(userId: String) {
        val l = _lang.value
        val ovs = runCatching { repository.cvOverrides(userId, l) }.getOrElse { emptyList() }
        _overrides.value = ovs.associateBy { "${it.sourceKind}:${it.sourceId}" }
        val pov = runCatching { repository.profileOverlay(userId, l) }.getOrElse { emptyMap() }
        _nameV.value = pov["name"] ?: ""
        _bioV.value = pov["bio"] ?: ""
        _instrumentV.value = pov["instrument"] ?: ""
        _eyebrowV.value = pov["eyebrow"] ?: ""
    }

    fun setLang(userId: String, lang: String) {
        if (lang == _lang.value) return
        _lang.value = lang
        viewModelScope.launch { loadLang(userId) }
    }

    fun mergeOverride(override: CVOverride) {
        _overrides.value = _overrides.value + ("${override.sourceKind}:${override.sourceId}" to override)
    }

    fun suggestProfile(profile: Profile?) {
        profile ?: return
        val originals = buildMap {
            profile.realName.takeIf { it.isNotEmpty() }?.let { put("name", it) }
            profile.bio?.takeIf { it.isNotEmpty() }?.let { put("bio", it) }
            profile.instrument?.takeIf { it.isNotEmpty() }?.let { put("instrument", it) }
        }
        if (originals.isEmpty()) return
        viewModelScope.launch {
            _translating.value = true
            try {
                val out = repository.translateCVEntry("profile", originals, _lang.value)
                if (_nameV.value.isEmpty()) out["name"]?.let { _nameV.value = it }
                if (_bioV.value.isEmpty()) out["bio"]?.let { _bioV.value = it }
                if (_instrumentV.value.isEmpty()) out["instrument"]?.let { _instrumentV.value = it }
            } catch (_: Exception) {
                // 번역 실패는 치명적이지 않음
            } finally {
                _translating.value = false
            }
        }
    }

    fun save(userId: String, base: Profile?, onDone: () -> Unit) {
        viewModelScope.launch {
            _busy.value = true; _error.value = null
            try {
                val patch = buildMap {
                    _nameV.value.trim().takeIf { it.isNotEmpty() }?.let { put("name", it) }
                    _bioV.value.trim().takeIf { it.isNotEmpty() }?.let { put("bio", it) }
                    _instrumentV.value.trim().takeIf { it.isNotEmpty() }?.let { put("instrument", it) }
                    _eyebrowV.value.trim().takeIf { it.isNotEmpty() }?.let { put("eyebrow", it) }
                }
                repository.upsertProfileOverlay(userId, _lang.value, patch)
                // 이 언어에 내용이 생겼으니 제공 언어 목록에 추가
                val set = (base?.profileLangs ?: emptyList()).toMutableSet()
                if (patch.isNotEmpty() || _overrides.value.isNotEmpty()) set.add(_lang.value)
                repository.setProfileLangs(userId, set.sorted())
                _busy.value = false
                onDone()
            } catch (e: Exception) {
                _error.value = e.message
                _busy.value = false
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MultilingualProfileEditorScreen(
    userId: String,
    profile: Profile?,
    onDismiss: () -> Unit,
    onSaved: () -> Unit = {},
    viewModel: MultilingualProfileEditorViewModel = hiltViewModel(),
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val lang by viewModel.lang.collectAsState()
    val entries by viewModel.entries.collectAsState()
    val overrides by viewModel.overrides.collectAsState()
    val nameV by viewModel.nameV.collectAsState()
    val bioV by viewModel.bioV.collectAsState()
    val instrumentV by viewModel.instrumentV.collectAsState()
    val eyebrowV by viewModel.eyebrowV.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()
    val translating by viewModel.translating.collectAsState()
    val busy by viewModel.busy.collectAsState()
    val error by viewModel.error.collectAsState()

    var selectedEntry by remember { mutableStateOf<CVEntry?>(null) }

    LaunchedEffect(userId) { viewModel.load(userId) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        modifier = Modifier.fillMaxSize(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .imePadding()
                .padding(horizontal = 16.dp),
        ) {
            // Toolbar
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            ) {
                TextButton(onClick = onDismiss) { Text(AppLocale.localized("닫기", "Done", "Fertig")) }
                Text(
                    AppLocale.localized("다국어 프로필", "Multilingual profile", "Mehrsprachiges Profil"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    maxLines = 1,
                )
                if (busy) CircularProgressIndicator(modifier = Modifier.size(24.dp))
                else TextButton(
                    onClick = { viewModel.save(userId, profile) { onSaved(); onDismiss() } },
                ) {
                    Text(AppLocale.localized("저장", "Save", "Speichern"), fontWeight = FontWeight.SemiBold)
                }
            }
            HorizontalDivider(modifier = Modifier.padding(bottom = 12.dp))

            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // Language picker
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    listOf("en" to "English", "de" to "Deutsch").forEachIndexed { index, (code, label) ->
                        SegmentedButton(
                            selected = lang == code,
                            onClick = { viewModel.setLang(userId, code) },
                            shape = SegmentedButtonDefaults.itemShape(index = index, count = 2),
                        ) { Text(label) }
                    }
                }
                Text(
                    AppLocale.localized(
                        "한국어는 기본 버전입니다. 여기서 작성한 언어 버전이 방문자 언어에 맞춰 보여지고, 없는 항목은 한국어 원문으로 표시됩니다.",
                        "Korean is the base version. Versions you write here are shown to visitors in their language; anything left blank falls back to the Korean original.",
                        "Koreanisch ist die Basis. Hier erstellte Sprachversionen werden Besuchern angezeigt; Leeres nutzt das koreanische Original.",
                    ),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )

                // AI translate for profile fields
                TextButton(
                    onClick = { viewModel.suggestProfile(profile) },
                    enabled = !translating,
                ) {
                    Icon(Icons.Outlined.AutoAwesome, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.size(6.dp))
                    Text(AppLocale.localized("원문에서 AI 번역 제안", "AI-translate from the original", "KI-Übersetzung aus dem Original"))
                    if (translating) {
                        Spacer(Modifier.size(8.dp))
                        CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
                    }
                }

                // Profile section
                Text(
                    AppLocale.localized("프로필", "Profile", "Profil"),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                OverlayField(
                    label = AppLocale.localized("이름", "Name", "Name"),
                    value = nameV, onValueChange = viewModel::setName, original = profile?.realName,
                )
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    OutlinedTextField(
                        value = bioV, onValueChange = viewModel::setBio,
                        label = { Text(AppLocale.localized("소개", "About", "Über mich")) },
                        modifier = Modifier.fillMaxWidth().height(110.dp),
                    )
                    if (!profile?.bio.isNullOrEmpty()) {
                        Text(
                            AppLocale.localized("원문: ", "Original: ", "Original: ") + profile!!.bio,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 3,
                        )
                    }
                }
                OverlayField(
                    label = AppLocale.localized("악기", "Instrument", "Instrument"),
                    value = instrumentV, onValueChange = viewModel::setInstrument, original = profile?.instrument,
                )
                OverlayField(
                    label = AppLocale.localized("헤드라인", "Headline", "Überschrift"),
                    value = eyebrowV, onValueChange = viewModel::setEyebrow, original = null,
                )

                HorizontalDivider()

                // Career entries
                Text(
                    AppLocale.localized("커리어 항목", "Career entries", "Karriereeinträge"),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                if (isLoading) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        Text(AppLocale.localized("불러오는 중…", "Loading…", "Lädt…"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                } else {
                    entries.forEach { entry ->
                        val hasOverride = overrides["${entry.sourceKind}:${entry.sourceId}"]?.patch?.isNotEmpty() == true
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { selectedEntry = entry }
                                .padding(vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(entry.titleOriginal, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, maxLines = 1)
                                Text(entry.sectionLabel, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            if (hasOverride) {
                                Icon(Icons.Outlined.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                            }
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = MaterialTheme.colorScheme.outline)
                        }
                        HorizontalDivider()
                    }
                }

                error?.let { err ->
                    Text(err, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }

    selectedEntry?.let { entry ->
        CVEntryOverrideSheet(
            entry = entry,
            existing = overrides["${entry.sourceKind}:${entry.sourceId}"],
            repository = viewModel.repository,
            userId = userId,
            lang = lang,
            onDismiss = { selectedEntry = null },
            onSaved = { updated -> viewModel.mergeOverride(updated); selectedEntry = null },
        )
    }
}

@Composable
private fun OverlayField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    original: String?,
) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        OutlinedTextField(
            value = value,
            onValueChange = onValueChange,
            label = { Text(label) },
            placeholder = { if (!original.isNullOrEmpty()) Text(original) },
            modifier = Modifier.fillMaxWidth(),
            singleLine = true,
        )
        if (!original.isNullOrEmpty()) {
            Text(
                AppLocale.localized("원문: ", "Original: ", "Original: ") + original,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}
