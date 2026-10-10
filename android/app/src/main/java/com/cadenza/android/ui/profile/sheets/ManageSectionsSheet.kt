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
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.ProfileSection
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ManageSectionsSheet(
    visibleSections: List<String>,
    onDismiss: () -> Unit,
    onSave: suspend (List<String>) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    var selected by remember(visibleSections) { mutableStateOf(visibleSections.toMutableSet()) }
    var saving by remember { mutableStateOf(false) }

    val allSections = ProfileSection.entries.toList()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .padding(horizontal = 16.dp),
        ) {
            Box(modifier = Modifier.fillMaxWidth().height(48.dp)) {
                TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterStart)) {
                    Text(AppLocale.localized("취소", "Cancel", "Abbrechen"), style = MaterialTheme.typography.bodyLarge)
                }
                Text(
                    AppLocale.localized("프로필 섹션 관리", "Profile Sections", "Profilabschnitte"),
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
                            scope.launch {
                                try { onSave(selected.toList()) } finally { saving = false }
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
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                allSections.forEach { section ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Checkbox(
                            checked = selected.contains(section.raw),
                            onCheckedChange = { checked ->
                                selected = if (checked) {
                                    (selected + section.raw).toMutableSet()
                                } else {
                                    (selected - section.raw).toMutableSet()
                                }
                            },
                        )
                        Text(
                            section.title,
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
