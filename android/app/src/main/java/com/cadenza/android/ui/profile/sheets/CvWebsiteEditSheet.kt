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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.Profile
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CvWebsiteEditSheet(
    userId: String,
    currentCvUrl: String?,
    currentWebsiteUrl: String?,
    repository: Repository,
    onDismiss: () -> Unit,
    onSaved: (Profile) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    var cvUrl by remember { mutableStateOf(currentCvUrl ?: "") }
    var websiteUrl by remember { mutableStateOf(currentWebsiteUrl ?: "") }
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
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                TextButton(onClick = onDismiss) {
                    Text(AppLocale.localized("취소", "Cancel", "Abbrechen"))
                }
                Text(
                    AppLocale.localized("CV / 홈페이지", "CV / Website", "CV / Webseite"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                if (saving) {
                    CircularProgressIndicator(modifier = Modifier.height(24.dp))
                } else {
                    Button(
                        onClick = {
                            saving = true
                            errorText = null
                            scope.launch {
                                try {
                                    val updated = repository.updateProfileLinks(
                                        id = userId,
                                        cvUrl = cvUrl.trim().takeIf { it.isNotEmpty() },
                                        websiteUrl = websiteUrl.trim().takeIf { it.isNotEmpty() },
                                    )
                                    onSaved(updated)
                                    onDismiss()
                                } catch (e: Throwable) {
                                    errorText = e.message
                                } finally {
                                    saving = false
                                }
                            }
                        },
                    ) {
                        Text(AppLocale.localized("저장", "Save", "Speichern"))
                    }
                }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            Column(
                modifier = Modifier.padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    AppLocale.localized("CV / 이력서 URL", "CV / Resume URL", "CV / Lebenslauf URL"),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = cvUrl,
                    onValueChange = { cvUrl = it },
                    placeholder = { Text("https://...") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Uri,
                        imeAction = ImeAction.Next,
                    ),
                    singleLine = true,
                )
                Text(
                    AppLocale.localized("홈페이지 URL", "Website URL", "Webseite URL"),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = websiteUrl,
                    onValueChange = { websiteUrl = it },
                    placeholder = { Text("https://...") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Uri,
                        imeAction = ImeAction.Done,
                    ),
                    singleLine = true,
                )
                if (errorText != null) {
                    Text(
                        errorText!!,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
