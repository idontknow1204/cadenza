package com.cadenza.android.ui.profile.sheets

import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.ProfileLanguage
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

private val commonLanguages = listOf("한국어", "English", "Deutsch", "日本語", "中文", "Français", "Español", "Italiano", "Русский", "Português")
private val languageLevels = listOf("native", "fluent", "intermediate", "basic")

private fun levelLabel(level: String): String = when (level) {
    "native"       -> AppLocale.localized("모국어", "Native",        "Muttersprache")
    "fluent"       -> AppLocale.localized("유창",   "Fluent",        "Fließend")
    "intermediate" -> AppLocale.localized("중급",   "Intermediate",  "Mittel")
    else           -> AppLocale.localized("기초",   "Basic",         "Grundkenntnisse")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LanguageEditSheet(
    userId: String,
    current: List<ProfileLanguage>,
    repository: Repository,
    onDismiss: () -> Unit,
    onSaved: (List<ProfileLanguage>) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val languages = remember { mutableStateListOf<ProfileLanguage>().also { it.addAll(current) } }
    var newLanguage by remember { mutableStateOf("") }
    var newLevel by remember { mutableStateOf("native") }
    var langExpanded by remember { mutableStateOf(false) }
    var levelExpanded by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }

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
                    AppLocale.localized("언어", "Languages", "Sprachen"),
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
                            saving = true
                            errorText = null
                            scope.launch {
                                try {
                                    // Delete removed, upsert remaining
                                    val currentIds = current.map { it.id }.toSet()
                                    val updatedIds = languages.map { it.id }.toSet()
                                    currentIds.filter { it !in updatedIds }.forEach {
                                        runCatching { repository.deleteLanguage(it) }
                                    }
                                    val result = languages.map { lang ->
                                        runCatching {
                                            if (lang.id in currentIds) {
                                                repository.upsertLanguage(userId, lang.language, lang.level)
                                            } else {
                                                repository.upsertLanguage(userId, lang.language, lang.level)
                                            }
                                        }.getOrElse { lang }
                                    }
                                    onSaved(result)
                                    onDismiss()
                                } catch (e: Throwable) {
                                    errorText = e.message
                                } finally {
                                    saving = false
                                }
                            }
                        },
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
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                languages.forEachIndexed { index, lang ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(lang.language, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                        Text(levelLabel(lang.level), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        IconButton(onClick = { languages.removeAt(index) }, modifier = Modifier.size(32.dp)) {
                            Icon(Icons.Outlined.Delete, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(18.dp))
                        }
                    }
                    if (index < languages.lastIndex) HorizontalDivider()
                }
                if (languages.isNotEmpty()) {
                    HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))
                }
                Text(AppLocale.localized("언어 추가", "Add Language", "Sprache hinzufügen"), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    ExposedDropdownMenuBox(
                        expanded = langExpanded,
                        onExpandedChange = { langExpanded = it },
                        modifier = Modifier.weight(1f),
                    ) {
                        OutlinedTextField(
                            value = newLanguage,
                            onValueChange = { newLanguage = it },
                            label = { Text(AppLocale.localized("언어", "Language", "Sprache")) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(langExpanded) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(),
                        )
                        ExposedDropdownMenu(expanded = langExpanded, onDismissRequest = { langExpanded = false }) {
                            commonLanguages.forEach { lang ->
                                DropdownMenuItem(text = { Text(lang) }, onClick = { newLanguage = lang; langExpanded = false })
                            }
                        }
                    }
                    ExposedDropdownMenuBox(
                        expanded = levelExpanded,
                        onExpandedChange = { levelExpanded = it },
                        modifier = Modifier.weight(1f),
                    ) {
                        OutlinedTextField(
                            value = levelLabel(newLevel),
                            onValueChange = {},
                            readOnly = true,
                            label = { Text(AppLocale.localized("수준", "Level", "Niveau")) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(levelExpanded) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(),
                        )
                        ExposedDropdownMenu(expanded = levelExpanded, onDismissRequest = { levelExpanded = false }) {
                            languageLevels.forEach { lvl ->
                                DropdownMenuItem(text = { Text(levelLabel(lvl)) }, onClick = { newLevel = lvl; levelExpanded = false })
                            }
                        }
                    }
                }
                Button(
                    onClick = {
                        val lang = newLanguage.trim()
                        if (lang.isNotEmpty() && languages.none { it.language == lang }) {
                            languages.add(ProfileLanguage(id = java.util.UUID.randomUUID().toString(), userId = userId, language = lang, level = newLevel))
                            newLanguage = ""
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = newLanguage.trim().isNotEmpty(),
                ) {
                    Text(AppLocale.localized("추가", "Add", "Hinzufügen"))
                }
                if (errorText != null) {
                    Text(errorText!!, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
