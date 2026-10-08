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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.Activity
import com.cadenza.android.core.data.model.ActivityType
import com.cadenza.android.core.data.model.Affiliation
import com.cadenza.android.core.data.model.CVEntryRow
import com.cadenza.android.core.data.model.CVOverride
import com.cadenza.android.core.data.model.Profile
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import javax.inject.Inject

// ─── Display models ───────────────────────────────────────────────────────────

data class CVFieldSpec(val key: String, val label: String, val original: String?)

data class CVEntry(
    val id: String,
    val sourceKind: String,
    val sourceId: String,
    val kind: String,
    val sectionLabel: String,
    val titleOriginal: String,
    val subtitleOriginal: String?,
    val fields: List<CVFieldSpec>,
)

fun buildCVEntries(
    activities: List<Activity>,
    affiliations: List<Affiliation>,
    cvEntries: List<CVEntryRow>,
): List<CVEntry> {
    val out = mutableListOf<CVEntry>()

    val titleLabel   = AppLocale.localized("제목", "Title", "Titel")
    val orgLabel     = AppLocale.localized("주최/기관", "Organization", "Veranstalter")
    val placeLabel   = AppLocale.localized("장소", "Place", "Ort")
    val detailLabel  = AppLocale.localized("설명", "Detail", "Detail")
    val resultLabel  = AppLocale.localized("결과", "Result", "Ergebnis")
    val instLabel    = AppLocale.localized("기관명", "Institution", "Institution")
    val degreeLabel  = AppLocale.localized("학위", "Degree", "Abschluss")
    val teacherLabel = AppLocale.localized("사사 교수", "Teacher", "Lehrer")

    for (a in activities) {
        val idKey = "activity:${a.id}"
        when (a.type) {
            ActivityType.PERFORMANCE -> out.add(CVEntry(
                id = idKey, sourceKind = "activity", sourceId = a.id, kind = "performance",
                sectionLabel = AppLocale.localized("연주", "Performance", "Auftritt"),
                titleOriginal = a.title, subtitleOriginal = a.organizer,
                fields = listOf(
                    CVFieldSpec("title",  titleLabel,  a.title),
                    CVFieldSpec("org",    orgLabel,    a.organizer),
                    CVFieldSpec("place",  placeLabel,  a.location),
                    CVFieldSpec("detail", detailLabel, a.role),
                )))
            ActivityType.COMPETITION -> out.add(CVEntry(
                id = idKey, sourceKind = "activity", sourceId = a.id, kind = "competition",
                sectionLabel = AppLocale.localized("콩쿠르", "Competition", "Wettbewerb"),
                titleOriginal = a.title, subtitleOriginal = a.prize,
                fields = listOf(
                    CVFieldSpec("title",  titleLabel,  a.title),
                    CVFieldSpec("place",  placeLabel,  a.location),
                    CVFieldSpec("result", resultLabel, a.prize),
                )))
            ActivityType.EDUCATION -> out.add(CVEntry(
                id = idKey, sourceKind = "activity", sourceId = a.id, kind = "masterclass",
                sectionLabel = AppLocale.localized("마스터클래스", "Masterclass", "Meisterkurs"),
                titleOriginal = a.title, subtitleOriginal = a.location,
                fields = listOf(
                    CVFieldSpec("institution", instLabel,    a.title),
                    CVFieldSpec("place",       placeLabel,   a.location),
                    CVFieldSpec("teacher",     teacherLabel, a.role ?: a.organizer),
                )))
            ActivityType.RECORDING -> Unit  // CV에는 녹음 섹션 없음
        }
    }

    for (af in affiliations) {
        out.add(CVEntry(
            id = "affiliation:${af.id}", sourceKind = "affiliation", sourceId = af.id,
            kind = "education",
            sectionLabel = AppLocale.localized("학력", "Education", "Ausbildung"),
            titleOriginal = af.institutionName, subtitleOriginal = null,
            fields = listOf(
                CVFieldSpec("institution", instLabel,   af.institutionName),
                CVFieldSpec("degree",      degreeLabel, null),
            )))
    }

    for (ce in cvEntries) {
        val idKey = "cv_entry:${ce.id}"
        when (ce.kind) {
            "performance" -> out.add(CVEntry(
                id = idKey, sourceKind = "cv_entry", sourceId = ce.id, kind = "performance",
                sectionLabel = AppLocale.localized("연주", "Performance", "Auftritt"),
                titleOriginal = ce.title ?: "", subtitleOriginal = ce.org,
                fields = listOf(
                    CVFieldSpec("title",  titleLabel,  ce.title),
                    CVFieldSpec("org",    orgLabel,    ce.org),
                    CVFieldSpec("place",  placeLabel,  ce.place),
                    CVFieldSpec("detail", detailLabel, ce.detail),
                )))
            "competition" -> out.add(CVEntry(
                id = idKey, sourceKind = "cv_entry", sourceId = ce.id, kind = "competition",
                sectionLabel = AppLocale.localized("콩쿠르", "Competition", "Wettbewerb"),
                titleOriginal = ce.title ?: "", subtitleOriginal = ce.result,
                fields = listOf(
                    CVFieldSpec("title",  titleLabel,  ce.title),
                    CVFieldSpec("place",  placeLabel,  ce.place),
                    CVFieldSpec("result", resultLabel, ce.result),
                )))
            "education" -> out.add(CVEntry(
                id = idKey, sourceKind = "cv_entry", sourceId = ce.id, kind = "education",
                sectionLabel = AppLocale.localized("학력", "Education", "Ausbildung"),
                titleOriginal = ce.institution ?: "", subtitleOriginal = ce.degree,
                fields = listOf(
                    CVFieldSpec("institution", instLabel,   ce.institution),
                    CVFieldSpec("degree",      degreeLabel, ce.degree),
                )))
            "masterclass" -> out.add(CVEntry(
                id = idKey, sourceKind = "cv_entry", sourceId = ce.id, kind = "masterclass",
                sectionLabel = AppLocale.localized("마스터클래스", "Masterclass", "Meisterkurs"),
                titleOriginal = ce.institution ?: "", subtitleOriginal = ce.teacher,
                fields = listOf(
                    CVFieldSpec("institution", instLabel,    ce.institution),
                    CVFieldSpec("place",       placeLabel,   ce.place),
                    CVFieldSpec("teacher",     teacherLabel, ce.teacher),
                )))
        }
    }

    return out
}

// ─── ViewModel ────────────────────────────────────────────────────────────────

@HiltViewModel
class CVEditorViewModel @Inject constructor(
    val repository: Repository,
) : ViewModel() {

    private val _activities   = MutableStateFlow<List<Activity>>(emptyList())
    private val _affiliations = MutableStateFlow<List<Affiliation>>(emptyList())
    private val _cvEntries    = MutableStateFlow<List<CVEntryRow>>(emptyList())
    private val _overrides    = MutableStateFlow<Map<String, CVOverride>>(emptyMap())
    private val _isLoading    = MutableStateFlow(false)

    val isLoading: StateFlow<Boolean>                 = _isLoading.asStateFlow()
    val cvEntries: StateFlow<List<CVEntryRow>>        = _cvEntries.asStateFlow()
    val overrides: StateFlow<Map<String, CVOverride>> = _overrides.asStateFlow()

    val entries: StateFlow<List<CVEntry>> = combine(_activities, _affiliations, _cvEntries) { acts, affs, ces ->
        buildCVEntries(acts, affs, ces)
    }.stateIn(viewModelScope, SharingStarted.Lazily, emptyList())

    fun load(userId: String) {
        if (_isLoading.value) return
        viewModelScope.launch {
            _isLoading.value = true
            try {
                coroutineScope {
                    val actsD = async { runCatching { repository.cvActivities(userId) }.getOrElse { emptyList() } }
                    val affsD = async { runCatching { repository.affiliations(forUser = userId) }.getOrElse { emptyList() } }
                    val cesD  = async { runCatching { repository.cvEntries(userId) }.getOrElse { emptyList() } }
                    val ovsD  = async { runCatching { repository.cvOverrides(userId) }.getOrElse { emptyList() } }
                    _activities.value   = actsD.await()
                    _affiliations.value = affsD.await()
                    _cvEntries.value    = cesD.await()
                    val ovList = ovsD.await()
                    _overrides.value = ovList.associateBy { "${it.sourceKind}:${it.sourceId}" }
                }
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun mergeOverride(override: CVOverride) {
        val key = "${override.sourceKind}:${override.sourceId}"
        _overrides.value = _overrides.value + (key to override)
    }

    fun mergeCVEntry(row: CVEntryRow) {
        val list = _cvEntries.value.toMutableList()
        val i = list.indexOfFirst { it.id == row.id }
        if (i >= 0) list[i] = row else list.add(0, row)
        _cvEntries.value = list
    }

    fun removeCVEntry(id: String) {
        _cvEntries.value = _cvEntries.value.filter { it.id != id }
        viewModelScope.launch { runCatching { repository.deleteCVEntry(id) } }
    }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

private val isoDateFmt: DateTimeFormatter = DateTimeFormatter.ISO_LOCAL_DATE.withZone(ZoneOffset.UTC)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CVEditorScreen(
    userId: String,
    profile: Profile?,
    onDismiss: () -> Unit,
    onProfileUpdated: () -> Unit = {},
    viewModel: CVEditorViewModel = hiltViewModel(),
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    // Form state — initialized from profile
    var nameEn    by remember { mutableStateOf(profile?.nameEn ?: "") }
    var eyebrow   by remember { mutableStateOf(profile?.eyebrow ?: "") }
    var birthDateMillis by remember {
        val millis = profile?.birthDate?.let {
            runCatching { Instant.from(isoDateFmt.parse(it)).toEpochMilli() }.getOrNull()
        }
        mutableStateOf(millis)
    }
    var phone    by remember { mutableStateOf(profile?.phone ?: "") }
    var address  by remember { mutableStateOf(profile?.address ?: "") }
    var repertoire by remember { mutableStateOf(profile?.repertoire ?: emptyList()) }
    var newRepItem by remember { mutableStateOf("") }

    var busy     by remember { mutableStateOf(false) }
    var exporting by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var showDatePicker   by remember { mutableStateOf(false) }
    var composerKind     by remember { mutableStateOf<String?>(null) }
    var composerExisting by remember { mutableStateOf<CVEntryRow?>(null) }
    var selectedEntry    by remember { mutableStateOf<CVEntry?>(null) }
    var kindMenuExpanded by remember { mutableStateOf(false) }

    val isLoading by viewModel.isLoading.collectAsState()
    val cvEntries by viewModel.cvEntries.collectAsState()
    val overrides by viewModel.overrides.collectAsState()
    val entries   by viewModel.entries.collectAsState()

    LaunchedEffect(userId) { viewModel.load(userId) }

    val cvKinds = listOf(
        "performance" to AppLocale.localized("연주", "Performance", "Auftritt"),
        "competition" to AppLocale.localized("콩쿠르", "Competition", "Wettbewerb"),
        "education"   to AppLocale.localized("학력", "Education", "Ausbildung"),
        "masterclass" to AppLocale.localized("마스터클래스", "Masterclass", "Meisterkurs"),
    )

    fun kindLabel(k: String) = cvKinds.firstOrNull { it.first == k }?.second ?: k

    val birthDateStr = birthDateMillis?.let {
        Instant.ofEpochMilli(it).atOffset(ZoneOffset.UTC).toLocalDate().format(DateTimeFormatter.ISO_LOCAL_DATE)
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        modifier = Modifier.fillMaxSize(),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .imePadding(),
        ) {
            // ── Toolbar ────────────────────────────────────────────────────────
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp),
            ) {
                TextButton(onClick = onDismiss) { Text(AppLocale.localized("닫기", "Done", "Fertig")) }
                Text(
                    AppLocale.localized("CV / 이력서", "CV", "Lebenslauf"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                if (busy) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp).padding(end = 12.dp))
                } else {
                    TextButton(
                        onClick = {
                            busy = true; errorText = null
                            scope.launch {
                                try {
                                    viewModel.repository.updateCVFields(
                                        id = userId,
                                        nameEn = nameEn.trim().takeIf { it.isNotEmpty() },
                                        eyebrow = eyebrow.trim().takeIf { it.isNotEmpty() },
                                        birthDate = birthDateStr,
                                        phone = phone.trim().takeIf { it.isNotEmpty() },
                                        address = address.trim().takeIf { it.isNotEmpty() },
                                    )
                                    viewModel.repository.saveRepertoire(userId, repertoire)
                                    onProfileUpdated()
                                    onDismiss()
                                } catch (e: Exception) {
                                    errorText = e.message
                                    busy = false
                                }
                            }
                        },
                    ) {
                        Text(AppLocale.localized("저장", "Save", "Speichern"), fontWeight = FontWeight.SemiBold)
                    }
                }
            }
            HorizontalDivider()

            errorText?.let { err ->
                Text(
                    err,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                )
            }

            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 32.dp),
            ) {
                // ── Intro ──────────────────────────────────────────────────────
                item {
                    Text(
                        AppLocale.localized(
                            "CV는 영어로 발행됩니다. 아래에서 영문 이름과 항목별 영어 표기를 확정하세요. 비워둔 항목은 원문이 그대로 쓰입니다.",
                            "Your CV is published in English. Confirm your romanized name and English wording per entry below. Anything left blank falls back to the original text.",
                            "Der Lebenslauf erscheint auf Englisch. Bestätige unten die englische Schreibweise. Leere Felder nutzen den Originaltext.",
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(16.dp),
                    )
                    HorizontalDivider()
                }

                // ── Identity ───────────────────────────────────────────────────
                item {
                    CvSectionHeader(AppLocale.localized("이름 · 연락처", "Name & contact", "Name & Kontakt"))
                }
                item {
                    Column(
                        modifier = Modifier.padding(horizontal = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        OutlinedTextField(
                            value = nameEn, onValueChange = { nameEn = it },
                            label = { Text(AppLocale.localized("영문 이름", "Name (English)", "Name (Englisch)")) },
                            placeholder = { Text(profile?.realName ?: "e.g. Hyewon Heo") },
                            modifier = Modifier.fillMaxWidth(), singleLine = true,
                        )
                        OutlinedTextField(
                            value = eyebrow, onValueChange = { eyebrow = it },
                            label = { Text(AppLocale.localized("헤드라인", "Headline", "Überschrift")) },
                            placeholder = { Text("e.g. VIOLINIST · BERLIN") },
                            modifier = Modifier.fillMaxWidth(), singleLine = true,
                        )
                        // Birth date row
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(
                                AppLocale.localized("생년월일", "Date of birth", "Geburtsdatum"),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                            if (birthDateStr != null) {
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text(
                                        birthDateStr,
                                        style = MaterialTheme.typography.bodyMedium,
                                        modifier = Modifier.clickable { showDatePicker = true },
                                    )
                                    IconButton(onClick = { birthDateMillis = null }, modifier = Modifier.size(24.dp)) {
                                        Icon(Icons.Outlined.Close, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                            } else {
                                TextButton(onClick = { showDatePicker = true }) {
                                    Text(AppLocale.localized("설정", "Set", "Festlegen"))
                                }
                            }
                        }
                        OutlinedTextField(
                            value = phone, onValueChange = { phone = it },
                            label = { Text(AppLocale.localized("전화", "Phone", "Telefon")) },
                            placeholder = { Text("+49 …") },
                            modifier = Modifier.fillMaxWidth(), singleLine = true,
                        )
                        OutlinedTextField(
                            value = address, onValueChange = { address = it },
                            label = { Text(AppLocale.localized("주소", "Address", "Adresse")) },
                            placeholder = { Text("Torstraße 12, Berlin") },
                            modifier = Modifier.fillMaxWidth(), singleLine = true,
                        )
                        Text(
                            AppLocale.localized(
                                "전화·주소·생년월일은 공개 웹 프로필에는 표시되지 않고, 내려받는 PDF에만 들어갑니다.",
                                "Phone, address and date of birth appear only in the downloaded PDF, never on the public web profile.",
                                "Telefon, Adresse und Geburtsdatum erscheinen nur im PDF, nicht im öffentlichen Profil.",
                            ),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(4.dp))
                    }
                    HorizontalDivider()
                }

                // ── Repertoire ─────────────────────────────────────────────────
                item { CvSectionHeader(AppLocale.localized("레퍼토리", "Repertoire", "Repertoire")) }
                itemsIndexed(repertoire) { idx, item ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(item, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                        IconButton(onClick = {
                            if (idx > 0) repertoire = repertoire.toMutableList().also { l -> l.add(idx - 1, l.removeAt(idx)) }
                        }, modifier = Modifier.size(32.dp), enabled = idx > 0) {
                            Icon(Icons.Default.KeyboardArrowUp, contentDescription = null, modifier = Modifier.size(18.dp))
                        }
                        IconButton(onClick = {
                            if (idx < repertoire.lastIndex) repertoire = repertoire.toMutableList().also { l -> l.add(idx + 1, l.removeAt(idx)) }
                        }, modifier = Modifier.size(32.dp), enabled = idx < repertoire.lastIndex) {
                            Icon(Icons.Default.KeyboardArrowDown, contentDescription = null, modifier = Modifier.size(18.dp))
                        }
                        IconButton(onClick = { repertoire = repertoire.toMutableList().also { it.removeAt(idx) } }, modifier = Modifier.size(32.dp)) {
                            Icon(Icons.Outlined.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                        }
                    }
                }
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        OutlinedTextField(
                            value = newRepItem, onValueChange = { newRepItem = it },
                            placeholder = { Text(AppLocale.localized("작품 추가…", "Add a work…", "Werk hinzufügen…"), style = MaterialTheme.typography.bodySmall) },
                            modifier = Modifier.weight(1f), singleLine = true,
                        )
                        IconButton(
                            onClick = {
                                val v = newRepItem.trim()
                                if (v.isNotEmpty()) { repertoire = repertoire + v; newRepItem = "" }
                            },
                            enabled = newRepItem.isNotBlank(),
                        ) {
                            Icon(Icons.Outlined.CheckCircle, contentDescription = null)
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                    HorizontalDivider()
                }

                // ── CV-only entries ────────────────────────────────────────────
                item {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp, top = 12.dp, bottom = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            AppLocale.localized("CV 전용 항목", "CV-only entries", "Nur-CV-Einträge"),
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.weight(1f),
                        )
                        // Kind picker via ExposedDropdownMenuBox
                        ExposedDropdownMenuBox(
                            expanded = kindMenuExpanded,
                            onExpandedChange = { kindMenuExpanded = it },
                        ) {
                            TextButton(
                                onClick = { kindMenuExpanded = true },
                                modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable),
                            ) {
                                Text(AppLocale.localized("+ 추가", "+ Add", "+ Hinzufügen"))
                                ExposedDropdownMenuDefaults.TrailingIcon(expanded = kindMenuExpanded)
                            }
                            ExposedDropdownMenu(
                                expanded = kindMenuExpanded,
                                onDismissRequest = { kindMenuExpanded = false },
                            ) {
                                cvKinds.forEach { (code, label) ->
                                    DropdownMenuItem(
                                        text = { Text(label) },
                                        onClick = {
                                            composerExisting = null
                                            composerKind = code
                                            kindMenuExpanded = false
                                        },
                                    )
                                }
                            }
                        }
                    }
                }
                itemsIndexed(cvEntries) { _, row ->
                    Surface(
                        modifier = Modifier.fillMaxWidth().clickable {
                            composerExisting = row
                            composerKind = row.kind
                        },
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    row.title ?: row.institution ?: "—",
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                )
                                Text(
                                    kindLabel(row.kind) + (row.year?.let { " · $it" } ?: ""),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            IconButton(onClick = { viewModel.removeCVEntry(row.id) }, modifier = Modifier.size(32.dp)) {
                                Icon(Icons.Outlined.Close, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                item {
                    Text(
                        AppLocale.localized(
                            "기록과 별개로 CV에만 넣을 항목을 추가하세요. 추가 후 '항목 영어화'에서 번역하세요.",
                            "Add CV-only entries separate from your records. Translate them under 'English per entry'.",
                            "Nur-CV-Einträge je Typ, getrennt von Aktivitäten.",
                        ),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                    HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
                }

                // ── Entries (activities + affiliations) ───────────────────────
                item {
                    CvSectionHeader(AppLocale.localized("항목 영어화", "English per entry", "Englisch je Eintrag"))
                    if (isLoading) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                            Text(AppLocale.localized("불러오는 중…", "Loading…", "Lädt…"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    } else if (entries.isEmpty()) {
                        Text(
                            AppLocale.localized("아직 등록된 활동이 없습니다.", "No activities yet.", "Noch keine Aktivitäten."),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(16.dp),
                        )
                    }
                }
                items(entries.size, key = { entries[it].id }) { i ->
                    val entry = entries[i]
                    val ov = overrides["${entry.sourceKind}:${entry.sourceId}"]
                    val excluded    = ov?.include == false
                    val hasEnglish  = ov?.patch?.isNotEmpty() == true

                    Surface(modifier = Modifier.fillMaxWidth().clickable { selectedEntry = entry }) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    entry.titleOriginal,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    color = if (excluded) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                                    maxLines = 1,
                                )
                                Text(
                                    entry.sectionLabel + (entry.subtitleOriginal?.let { " · $it" } ?: ""),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                )
                            }
                            when {
                                excluded   -> Icon(Icons.Outlined.VisibilityOff, contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFFF57C00))
                                hasEnglish -> Icon(Icons.Outlined.CheckCircle,  contentDescription = null, modifier = Modifier.size(16.dp), tint = Color(0xFF388E3C))
                            }
                        }
                    }
                }
                item {
                    Text(
                        AppLocale.localized(
                            "각 항목을 눌러 영어 표기를 확정하고, CV에 넣을지 정하세요.",
                            "Tap an entry to confirm English wording and whether it appears on the CV.",
                            "Tippe einen Eintrag an, um Englisch und Sichtbarkeit festzulegen.",
                        ),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                    HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
                }

                // ── Export ────────────────────────────────────────────────────
                item {
                    CvSectionHeader(AppLocale.localized("내보내기", "Export", "Exportieren"))
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(enabled = !exporting) {
                                exporting = true; errorText = null
                                scope.launch {
                                    try {
                                        val url = viewModel.repository.exportCV()
                                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))
                                        context.startActivity(intent)
                                    } catch (e: Exception) {
                                        errorText = e.message
                                    } finally {
                                        exporting = false
                                    }
                                }
                            }
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(Icons.Outlined.Description, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Text(
                            AppLocale.localized("PDF 내보내기", "Export PDF", "PDF exportieren"),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.weight(1f),
                        )
                        if (exporting) CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    }
                    Text(
                        AppLocale.localized(
                            "저장 후 내보내면 최신 내용이 반영됩니다.",
                            "Save first so the export reflects your latest changes.",
                            "Zuerst speichern, damit der Export aktuell ist.",
                        ),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                }
            }
        }
    }

    // ── Date picker ────────────────────────────────────────────────────────────
    if (showDatePicker) {
        val datePickerState = androidx.compose.material3.rememberDatePickerState(
            initialSelectedDateMillis = birthDateMillis ?: System.currentTimeMillis(),
        )
        androidx.compose.material3.DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    birthDateMillis = datePickerState.selectedDateMillis
                    showDatePicker = false
                }) { Text(AppLocale.localized("확인", "OK", "OK")) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen")) }
            },
        ) { androidx.compose.material3.DatePicker(state = datePickerState) }
    }

    // ── CV entry composer ──────────────────────────────────────────────────────
    val composerKindSnapshot = composerKind
    if (composerKindSnapshot != null) {
        CVEntryComposerSheet(
            userId = userId,
            repository = viewModel.repository,
            existing = composerExisting,
            initialKind = composerKindSnapshot,
            onDismiss = { composerKind = null; composerExisting = null },
            onSaved = { row ->
                viewModel.mergeCVEntry(row)
                composerKind = null; composerExisting = null
            },
        )
    }

    // ── Override editor ────────────────────────────────────────────────────────
    val selectedEntrySnapshot = selectedEntry
    if (selectedEntrySnapshot != null) {
        CVEntryOverrideSheet(
            entry = selectedEntrySnapshot,
            existing = overrides["${selectedEntrySnapshot.sourceKind}:${selectedEntrySnapshot.sourceId}"],
            repository = viewModel.repository,
            userId = userId,
            onDismiss = { selectedEntry = null },
            onSaved = { override ->
                viewModel.mergeOverride(override)
                selectedEntry = null
            },
        )
    }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

@Composable
private fun CvSectionHeader(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelLarge,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp, bottom = 4.dp),
    )
}
