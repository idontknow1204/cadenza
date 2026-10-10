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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Checkbox
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
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.Recommendation
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecommendationEditSheet(
    existing: Recommendation?,
    recipientId: String,
    repository: Repository,
    onDismiss: () -> Unit,
    onSaved: (Recommendation) -> Unit,
    onDeleted: (() -> Unit)? = null,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    var recommenderName by remember { mutableStateOf(existing?.recommenderName ?: "") }
    var recommenderTitle by remember { mutableStateOf(existing?.recommenderTitle ?: "") }
    var body by remember { mutableStateOf(existing?.body ?: "") }
    var isVisible by remember { mutableStateOf(existing?.isVisible ?: true) }
    var saving by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

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
                        AppLocale.localized("추천서 추가", "Add Recommendation", "Empfehlung")
                    else
                        AppLocale.localized("추천서 편집", "Edit Recommendation", "Empfehlung bearbeiten"),
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
                            val name = recommenderName.trim()
                            val b = body.trim()
                            if (name.isEmpty() || b.isEmpty()) return@TextButton
                            saving = true
                            errorText = null
                            scope.launch {
                                try {
                                    val rec = if (existing != null) {
                                        repository.updateRecommendation(
                                            id = existing.id,
                                            recommenderName = name,
                                            recommenderTitle = recommenderTitle.trim().takeIf { it.isNotEmpty() },
                                            body = b,
                                            isVisible = isVisible,
                                        )
                                        existing.copy(
                                            recommenderName = name,
                                            recommenderTitle = recommenderTitle.trim().takeIf { it.isNotEmpty() },
                                            body = b,
                                            isVisible = isVisible,
                                        )
                                    } else {
                                        repository.addRecommendation(
                                            recipientId = recipientId,
                                            recommenderName = name,
                                            recommenderTitle = recommenderTitle.trim().takeIf { it.isNotEmpty() },
                                            body = b,
                                        )
                                    }
                                    onSaved(rec)
                                    onDismiss()
                                } catch (e: Throwable) {
                                    errorText = e.message
                                } finally {
                                    saving = false
                                }
                            }
                        },
                        enabled = recommenderName.trim().isNotEmpty() && body.trim().isNotEmpty(),
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
                    value = recommenderName,
                    onValueChange = { recommenderName = it },
                    label = { Text(AppLocale.localized("추천인 이름", "Recommender Name", "Name des Empfehlenden")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = recommenderTitle,
                    onValueChange = { recommenderTitle = it },
                    label = { Text(AppLocale.localized("직책/소속 (선택)", "Title / Affiliation (optional)", "Titel / Zugehörigkeit (optional)")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = body,
                    onValueChange = { body = it },
                    label = { Text(AppLocale.localized("추천 내용", "Recommendation Text", "Empfehlungstext")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    maxLines = 8,
                )
                if (existing != null) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = isVisible, onCheckedChange = { isVisible = it })
                        Text(AppLocale.localized("공개적으로 표시", "Show publicly", "Öffentlich anzeigen"))
                    }
                }
                if (errorText != null) {
                    Text(errorText!!, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
                if (existing != null && onDeleted != null) {
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

    if (showDeleteConfirm && existing != null && onDeleted != null) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(AppLocale.localized("추천서 삭제", "Delete Recommendation", "Empfehlung löschen")) },
            text = { Text(AppLocale.localized("이 추천서를 삭제할까요?", "Delete this recommendation?", "Diese Empfehlung löschen?")) },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        try { repository.deleteRecommendation(existing.id) } catch (_: Throwable) {}
                        onDeleted()
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
