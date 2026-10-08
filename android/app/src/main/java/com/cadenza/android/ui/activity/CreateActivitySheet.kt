package com.cadenza.android.ui.activity

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FilterChip
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
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.ActivityType
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.model.NewActivity
import com.cadenza.android.core.data.model.Organization
import com.cadenza.android.core.data.model.ProfileLite
import com.cadenza.android.core.data.model.Visibility
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun CreateActivitySheet(
    userId: String,
    repository: Repository,
    onDismiss: () -> Unit,
    onPosted: (ActivityWithAuthor) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    // Form state
    var type by remember { mutableStateOf(ActivityType.PERFORMANCE) }
    var title by remember { mutableStateOf("") }
    var dateMillis by remember { mutableStateOf(System.currentTimeMillis()) }
    var location by remember { mutableStateOf("") }
    var role by remember { mutableStateOf("") }
    var program by remember { mutableStateOf("") }
    var prize by remember { mutableStateOf("") }
    var organizer by remember { mutableStateOf("") }
    var personalNote by remember { mutableStateOf("") }
    var visibility by remember { mutableStateOf(Visibility.INDUSTRY_FOLLOWERS) }
    var selectedOrgId by remember { mutableStateOf<String?>(null) }

    // People / orgs loaded async
    var people by remember { mutableStateOf<List<ProfileLite>>(emptyList()) }
    var myOrgs by remember { mutableStateOf<List<Organization>>(emptyList()) }
    var taggedIds by remember { mutableStateOf<Set<String>>(emptySet()) }
    var tagSearch by remember { mutableStateOf("") }

    var busy by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var showDatePicker by remember { mutableStateOf(false) }
    var typeExpanded by remember { mutableStateOf(false) }
    var visibilityExpanded by remember { mutableStateOf(false) }
    var orgExpanded by remember { mutableStateOf(false) }

    LaunchedEffect(userId) {
        people = runCatching { repository.people(userId) }.getOrElse { emptyList() }
        myOrgs = runCatching { repository.myOrgs(userId) }.getOrElse { emptyList() }
    }

    val dateString = Instant.ofEpochMilli(dateMillis)
        .atZone(ZoneId.systemDefault()).toLocalDate()
        .format(DateTimeFormatter.ISO_LOCAL_DATE)

    val canPost = title.trim().isNotEmpty()

    val performanceRoles = listOf(
        "독주" to AppLocale.localized("독주", "Solo", "Solo"),
        "협연" to AppLocale.localized("협연", "Concerto", "Konzert"),
        "실내악" to AppLocale.localized("실내악", "Chamber music", "Kammermusik"),
        "반주" to AppLocale.localized("반주", "Accompaniment", "Begleitung"),
        "오케스트라" to AppLocale.localized("오케스트라", "Orchestra", "Orchester"),
    )
    val educationRoles = listOf(
        "수강/강의" to AppLocale.localized("수강/강의", "Attending/Teaching", "Teilnehmen/Lehren"),
        "마스터클래스" to AppLocale.localized("마스터클래스", "Masterclass", "Meisterkurs"),
    )
    val prizeOptions = listOf(
        "1위" to AppLocale.localized("1위", "1st place", "1. Preis"),
        "2위" to AppLocale.localized("2위", "2nd place", "2. Preis"),
        "3위" to AppLocale.localized("3위", "3rd place", "3. Preis"),
        "특별상" to AppLocale.localized("특별상", "Special award", "Sonderpreis"),
        "입선" to AppLocale.localized("입선", "Finalist", "Finalist"),
        "파이널리스트" to AppLocale.localized("파이널리스트", "Semifinalist", "Semifinalist"),
    )

    val filteredPeople = if (tagSearch.isEmpty()) emptyList()
        else people.filter { it.realName.contains(tagSearch, ignoreCase = true) }.take(8)

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
            // ── Toolbar ────────────────────────────────────────────────────────
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                TextButton(onClick = onDismiss) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen")) }
                Text(
                    AppLocale.localized("기록하기", "New record", "Neuer Eintrag"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                if (busy) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                } else {
                    Button(
                        onClick = {
                            if (!canPost) return@Button
                            busy = true; errorText = null
                            scope.launch {
                                try {
                                    val payload = NewActivity(
                                        id = UUID.randomUUID().toString(),
                                        userId = userId,
                                        orgId = selectedOrgId,
                                        type = type,
                                        title = title.trim(),
                                        activityDate = dateString,
                                        location = location.trim().takeIf { it.isNotEmpty() },
                                        role = role.trim().takeIf { it.isNotEmpty() },
                                        program = program.trim().takeIf { it.isNotEmpty() },
                                        prize = prize.trim().takeIf { it.isNotEmpty() },
                                        organizer = organizer.trim().takeIf { it.isNotEmpty() },
                                        personalNote = personalNote.trim().takeIf { it.isNotEmpty() },
                                        visibility = visibility,
                                    )
                                    val created = repository.createActivity(
                                        activity = payload,
                                        imageBytes = emptyList(),
                                        taggedUserIds = taggedIds.toList(),
                                    )
                                    val completed = ActivityWithAuthor(
                                        id = created.id,
                                        userId = created.userId,
                                        type = created.type,
                                        title = created.title,
                                        activityDate = created.activityDate,
                                        location = created.location,
                                        role = created.role,
                                        program = created.program,
                                        prize = created.prize,
                                        organizer = created.organizer,
                                        personalNote = created.personalNote,
                                        imageUrls = created.imageUrls,
                                        verification = created.verification,
                                        createdAt = created.createdAt,
                                        feedReason = "own",
                                    )
                                    onPosted(completed)
                                } catch (e: Exception) {
                                    errorText = e.message
                                    busy = false
                                }
                            }
                        },
                        enabled = canPost,
                    ) { Text(AppLocale.localized("게시", "Post", "Posten")) }
                }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                // ── Post as (org) ──────────────────────────────────────────────
                if (myOrgs.isNotEmpty()) {
                    FormSectionLabel(AppLocale.localized("게시 주체", "Post as", "Posten als"))
                    ExposedDropdownMenuBox(expanded = orgExpanded, onExpandedChange = { orgExpanded = it }) {
                        OutlinedTextField(
                            value = if (selectedOrgId == null) AppLocale.localized("개인으로", "As individual", "Als Einzelperson")
                            else myOrgs.firstOrNull { it.id == selectedOrgId }?.name ?: "",
                            onValueChange = {},
                            readOnly = true,
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = orgExpanded) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                        )
                        ExposedDropdownMenu(expanded = orgExpanded, onDismissRequest = { orgExpanded = false }) {
                            DropdownMenuItem(text = { Text(AppLocale.localized("개인으로", "As individual", "Als Einzelperson")) }, onClick = { selectedOrgId = null; orgExpanded = false })
                            myOrgs.forEach { org ->
                                DropdownMenuItem(text = { Text(org.name) }, onClick = { selectedOrgId = org.id; orgExpanded = false })
                            }
                        }
                    }
                }

                // ── Activity type ──────────────────────────────────────────────
                FormSectionLabel(AppLocale.localized("활동 유형", "Type", "Art"))
                ExposedDropdownMenuBox(expanded = typeExpanded, onExpandedChange = { typeExpanded = it }) {
                    OutlinedTextField(
                        value = type.localizedLabel,
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = typeExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                    )
                    ExposedDropdownMenu(expanded = typeExpanded, onDismissRequest = { typeExpanded = false }) {
                        ActivityType.entries.forEach { t ->
                            DropdownMenuItem(text = { Text(t.localizedLabel) }, onClick = {
                                type = t; typeExpanded = false
                                role = ""; program = ""; prize = ""; organizer = ""; personalNote = ""
                            })
                        }
                    }
                }

                // ── Common fields ──────────────────────────────────────────────
                FormSectionLabel(AppLocale.localized("상세", "Details", "Details"))
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("${type.localizedTitleHint} *") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = dateString,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text(type.localizedDateLabel) },
                    modifier = Modifier.fillMaxWidth().clickable { showDatePicker = true },
                    enabled = false,
                )
                OutlinedTextField(
                    value = location,
                    onValueChange = { location = it },
                    label = { Text(type.localizedLocationHint) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                // ── Type-specific sections ─────────────────────────────────────
                when (type) {
                    ActivityType.PERFORMANCE -> {
                        FormSectionLabel(AppLocale.localized("역할", "Role", "Rolle"))
                        ChipRow(options = performanceRoles, selected = role, onSelect = { role = it })
                        FormSectionLabel(AppLocale.localized("레퍼토리", "Repertoire", "Repertoire"))
                        OutlinedTextField(
                            value = program,
                            onValueChange = { program = it },
                            label = { Text(AppLocale.localized("곡목을 입력하세요…", "List repertoire…", "Repertoire eingeben…")) },
                            modifier = Modifier.fillMaxWidth(),
                            minLines = 3,
                            maxLines = 8,
                        )
                        FormSectionLabel(AppLocale.localized("주최", "Organizer", "Veranstalter"))
                        OutlinedTextField(value = organizer, onValueChange = { organizer = it }, label = { Text(AppLocale.localized("주최", "Organizer", "Veranstalter")) }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                        FormSectionLabel(AppLocale.localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"))
                        OutlinedTextField(value = personalNote, onValueChange = { personalNote = it }, label = { Text(AppLocale.localized("개인 메모 (선택)", "Personal note (optional)", "Persönliche Notiz (optional)")) }, modifier = Modifier.fillMaxWidth(), minLines = 3, maxLines = 8)
                    }
                    ActivityType.COMPETITION -> {
                        FormSectionLabel(AppLocale.localized("결과·수상", "Result", "Ergebnis"))
                        ChipRow(options = prizeOptions, selected = prize, onSelect = { prize = it })
                        OutlinedTextField(value = prize, onValueChange = { prize = it }, label = { Text(AppLocale.localized("직접 입력…", "Or type custom result…", "Oder eigene Eingabe…")) }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                        FormSectionLabel(AppLocale.localized("주최", "Organizer", "Veranstalter"))
                        OutlinedTextField(value = organizer, onValueChange = { organizer = it }, label = { Text(AppLocale.localized("주최", "Organizer", "Veranstalter")) }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                        FormSectionLabel(AppLocale.localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"))
                        OutlinedTextField(value = personalNote, onValueChange = { personalNote = it }, label = { Text(AppLocale.localized("개인 메모 (선택)", "Personal note (optional)", "Persönliche Notiz (optional)")) }, modifier = Modifier.fillMaxWidth(), minLines = 3, maxLines = 8)
                    }
                    ActivityType.EDUCATION -> {
                        FormSectionLabel(AppLocale.localized("역할", "Role", "Rolle"))
                        ChipRow(options = educationRoles, selected = role, onSelect = { role = it })
                        FormSectionLabel(AppLocale.localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"))
                        OutlinedTextField(value = personalNote, onValueChange = { personalNote = it }, label = { Text(AppLocale.localized("개인 메모 (선택)", "Personal note (optional)", "Persönliche Notiz (optional)")) }, modifier = Modifier.fillMaxWidth(), minLines = 3, maxLines = 8)
                    }
                    ActivityType.RECORDING -> {
                        FormSectionLabel(AppLocale.localized("역할", "Role", "Rolle"))
                        OutlinedTextField(value = role, onValueChange = { role = it }, label = { Text(AppLocale.localized("역할", "Role", "Rolle")) }, modifier = Modifier.fillMaxWidth(), singleLine = true)
                        FormSectionLabel(AppLocale.localized("수록곡", "Track list", "Trackliste"))
                        OutlinedTextField(value = program, onValueChange = { program = it }, label = { Text(AppLocale.localized("수록곡 목록…", "List tracks…", "Tracks eingeben…")) }, modifier = Modifier.fillMaxWidth(), minLines = 3, maxLines = 8)
                        FormSectionLabel(AppLocale.localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"))
                        OutlinedTextField(value = personalNote, onValueChange = { personalNote = it }, label = { Text(AppLocale.localized("개인 메모 (선택)", "Personal note (optional)", "Persönliche Notiz (optional)")) }, modifier = Modifier.fillMaxWidth(), minLines = 3, maxLines = 8)
                    }
                }

                // ── Tag people ─────────────────────────────────────────────────
                FormSectionLabel(AppLocale.localized("함께한 사람 태그", "Tag people", "Personen markieren"))
                if (taggedIds.isNotEmpty()) {
                    Row(
                        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        taggedIds.forEach { uid ->
                            val p = people.firstOrNull { it.id == uid }
                            if (p != null) {
                                Surface(
                                    shape = androidx.compose.foundation.shape.CircleShape,
                                    color = MaterialTheme.colorScheme.primaryContainer,
                                ) {
                                    Row(
                                        modifier = Modifier.padding(start = 10.dp, end = 4.dp, top = 5.dp, bottom = 5.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                                    ) {
                                        Text(p.realName, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onPrimaryContainer)
                                        IconButton(onClick = { taggedIds = taggedIds - uid }, modifier = Modifier.size(16.dp)) {
                                            Icon(Icons.Outlined.Close, contentDescription = null, modifier = Modifier.size(10.dp))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                OutlinedTextField(
                    value = tagSearch,
                    onValueChange = { tagSearch = it },
                    label = { Text(AppLocale.localized("이름으로 검색", "Search by name", "Nach Name suchen")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                filteredPeople.forEach { p ->
                    val isTagged = p.id in taggedIds
                    Row(
                        modifier = Modifier.fillMaxWidth().clickable {
                            taggedIds = if (isTagged) taggedIds - p.id else taggedIds + p.id
                        }.padding(vertical = 8.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(p.realName, style = MaterialTheme.typography.bodyMedium)
                            if (!p.instrument.isNullOrEmpty()) Text(p.instrument, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        if (isTagged) Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(18.dp), tint = MaterialTheme.colorScheme.primary)
                    }
                }

                // ── Visibility ─────────────────────────────────────────────────
                FormSectionLabel(AppLocale.localized("공개 범위", "Visibility", "Sichtbarkeit"))
                ExposedDropdownMenuBox(expanded = visibilityExpanded, onExpandedChange = { visibilityExpanded = it }) {
                    OutlinedTextField(
                        value = visibility.localizedLabel,
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = visibilityExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                    )
                    ExposedDropdownMenu(expanded = visibilityExpanded, onDismissRequest = { visibilityExpanded = false }) {
                        Visibility.entries.forEach { v ->
                            DropdownMenuItem(text = { Text(v.localizedLabel) }, onClick = { visibility = v; visibilityExpanded = false })
                        }
                    }
                }

                if (errorText != null) {
                    Text(errorText!!, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }

    // ── Date picker ────────────────────────────────────────────────────────────
    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = dateMillis)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    dateMillis = datePickerState.selectedDateMillis ?: dateMillis
                    showDatePicker = false
                }) { Text(AppLocale.localized("확인", "OK", "OK")) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen")) }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }
}

// ─── Chip row helper ──────────────────────────────────────────────────────────

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipRow(
    options: List<Pair<String, String>>,
    selected: String,
    onSelect: (String) -> Unit,
) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        options.forEach { (id, label) ->
            FilterChip(
                selected = selected == id,
                onClick = { onSelect(if (selected == id) "" else id) },
                label = { Text(label, style = MaterialTheme.typography.labelMedium) },
                leadingIcon = if (selected == id) { { Icon(Icons.Default.Check, contentDescription = null, modifier = Modifier.size(14.dp)) } } else null,
            )
        }
    }
}

@Composable
private fun FormSectionLabel(text: String) {
    Text(text, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, fontWeight = FontWeight.SemiBold)
}
