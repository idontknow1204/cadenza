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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.Affiliation
import com.cadenza.android.core.data.model.NewAffiliation
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AffiliationEditSheet(
    existing: Affiliation?,
    userId: String,
    repository: Repository,
    onDismiss: () -> Unit,
    onSaved: (Affiliation) -> Unit,
    onDeleted: (String) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    var institutionName by remember { mutableStateOf(existing?.institutionName ?: "") }
    var courseType by remember { mutableStateOf(existing?.courseType) }
    var enrollmentYear by remember { mutableIntStateOf(existing?.enrollmentYear ?: java.util.Calendar.getInstance().get(java.util.Calendar.YEAR)) }
    var graduationYear by remember { mutableStateOf(existing?.graduationYear) }
    var isCurrent by remember { mutableStateOf(existing?.isCurrent ?: true) }
    var saving by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    var courseExpanded by remember { mutableStateOf(false) }
    var enrollExpanded by remember { mutableStateOf(false) }
    var gradExpanded by remember { mutableStateOf(false) }

    val years = OnboardingData.enrollmentYears

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
                        AppLocale.localized("학력 추가", "Add Education", "Ausbildung hinzufügen")
                    else
                        AppLocale.localized("학력 편집", "Edit Education", "Ausbildung bearbeiten"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                if (saving) {
                    CircularProgressIndicator(modifier = Modifier.height(24.dp))
                } else {
                    Button(
                        onClick = {
                            val name = institutionName.trim()
                            if (name.isEmpty()) return@Button
                            saving = true
                            errorText = null
                            scope.launch {
                                try {
                                    val saved = if (existing != null) {
                                        repository.updateAffiliation(
                                            id = existing.id,
                                            institutionName = name,
                                            courseType = courseType,
                                            enrollmentYear = enrollmentYear,
                                            graduationYear = if (isCurrent) graduationYear else graduationYear,
                                            isCurrent = isCurrent,
                                        )
                                    } else {
                                        repository.insertAffiliation(
                                            NewAffiliation(
                                                userId = userId,
                                                institutionName = name,
                                                courseType = courseType,
                                                enrollmentYear = enrollmentYear,
                                                graduationYear = graduationYear,
                                                isCurrent = isCurrent,
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
                        enabled = institutionName.trim().isNotEmpty(),
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
                    value = institutionName,
                    onValueChange = { institutionName = it },
                    label = { Text(AppLocale.localized("학교 이름", "School Name", "Schulname")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                ExposedDropdownMenuBox(expanded = courseExpanded, onExpandedChange = { courseExpanded = it }) {
                    OutlinedTextField(
                        value = courseType?.let { ct -> OnboardingData.courseOptions.firstOrNull { it.id == ct }?.label } ?: "",
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(AppLocale.localized("과정", "Course", "Studiengang")) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(courseExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                    )
                    ExposedDropdownMenu(expanded = courseExpanded, onDismissRequest = { courseExpanded = false }) {
                        DropdownMenuItem(text = { Text(AppLocale.localized("없음", "None", "Keiner")) }, onClick = { courseType = null; courseExpanded = false })
                        OnboardingData.courseOptions.forEach { opt ->
                            DropdownMenuItem(text = { Text(opt.label) }, onClick = { courseType = opt.id; courseExpanded = false })
                        }
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(checked = isCurrent, onCheckedChange = { isCurrent = it })
                    Text(AppLocale.localized("재학중", "Currently enrolled", "Aktuell eingeschrieben"))
                }
                ExposedDropdownMenuBox(expanded = enrollExpanded, onExpandedChange = { enrollExpanded = it }) {
                    OutlinedTextField(
                        value = enrollmentYear.toString(),
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(AppLocale.localized("입학년도", "Enrollment Year", "Einschreibejahr")) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(enrollExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                    )
                    ExposedDropdownMenu(expanded = enrollExpanded, onDismissRequest = { enrollExpanded = false }) {
                        years.forEach { yr ->
                            DropdownMenuItem(text = { Text(yr.toString()) }, onClick = { enrollmentYear = yr; enrollExpanded = false })
                        }
                    }
                }
                ExposedDropdownMenuBox(expanded = gradExpanded, onExpandedChange = { gradExpanded = it }) {
                    OutlinedTextField(
                        value = graduationYear?.toString() ?: "",
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(AppLocale.localized("졸업년도 (예정)", "Graduation Year", "Abschlussjahr")) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(gradExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                    )
                    ExposedDropdownMenu(expanded = gradExpanded, onDismissRequest = { gradExpanded = false }) {
                        DropdownMenuItem(text = { Text(AppLocale.localized("없음", "None", "Keiner")) }, onClick = { graduationYear = null; gradExpanded = false })
                        years.forEach { yr ->
                            DropdownMenuItem(text = { Text(yr.toString()) }, onClick = { graduationYear = yr; gradExpanded = false })
                        }
                    }
                }
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
            title = { Text(AppLocale.localized("학력 삭제", "Delete Education", "Ausbildung löschen")) },
            text = { Text(AppLocale.localized("이 학력 항목을 삭제할까요?", "Delete this education entry?", "Diesen Eintrag löschen?")) },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        try { repository.deleteAffiliation(existing.id) } catch (_: Throwable) {}
                        onDeleted(existing.id)
                        onDismiss()
                    }
                }) { Text(AppLocale.localized("삭제", "Delete", "Löschen"), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text(AppLocale.localized("취소", "Cancel", "Abbrechen"))
                }
            },
        )
    }
}
