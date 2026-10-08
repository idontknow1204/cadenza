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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.CVOverride
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CVEntryOverrideSheet(
    entry: CVEntry,
    existing: CVOverride?,
    repository: Repository,
    userId: String,
    lang: String = "en",
    onDismiss: () -> Unit,
    onSaved: (CVOverride) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    val values = remember { mutableStateMapOf<String, String>() }
    var include     by remember { mutableStateOf(true) }
    var busy        by remember { mutableStateOf(false) }
    var translating by remember { mutableStateOf(false) }
    var suggested   by remember { mutableStateOf(false) }
    var errorText   by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(existing) {
        include = existing?.include ?: true
        values.clear()
        existing?.patch?.forEach { (k, v) -> values[k] = v }
        // Auto-suggest translation if no existing overrides
        if (existing?.patch.isNullOrEmpty()) {
            val originals = entry.fields.mapNotNull { f ->
                val o = f.original?.trim()?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                f.key to o
            }.toMap()
            if (originals.isNotEmpty()) {
                translating = true
                try {
                    val out = repository.translateCVEntry(entry.kind, originals, lang)
                    for ((k, v) in out) {
                        val t = v.trim()
                        if (t.isNotEmpty() && values[k].isNullOrEmpty()) values[k] = t
                    }
                    if (out.isNotEmpty()) suggested = true
                } catch (_: Exception) {
                    // Translation is non-critical
                } finally {
                    translating = false
                }
            }
        }
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
                    entry.titleOriginal,
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                    maxLines = 1,
                )
                if (busy) CircularProgressIndicator(modifier = Modifier.size(24.dp))
                else TextButton(
                    onClick = {
                        busy = true; errorText = null
                        scope.launch {
                            try {
                                val patch = values.entries
                                    .mapNotNull { (k, v) -> val t = v.trim(); if (t.isNotEmpty()) k to t else null }
                                    .toMap()
                                val override = CVOverride(
                                    sourceKind = entry.sourceKind,
                                    sourceId   = entry.sourceId,
                                    patch      = patch,
                                    include    = include,
                                )
                                repository.upsertCVOverride(userId, override, lang)
                                onSaved(override)
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
            HorizontalDivider(modifier = Modifier.padding(bottom = 12.dp))

            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(bottom = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // Include toggle
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(AppLocale.localized("CV에 포함", "Include in CV", "Im CV anzeigen"), style = MaterialTheme.typography.bodyMedium)
                        Text(
                            AppLocale.localized("끄면 이 항목은 CV에 나타나지 않습니다.", "Turn off to hide this entry from the CV.", "Aus: Eintrag erscheint nicht im Lebenslauf."),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Switch(checked = include, onCheckedChange = { include = it })
                }
                HorizontalDivider()

                // English fields header
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        AppLocale.localized("영어 표기", "English wording", "Englische Schreibweise"),
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.weight(1f),
                    )
                    if (translating) {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            CircularProgressIndicator(modifier = Modifier.size(14.dp), strokeWidth = 2.dp)
                            Text(
                                AppLocale.localized("번역 중…", "Translating…", "Übersetzt…"),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    } else {
                        TextButton(
                            onClick = {
                                scope.launch {
                                    translating = true
                                    try {
                                        val originals = entry.fields.mapNotNull { f ->
                                            val o = f.original?.trim()?.takeIf { it.isNotEmpty() } ?: return@mapNotNull null
                                            f.key to o
                                        }.toMap()
                                        if (originals.isNotEmpty()) {
                                            val out = repository.translateCVEntry(entry.kind, originals, lang)
                                            for ((k, v) in out) {
                                                val t = v.trim()
                                                if (t.isNotEmpty()) values[k] = t
                                            }
                                            if (out.isNotEmpty()) suggested = true
                                        }
                                    } catch (_: Exception) {}
                                    finally { translating = false }
                                }
                            },
                        ) {
                            Icon(Icons.Outlined.AutoAwesome, contentDescription = null, modifier = Modifier.size(14.dp))
                            Text(
                                " " + AppLocale.localized("AI 번역 제안", "AI translate", "KI-Übersetzung"),
                                style = MaterialTheme.typography.labelMedium,
                            )
                        }
                    }
                }

                // Fields
                entry.fields.forEach { field ->
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        OutlinedTextField(
                            value = values[field.key] ?: "",
                            onValueChange = { values[field.key] = it },
                            label = { Text(field.label) },
                            placeholder = {
                                Text(field.original ?: AppLocale.localized("영어로 입력", "Enter English", "Auf Englisch"))
                            },
                            modifier = Modifier.fillMaxWidth(),
                            singleLine = true,
                        )
                        if (!field.original.isNullOrEmpty()) {
                            Text(
                                AppLocale.localized("원문: ", "Original: ", "Original: ") + field.original,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                maxLines = 2,
                            )
                        }
                    }
                }

                Text(
                    if (suggested)
                        AppLocale.localized(
                            "✨ AI가 원문을 영어로 번역해 채웠어요. 자유롭게 수정하세요. 비운 필드는 원문이 쓰입니다.",
                            "✨ AI filled English suggestions from the original — edit freely. Blank fields fall back to the original.",
                            "✨ KI hat Vorschläge eingefügt — frei bearbeiten. Leere Felder nutzen das Original.",
                        )
                    else
                        AppLocale.localized(
                            "비운 필드는 원문이 그대로 CV에 쓰입니다.",
                            "Blank fields fall back to the original text on the CV.",
                            "Leere Felder nutzen den Originaltext.",
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
