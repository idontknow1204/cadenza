package com.cadenza.android.ui.jobs

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
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
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
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
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.JobType
import com.cadenza.android.core.data.model.NewJob
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateJobSheet(
    userId: String,
    repository: Repository,
    onDismiss: () -> Unit,
    onPosted: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    var type by remember { mutableStateOf(JobType.AUDITION) }
    var title by remember { mutableStateOf("") }
    var organization by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    var selectedInstruments by remember { mutableStateOf(emptySet<String>()) }
    var description by remember { mutableStateOf("") }
    var requirements by remember { mutableStateOf("") }
    var hasDeadline by remember { mutableStateOf(false) }
    var deadlineMillis by remember { mutableStateOf<Long?>(null) }
    var contact by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var showInstrumentPicker by remember { mutableStateOf(false) }
    var showDatePicker by remember { mutableStateOf(false) }

    val canPost = title.trim().isNotEmpty() && description.trim().length >= 10

    val deadlineString = deadlineMillis?.let { millis ->
        Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).toLocalDate()
            .format(DateTimeFormatter.ISO_LOCAL_DATE)
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .imePadding()
                .padding(horizontal = 16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                TextButton(onClick = onDismiss) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen")) }
                Text(
                    AppLocale.localized("공고 올리기", "Post an opportunity", "Ausschreibung erstellen"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                if (busy) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                } else {
                    Button(
                        onClick = {
                            if (!canPost || userId.isEmpty()) return@Button
                            busy = true; errorText = null
                            scope.launch {
                                try {
                                    repository.postJob(
                                        NewJob(
                                            userId = userId,
                                            type = type,
                                            title = title.trim(),
                                            organization = organization.trim().takeIf { it.isNotEmpty() },
                                            location = location.trim().takeIf { it.isNotEmpty() },
                                            instruments = selectedInstruments.sorted(),
                                            description = description.trim(),
                                            requirements = requirements.trim().takeIf { it.isNotEmpty() },
                                            deadline = deadlineString,
                                            contact = contact.trim().takeIf { it.isNotEmpty() },
                                        )
                                    )
                                    onPosted()
                                } catch (e: Exception) {
                                    errorText = e.message
                                    busy = false
                                }
                            }
                        },
                        enabled = canPost && userId.isNotEmpty(),
                    ) {
                        Text(AppLocale.localized("게시", "Post", "Veröffentlichen"))
                    }
                }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Type selector
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    JobType.entries.forEachIndexed { idx, t ->
                        SegmentedButton(
                            selected = type == t,
                            onClick = { type = t },
                            shape = SegmentedButtonDefaults.itemShape(idx, JobType.entries.size),
                        ) { Text(t.label, style = MaterialTheme.typography.labelSmall) }
                    }
                }

                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text(AppLocale.localized("공고 제목 *", "Title *", "Titel *")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = organization,
                    onValueChange = { organization = it },
                    label = { Text(AppLocale.localized("기관 / 단체명", "Organization", "Organisation")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = location,
                    onValueChange = { location = it },
                    label = { Text(AppLocale.localized("지역", "Location", "Ort")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                // Instruments
                TextButton(
                    onClick = { showInstrumentPicker = true },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(
                            if (selectedInstruments.isEmpty())
                                AppLocale.localized("악기 선택", "Select instruments", "Instrumente wählen")
                            else
                                selectedInstruments.sorted().joinToString(", ") { OnboardingData.instrumentDisplay(it) },
                            color = if (selectedInstruments.isEmpty())
                                MaterialTheme.colorScheme.onSurfaceVariant
                            else
                                MaterialTheme.colorScheme.onSurface,
                        )
                        if (selectedInstruments.isNotEmpty()) {
                            Icon(Icons.Filled.Check, contentDescription = null, modifier = Modifier.size(16.dp))
                        }
                    }
                }

                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text(AppLocale.localized("상세 내용 *", "Details *", "Details *")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 4,
                    maxLines = 10,
                )
                OutlinedTextField(
                    value = requirements,
                    onValueChange = { requirements = it },
                    label = { Text(AppLocale.localized("지원 자격", "Requirements", "Voraussetzungen")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    maxLines = 6,
                )

                // Deadline toggle
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = hasDeadline, onCheckedChange = {
                        hasDeadline = it
                        if (!it) deadlineMillis = null
                    })
                    Text(AppLocale.localized("마감일 설정", "Set deadline", "Frist festlegen"))
                }
                if (hasDeadline) {
                    TextButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) {
                        Text(deadlineString ?: AppLocale.localized("날짜 선택", "Select date", "Datum wählen"))
                    }
                }

                OutlinedTextField(
                    value = contact,
                    onValueChange = { contact = it },
                    label = { Text(AppLocale.localized("연락처 / 지원 방법", "Contact / How to apply", "Kontakt / Bewerbung")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    maxLines = 4,
                )

                if (errorText != null) {
                    Text(errorText!!, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }

    if (showInstrumentPicker) {
        InstrumentPickerSheet(
            selected = selectedInstruments,
            onSelectionChanged = { selectedInstruments = it },
            onDismiss = { showInstrumentPicker = false },
        )
    }

    if (showDatePicker) {
        val datePickerState = rememberDatePickerState(initialSelectedDateMillis = deadlineMillis)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    deadlineMillis = datePickerState.selectedDateMillis
                    showDatePicker = false
                }) { Text(AppLocale.localized("확인", "OK", "OK")) }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text(AppLocale.localized("취소", "Cancel", "Abbrechen"))
                }
            },
        ) {
            DatePicker(state = datePickerState)
        }
    }
}

// ─── Instrument picker ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun InstrumentPickerSheet(
    selected: Set<String>,
    onSelectionChanged: (Set<String>) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var localSelected by remember { mutableStateOf(selected) }

    val groups = remember {
        OnboardingData.majors.mapNotNull { major ->
            val insts = OnboardingData.instrumentsByMajor[major.id]
            if (insts.isNullOrEmpty()) null else major to insts
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .padding(horizontal = 16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Text(
                    AppLocale.localized("악기 선택", "Select instruments", "Instrumente wählen"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = {
                    onSelectionChanged(localSelected)
                    onDismiss()
                }) { Text(AppLocale.localized("완료", "Done", "Fertig")) }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(bottom = 16.dp),
            ) {
                groups.forEach { (major, instruments) ->
                    Text(
                        major.localizedName,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
                    )
                    instruments.forEach { inst ->
                        val isSelected = inst.id in localSelected
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(vertical = 2.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Checkbox(
                                checked = isSelected,
                                onCheckedChange = {
                                    localSelected = if (isSelected) localSelected - inst.id else localSelected + inst.id
                                },
                            )
                            Text(inst.localizedName, style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }
        }
    }
}
