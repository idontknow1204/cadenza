package com.cadenza.android.ui.cv

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.CVEntryRow
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch
import java.util.UUID

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CVEntryComposerSheet(
    userId: String,
    repository: Repository,
    existing: CVEntryRow?,
    initialKind: String = "performance",
    onDismiss: () -> Unit,
    onSaved: (CVEntryRow) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    var kind        by remember { mutableStateOf(existing?.kind ?: initialKind) }
    var yearText    by remember { mutableStateOf("") }
    var period      by remember { mutableStateOf("") }
    var title       by remember { mutableStateOf("") }
    var org         by remember { mutableStateOf("") }
    var place       by remember { mutableStateOf("") }
    var detail      by remember { mutableStateOf("") }
    var result      by remember { mutableStateOf("") }
    var institution by remember { mutableStateOf("") }
    var degree      by remember { mutableStateOf("") }
    var teacher     by remember { mutableStateOf("") }
    var busy        by remember { mutableStateOf(false) }
    var errorText   by remember { mutableStateOf<String?>(null) }
    var kindExpanded by remember { mutableStateOf(false) }

    LaunchedEffect(existing) {
        if (existing != null) {
            yearText    = existing.year?.toString() ?: ""
            period      = existing.period ?: ""
            title       = existing.title ?: ""
            org         = existing.org ?: ""
            place       = existing.place ?: ""
            detail      = existing.detail ?: ""
            result      = existing.result ?: ""
            institution = existing.institution ?: ""
            degree      = existing.degree ?: ""
            teacher     = existing.teacher ?: ""
        }
    }

    val kinds = listOf(
        "performance" to AppLocale.localized("연주", "Performance", "Auftritt"),
        "competition" to AppLocale.localized("콩쿠르", "Competition", "Wettbewerb"),
        "education"   to AppLocale.localized("학력", "Education", "Ausbildung"),
        "masterclass" to AppLocale.localized("마스터클래스", "Masterclass", "Meisterkurs"),
    )
    val kindLabel = kinds.firstOrNull { it.first == kind }?.second ?: kind

    val isValid = if (kind == "education" || kind == "masterclass") institution.isNotBlank() else title.isNotBlank()

    fun trimmedOrNull(v: String): String? = v.trim().takeIf { it.isNotEmpty() }

    fun extractYear(text: String): Int? {
        var digits = ""
        for (ch in text) {
            if (ch.isDigit()) {
                digits += ch
                if (digits.length == 4) return digits.toIntOrNull()
            } else digits = ""
        }
        return null
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
                .imePadding()
                .padding(horizontal = 16.dp),
        ) {
            // Toolbar
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
            ) {
                TextButton(onClick = onDismiss) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen")) }
                Text(
                    if (existing == null) AppLocale.localized("항목 추가", "Add entry", "Eintrag hinzufügen")
                    else AppLocale.localized("항목 편집", "Edit entry", "Eintrag bearbeiten"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                if (busy) CircularProgressIndicator(modifier = Modifier.size(24.dp))
                else TextButton(
                    onClick = {
                        if (!isValid) return@TextButton
                        busy = true; errorText = null
                        scope.launch {
                            try {
                                val yr = if (kind == "education") extractYear(period) else yearText.trim().toIntOrNull()
                                val row = CVEntryRow(
                                    id = existing?.id ?: UUID.randomUUID().toString(),
                                    kind = kind,
                                    year = yr,
                                    period = trimmedOrNull(period),
                                    title = trimmedOrNull(title),
                                    org = trimmedOrNull(org),
                                    place = trimmedOrNull(place),
                                    detail = trimmedOrNull(detail),
                                    result = trimmedOrNull(result),
                                    institution = trimmedOrNull(institution),
                                    degree = trimmedOrNull(degree),
                                    teacher = trimmedOrNull(teacher),
                                )
                                if (existing == null) repository.createCVEntry(userId, row)
                                else repository.updateCVEntry(userId, row)
                                onSaved(row)
                            } catch (e: Exception) {
                                errorText = e.message
                                busy = false
                            }
                        }
                    },
                    enabled = isValid,
                ) {
                    Text(AppLocale.localized("저장", "Save", "Speichern"), fontWeight = FontWeight.SemiBold)
                }
            }
            HorizontalDivider(modifier = Modifier.padding(bottom = 12.dp))

            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Kind picker (disabled when editing)
                ExposedDropdownMenuBox(expanded = kindExpanded && existing == null, onExpandedChange = { if (existing == null) kindExpanded = it }) {
                    OutlinedTextField(
                        value = kindLabel,
                        onValueChange = {},
                        readOnly = true,
                        enabled = existing == null,
                        label = { Text(AppLocale.localized("유형", "Type", "Typ")) },
                        trailingIcon = { if (existing == null) ExposedDropdownMenuDefaults.TrailingIcon(expanded = kindExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                    )
                    ExposedDropdownMenu(expanded = kindExpanded, onDismissRequest = { kindExpanded = false }) {
                        kinds.forEach { (code, label) ->
                            DropdownMenuItem(text = { Text(label) }, onClick = { kind = code; kindExpanded = false })
                        }
                    }
                }

                // Kind-specific fields
                when (kind) {
                    "performance" -> {
                        CvField(AppLocale.localized("연도", "Year", "Jahr"), yearText, { yearText = it }, keyboardType = KeyboardType.Number)
                        CvField(AppLocale.localized("제목", "Title", "Titel"), title, { title = it })
                        CvField(AppLocale.localized("주최", "Organizer", "Veranstalter"), org, { org = it })
                        CvField(AppLocale.localized("장소", "Place", "Ort"), place, { place = it })
                        CvField(AppLocale.localized("설명", "Detail", "Detail"), detail, { detail = it })
                    }
                    "competition" -> {
                        CvField(AppLocale.localized("연도", "Year", "Jahr"), yearText, { yearText = it }, keyboardType = KeyboardType.Number)
                        CvField(AppLocale.localized("대회명", "Competition", "Wettbewerb"), title, { title = it })
                        CvField(AppLocale.localized("장소", "Place", "Ort"), place, { place = it })
                        CvField(AppLocale.localized("결과", "Result", "Ergebnis"), result, { result = it })
                    }
                    "education" -> {
                        CvField(AppLocale.localized("기간", "Period", "Zeitraum"), period, { period = it }, placeholder = "2020 – 2024")
                        CvField(AppLocale.localized("기관", "Institution", "Institution"), institution, { institution = it })
                        CvField(AppLocale.localized("학위", "Degree", "Abschluss"), degree, { degree = it })
                    }
                    "masterclass" -> {
                        CvField(AppLocale.localized("연도", "Year", "Jahr"), yearText, { yearText = it }, keyboardType = KeyboardType.Number)
                        CvField(AppLocale.localized("기관/행사", "Institution", "Institution"), institution, { institution = it })
                        CvField(AppLocale.localized("사사/강사", "Teacher", "Lehrer"), teacher, { teacher = it })
                        CvField(AppLocale.localized("장소", "Place", "Ort"), place, { place = it })
                    }
                }

                Text(
                    AppLocale.localized(
                        "CV에 들어가는 간단한 내용만 입력하세요. 기록(활동)과는 별개입니다. 번역은 저장 후 '항목 영어화'에서.",
                        "Enter only the brief content that appears on the CV. Separate from your activity records. Translate afterwards under 'English per entry'.",
                        "Nur kurze CV-Inhalte. Getrennt von den Aktivitäten. Übersetzung danach.",
                    ),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )

                errorText?.let { err ->
                    Text(err, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}

@Composable
private fun CvField(
    label: String,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String = "",
    keyboardType: KeyboardType = KeyboardType.Text,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        placeholder = if (placeholder.isNotEmpty()) { { Text(placeholder) } } else null,
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = keyboardType),
    )
}
