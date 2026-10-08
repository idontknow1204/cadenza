package com.cadenza.android.ui.profile.sheets

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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.ProfileAward
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AwardEditSheet(
    existing: ProfileAward?,
    userId: String,
    repository: Repository,
    onDismiss: () -> Unit,
    onSaved: (ProfileAward) -> Unit,
    onDeleted: (String) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val years = OnboardingData.enrollmentYears

    var title by remember { mutableStateOf(existing?.title ?: "") }
    var prize by remember { mutableStateOf(existing?.prize ?: "") }
    var issuer by remember { mutableStateOf(existing?.issuer ?: "") }
    var year by remember { mutableIntStateOf(existing?.year ?: java.util.Calendar.getInstance().get(java.util.Calendar.YEAR)) }
    var details by remember { mutableStateOf(existing?.details ?: "") }
    var linkUrl by remember { mutableStateOf(existing?.linkUrl ?: "") }
    var saving by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var yearExpanded by remember { mutableStateOf(false) }

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
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                TextButton(onClick = onDismiss) {
                    Text(AppLocale.localized("취소", "Cancel", "Abbrechen"))
                }
                Text(
                    if (existing == null)
                        AppLocale.localized("수상 경력 추가", "Add Award", "Auszeichnung hinzufügen")
                    else
                        AppLocale.localized("수상 경력 편집", "Edit Award", "Auszeichnung bearbeiten"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                if (saving) {
                    CircularProgressIndicator(modifier = Modifier.height(24.dp))
                } else {
                    Button(
                        onClick = {
                            val t = title.trim()
                            val p = prize.trim()
                            val iss = issuer.trim()
                            if (t.isEmpty() || p.isEmpty() || iss.isEmpty()) return@Button
                            saving = true
                            errorText = null
                            scope.launch {
                                try {
                                    val award = ProfileAward(
                                        id = existing?.id ?: UUID.randomUUID().toString(),
                                        userId = userId,
                                        title = t,
                                        prize = p,
                                        issuer = iss,
                                        year = year,
                                        details = details.trim(),
                                        linkUrl = linkUrl.trim(),
                                    )
                                    val saved = if (existing != null) {
                                        repository.updateAward(award)
                                    } else {
                                        repository.insertAward(award)
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
                        enabled = title.trim().isNotEmpty() && prize.trim().isNotEmpty() && issuer.trim().isNotEmpty(),
                    ) {
                        Text(AppLocale.localized("저장", "Save", "Speichern"))
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
                    value = title,
                    onValueChange = { title = it },
                    label = { Text(AppLocale.localized("대회/행사명", "Competition/Event Name", "Wettbewerb/Veranstaltungsname")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = prize,
                    onValueChange = { prize = it },
                    label = { Text(AppLocale.localized("수상 내역", "Prize / Award", "Preis / Auszeichnung")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = issuer,
                    onValueChange = { issuer = it },
                    label = { Text(AppLocale.localized("주최 기관", "Issuing Organization", "Ausgebende Organisation")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                ExposedDropdownMenuBox(expanded = yearExpanded, onExpandedChange = { yearExpanded = it }) {
                    OutlinedTextField(
                        value = year.toString(),
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(AppLocale.localized("수상년도", "Year", "Jahr")) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(yearExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                    )
                    ExposedDropdownMenu(expanded = yearExpanded, onDismissRequest = { yearExpanded = false }) {
                        years.forEach { yr -> DropdownMenuItem(text = { Text(yr.toString()) }, onClick = { year = yr; yearExpanded = false }) }
                    }
                }
                OutlinedTextField(
                    value = details,
                    onValueChange = { details = it },
                    label = { Text(AppLocale.localized("상세 내용 (선택)", "Details (optional)", "Details (optional)")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 2,
                    maxLines = 4,
                )
                OutlinedTextField(
                    value = linkUrl,
                    onValueChange = { linkUrl = it },
                    label = { Text(AppLocale.localized("관련 링크 (선택)", "Link (optional)", "Link (optional)")) },
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
            title = { Text(AppLocale.localized("수상 경력 삭제", "Delete Award", "Auszeichnung löschen")) },
            text = { Text(AppLocale.localized("이 항목을 삭제할까요?", "Delete this entry?", "Diesen Eintrag löschen?")) },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        try { repository.deleteAward(existing.id, userId) } catch (_: Throwable) {}
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
