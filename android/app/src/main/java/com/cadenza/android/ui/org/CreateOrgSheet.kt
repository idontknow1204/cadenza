package com.cadenza.android.ui.org

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
import androidx.compose.material3.Button
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.OrgCategory
import com.cadenza.android.core.data.model.Organization
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateOrgSheet(
    userId: String,
    repository: Repository,
    onDismiss: () -> Unit,
    onCreated: (Organization) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    var name by remember { mutableStateOf("") }
    var handle by remember { mutableStateOf("") }
    var handleEdited by remember { mutableStateOf(false) }
    var handleError by remember { mutableStateOf<String?>(null) }
    var category by remember { mutableStateOf(OrgCategory.ORCHESTRA) }
    var description by remember { mutableStateOf("") }
    var website by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var categoryExpanded by remember { mutableStateOf(false) }

    val canSubmit = name.isNotEmpty() && handle.length >= 3 && handleError == null && !busy

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .imePadding()
                .padding(horizontal = 16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                TextButton(onClick = onDismiss) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen")) }
                Text(
                    AppLocale.localized("기관 페이지 만들기", "Create Organization", "Organisation erstellen"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                if (busy) {
                    CircularProgressIndicator(modifier = Modifier.size(24.dp))
                } else {
                    Button(
                        onClick = {
                            if (!canSubmit) return@Button
                            busy = true; errorText = null
                            scope.launch {
                                try {
                                    val org = repository.createOrg(
                                        name = name.trim(),
                                        handle = handle.trim(),
                                        category = category,
                                        description = description.trim().takeIf { it.isNotEmpty() },
                                        website = website.trim().takeIf { it.isNotEmpty() },
                                        createdBy = userId,
                                    )
                                    onCreated(org)
                                } catch (e: Exception) {
                                    errorText = e.message
                                    busy = false
                                }
                            }
                        },
                        enabled = canSubmit,
                    ) { Text(AppLocale.localized("만들기", "Create", "Erstellen")) }
                }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            // Preview header
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OrgAvatarView(category = category, size = 52.dp)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        name.ifEmpty { AppLocale.localized("기관 이름", "Organization name", "Organisationsname") },
                        style = MaterialTheme.typography.titleSmall,
                        color = if (name.isEmpty()) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
                    )
                    Text(category.label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            Column(
                modifier = Modifier
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { v ->
                        name = v
                        if (!handleEdited) handle = makeHandle(v)
                    },
                    label = { Text(AppLocale.localized("기관 이름 *", "Name *", "Name *")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                OutlinedTextField(
                    value = handle,
                    onValueChange = { v ->
                        handleEdited = true
                        val sanitized = v.filter { it.isLetterOrDigit() || it == '_' || it == '.' }
                        handle = sanitized
                        handleError = if (sanitized.length < 3) AppLocale.localized("3자 이상 입력하세요", "Minimum 3 characters", "Mindestens 3 Zeichen") else null
                    },
                    label = { Text(AppLocale.localized("핸들 *", "Handle *", "Handle *")) },
                    prefix = { Text("@") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    isError = handleError != null,
                    supportingText = handleError?.let { { Text(it) } },
                )

                // Category picker
                ExposedDropdownMenuBox(
                    expanded = categoryExpanded,
                    onExpandedChange = { categoryExpanded = it },
                ) {
                    OutlinedTextField(
                        value = category.label,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(AppLocale.localized("분야", "Category", "Kategorie")) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = categoryExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(MenuAnchorType.PrimaryNotEditable),
                    )
                    ExposedDropdownMenu(expanded = categoryExpanded, onDismissRequest = { categoryExpanded = false }) {
                        OrgCategory.entries.forEach { c ->
                            DropdownMenuItem(
                                text = { Text(c.label) },
                                leadingIcon = { OrgAvatarView(category = c, size = 28.dp) },
                                onClick = { category = c; categoryExpanded = false },
                            )
                        }
                    }
                }

                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text(AppLocale.localized("기관 소개 (선택)", "Description", "Beschreibung")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    maxLines = 6,
                )
                OutlinedTextField(
                    value = website,
                    onValueChange = { website = it },
                    label = { Text(AppLocale.localized("웹사이트 (선택)", "Website", "Website")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                if (errorText != null) {
                    Text(errorText!!, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

private fun makeHandle(name: String): String =
    name.lowercase().filter { it.isLetterOrDigit() || it.isWhitespace() }
        .replace(" ", "_").take(30)
