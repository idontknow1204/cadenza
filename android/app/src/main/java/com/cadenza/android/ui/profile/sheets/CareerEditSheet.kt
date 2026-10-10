package com.cadenza.android.ui.profile.sheets

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
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
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.Career
import com.cadenza.android.core.data.model.NewCareer
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CareerEditSheet(
    existing: Career?,
    userId: String,
    repository: Repository,
    onDismiss: () -> Unit,
    onSaved: (Career) -> Unit,
    onDeleted: (String) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val years = OnboardingData.enrollmentYears

    var organization by remember { mutableStateOf(existing?.organization ?: "") }
    var role by remember { mutableStateOf(existing?.role ?: "") }
    var startYear by remember { mutableStateOf(existing?.startYear) }
    var endYear by remember { mutableStateOf(existing?.endYear) }
    var isCurrent by remember { mutableStateOf(existing?.isCurrent ?: false) }
    var description by remember { mutableStateOf(existing?.description ?: "") }
    var contribution by remember { mutableStateOf(existing?.contribution ?: "") }
    var linkUrl by remember { mutableStateOf(existing?.linkUrl ?: "") }
    var mediaUrl by remember { mutableStateOf(existing?.mediaUrl ?: "") }
    var saving by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var startExpanded by remember { mutableStateOf(false) }
    var endExpanded by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .imePadding()
                .padding(horizontal = 16.dp),
        ) {
            Box(modifier = Modifier.fillMaxWidth().height(48.dp)) {
                TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterStart)) {
                    Text(AppLocale.localized("취소", "Cancel", "Abbrechen"), style = MaterialTheme.typography.bodyLarge)
                }
                Text(
                    if (existing == null)
                        AppLocale.localized("경력 추가", "Add Career", "Berufserfahrung")
                    else
                        AppLocale.localized("경력 편집", "Edit Career", "Berufserfahrung bearbeiten"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.align(Alignment.Center).padding(horizontal = 96.dp),
                    textAlign = TextAlign.Center,
                )
                if (saving) {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.CenterEnd).padding(end = 12.dp).size(24.dp))
                } else {
                    TextButton(
                        modifier = Modifier.align(Alignment.CenterEnd),
                        onClick = {
                            val org = organization.trim()
                            val r = role.trim()
                            if (org.isEmpty() || r.isEmpty()) return@TextButton
                            saving = true
                            errorText = null
                            scope.launch {
                                try {
                                    val saved = if (existing != null) {
                                        repository.updateCareer(
                                            id = existing.id,
                                            organization = org,
                                            role = r,
                                            startYear = startYear,
                                            endYear = if (isCurrent) null else endYear,
                                            isCurrent = isCurrent,
                                            description = description.trim().takeIf { it.isNotEmpty() },
                                            contribution = contribution.trim().takeIf { it.isNotEmpty() },
                                            linkUrl = linkUrl.trim().takeIf { it.isNotEmpty() },
                                            mediaUrl = mediaUrl.trim().takeIf { it.isNotEmpty() },
                                        )
                                    } else {
                                        repository.insertCareer(
                                            NewCareer(
                                                userId = userId,
                                                organization = org,
                                                role = r,
                                                startYear = startYear,
                                                endYear = if (isCurrent) null else endYear,
                                                isCurrent = isCurrent,
                                                description = description.trim().takeIf { it.isNotEmpty() },
                                                contribution = contribution.trim().takeIf { it.isNotEmpty() },
                                                linkUrl = linkUrl.trim().takeIf { it.isNotEmpty() },
                                                mediaUrl = mediaUrl.trim().takeIf { it.isNotEmpty() },
                                            )
                                        )
                                    }
                                    onSaved(saved)
                                    onDismiss()
                                } catch (e: Throwable) {
                                    errorText = e.message
                                } finally {
                                    saving = false
                                }
                            }
                        },
                        enabled = organization.trim().isNotEmpty() && role.trim().isNotEmpty(),
                    ) {
                        Text(
                            AppLocale.localized("저장", "Save", "Speichern"),
                            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                        )
                    }
                }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedTextField(
                    value = organization,
                    onValueChange = { organization = it },
                    label = { Text(AppLocale.localized("기관명", "Organization", "Organisation")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = role,
                    onValueChange = { role = it },
                    label = { Text(AppLocale.localized("역할/직책", "Role / Title", "Rolle / Titel")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = isCurrent, onCheckedChange = { isCurrent = it })
                    Text(AppLocale.localized("현재 재직중", "Currently working here", "Aktuell tätig"))
                }
                ExposedDropdownMenuBox(expanded = startExpanded, onExpandedChange = { startExpanded = it }) {
                    OutlinedTextField(
                        value = startYear?.toString() ?: "",
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(AppLocale.localized("시작년도", "Start Year", "Startjahr")) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(startExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                    )
                    ExposedDropdownMenu(expanded = startExpanded, onDismissRequest = { startExpanded = false }) {
                        DropdownMenuItem(text = { Text(AppLocale.localized("없음", "None", "Keiner")) }, onClick = { startYear = null; startExpanded = false })
                        years.forEach { yr -> DropdownMenuItem(text = { Text(yr.toString()) }, onClick = { startYear = yr; startExpanded = false }) }
                    }
                }
                if (!isCurrent) {
                    ExposedDropdownMenuBox(expanded = endExpanded, onExpandedChange = { endExpanded = it }) {
                        OutlinedTextField(
                            value = endYear?.toString() ?: "",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text(AppLocale.localized("종료년도", "End Year", "Endjahr")) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(endExpanded) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(),
                        )
                        ExposedDropdownMenu(expanded = endExpanded, onDismissRequest = { endExpanded = false }) {
                            DropdownMenuItem(text = { Text(AppLocale.localized("없음", "None", "Keiner")) }, onClick = { endYear = null; endExpanded = false })
                            years.forEach { yr -> DropdownMenuItem(text = { Text(yr.toString()) }, onClick = { endYear = yr; endExpanded = false }) }
                        }
                    }
                }
                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text(AppLocale.localized("설명 (선택)", "Description (optional)", "Beschreibung (optional)")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    maxLines = 5,
                )
                OutlinedTextField(
                    value = contribution,
                    onValueChange = { contribution = it },
                    label = { Text(AppLocale.localized("기여 내용 (선택)", "Contribution (optional)", "Beitrag (optional)")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    maxLines = 5,
                )
                OutlinedTextField(
                    value = linkUrl,
                    onValueChange = { linkUrl = it },
                    label = { Text(AppLocale.localized("관련 링크 (선택)", "Related link (optional)", "Relevanter Link (optional)")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                )
                OutlinedTextField(
                    value = mediaUrl,
                    onValueChange = { mediaUrl = it },
                    label = { Text(AppLocale.localized("영상 링크 (선택)", "Video link (optional)", "Videolink (optional)")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                )
                if (errorText != null) {
                    Text(errorText!!, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
                if (existing != null) {
                    Button(
                        onClick = { showDeleteConfirm = true },
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.errorContainer, contentColor = MaterialTheme.colorScheme.onErrorContainer),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(AppLocale.localized("삭제", "Delete", "Löschen"))
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }

    if (showDeleteConfirm && existing != null) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(AppLocale.localized("경력 삭제", "Delete Career", "Berufserfahrung löschen")) },
            text = { Text(AppLocale.localized("이 경력 항목을 삭제할까요?", "Delete this career entry?", "Diesen Eintrag löschen?")) },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        try { repository.deleteCareer(existing.id) } catch (_: Throwable) {}
                        onDeleted(existing.id)
                        onDismiss()
                    }
                }) { Text(AppLocale.localized("삭제", "Delete", "Löschen"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen")) }
            },
        )
    }
}
