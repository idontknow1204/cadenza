package com.cadenza.android.ui.profile.sheets

import androidx.compose.foundation.layout.Box
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Description
import androidx.compose.material.icons.outlined.UploadFile
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
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
    val context = LocalContext.current
    var cvUrl by remember { mutableStateOf(currentCvUrl ?: "") }
    var websiteUrl by remember { mutableStateOf(currentWebsiteUrl ?: "") }
    var saving by remember { mutableStateOf(false) }
    var uploadingPdf by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }

    val pickPdf = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        if (uri == null) return@rememberLauncherForActivityResult
        uploadingPdf = true
        errorText = null
        scope.launch {
            try {
                val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: return@launch
                cvUrl = repository.uploadCV(bytes)
            } catch (e: Throwable) {
                errorText = AppLocale.localized(
                    "PDF 업로드 실패: ${e.message}",
                    "PDF upload failed: ${e.message}",
                    "PDF-Upload fehlgeschlagen: ${e.message}",
                )
            } finally {
                uploadingPdf = false
            }
        }
    }

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
                    AppLocale.localized("CV / 홈페이지", "CV / Website", "CV / Webseite"),
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
                        Text(
                            AppLocale.localized("저장", "Save", "Speichern"),
                            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                        )
                    }
                }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            Column(
                modifier = Modifier.padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    AppLocale.localized("CV / 이력서", "CV / Resume", "CV / Lebenslauf"),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                // Show uploaded file name if cvUrl looks like a storage URL
                if (cvUrl.isNotEmpty() && cvUrl.contains("/cv/")) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(
                            Icons.Outlined.Description,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp),
                        )
                        Text(
                            cvUrl.substringAfterLast("/"),
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.weight(1f),
                            maxLines = 1,
                        )
                        IconButton(onClick = { cvUrl = "" }, modifier = Modifier.size(24.dp)) {
                            Icon(Icons.Outlined.Close, contentDescription = null, modifier = Modifier.size(16.dp))
                        }
                    }
                }
                if (uploadingPdf) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        Text(
                            AppLocale.localized("업로드 중…", "Uploading…", "Wird hochgeladen…"),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                } else {
                    Button(
                        onClick = { pickPdf.launch(arrayOf("application/pdf")) },
                        colors = ButtonDefaults.outlinedButtonColors(),
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(Icons.Outlined.UploadFile, contentDescription = null, modifier = Modifier.size(18.dp))
                        Text(
                            AppLocale.localized(
                                if (cvUrl.isEmpty()) "PDF 파일 업로드" else "파일 교체",
                                if (cvUrl.isEmpty()) "Upload PDF" else "Replace file",
                                if (cvUrl.isEmpty()) "PDF hochladen" else "Datei ersetzen",
                            ),
                            modifier = Modifier.padding(start = 6.dp),
                        )
                    }
                }
                if (cvUrl.isEmpty() || !cvUrl.contains("/cv/")) {
                    Text(
                        AppLocale.localized(
                            "또는 링크 붙여넣기 (Google Drive 등)",
                            "Or paste a link (Google Drive, etc.)",
                            "Oder Link einfügen (Google Drive, etc.)",
                        ),
                        style = MaterialTheme.typography.labelSmall,
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
                }
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
