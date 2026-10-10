package com.cadenza.android.ui.profile.sheets

import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.AssistChip
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
import androidx.compose.material3.Surface
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import com.cadenza.android.core.data.model.Affiliation
import com.cadenza.android.core.data.model.NewAffiliation
import com.cadenza.android.core.data.model.Profile
import com.cadenza.android.core.data.model.Visibility
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun EditProfileSheet(
    profile: Profile,
    existingAffiliation: Affiliation?,
    userId: String,
    repository: Repository,
    onDismiss: () -> Unit,
    onSaved: (Profile, Affiliation?) -> Unit,
) {
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    var realName by remember { mutableStateOf(profile.realName) }
    var major by remember { mutableStateOf(profile.major ?: "") }
    var instrument by remember { mutableStateOf(profile.instrument ?: "") }
    var bio by remember { mutableStateOf(profile.bio ?: "") }
    var homeCities by remember { mutableStateOf(profile.homeCities.toMutableSet()) }
    var defaultVisibility by remember { mutableStateOf(profile.defaultVisibility) }
    var institutionName by remember { mutableStateOf(existingAffiliation?.institutionName ?: "") }
    var selectedAvatarUri by remember { mutableStateOf<Uri?>(null) }

    var majorExpanded by remember { mutableStateOf(false) }
    var instrumentExpanded by remember { mutableStateOf(false) }
    var visibilityExpanded by remember { mutableStateOf(false) }
    var cityPickerExpanded by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }

    val availableInstruments = remember(major) { OnboardingData.instrumentsByMajor[major] ?: emptyList() }

    val pickMedia = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        selectedAvatarUri = uri
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
                    AppLocale.localized("프로필 편집", "Edit Profile", "Profil bearbeiten"),
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
                            val name = realName.trim()
                            if (name.isEmpty()) return@TextButton
                            saving = true
                            errorText = null
                            scope.launch {
                                try {
                                    // Upload avatar if selected
                                    selectedAvatarUri?.let { uri ->
                                        context.contentResolver.openInputStream(uri)?.use { stream ->
                                            runCatching { repository.uploadAvatar(userId, stream.readBytes()) }
                                        }
                                    }
                                    val updatedProfile = repository.updateProfileDetails(
                                        id = userId,
                                        realName = name,
                                        major = major.takeIf { it.isNotEmpty() },
                                        instrument = instrument.takeIf { it.isNotEmpty() },
                                        homeCities = homeCities.sorted(),
                                        bio = bio.trim(),
                                        defaultVisibility = defaultVisibility,
                                    )
                                    var savedAff = existingAffiliation
                                    val instName = institutionName.trim()
                                    if (instName.isNotEmpty()) {
                                        savedAff = if (existingAffiliation != null) {
                                            repository.updateAffiliation(
                                                id = existingAffiliation.id,
                                                institutionName = instName,
                                                courseType = existingAffiliation.courseType,
                                                enrollmentYear = existingAffiliation.enrollmentYear,
                                                graduationYear = existingAffiliation.graduationYear,
                                                isCurrent = existingAffiliation.isCurrent,
                                            )
                                        } else {
                                            repository.insertAffiliation(
                                                NewAffiliation(
                                                    userId = userId,
                                                    institutionName = instName,
                                                )
                                            )
                                        }
                                    }
                                    onSaved(updatedProfile, savedAff)
                                    onDismiss()
                                } catch (e: Throwable) {
                                    errorText = e.message
                                } finally {
                                    saving = false
                                }
                            }
                        },
                        enabled = realName.trim().isNotEmpty(),
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
                // Avatar
                Box(modifier = Modifier.align(Alignment.CenterHorizontally)) {
                    if (selectedAvatarUri != null) {
                        AsyncImage(
                            model = selectedAvatarUri,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.size(88.dp).clip(CircleShape),
                        )
                    } else if (!profile.avatarUrl.isNullOrEmpty()) {
                        AsyncImage(
                            model = profile.avatarUrl,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.size(88.dp).clip(CircleShape),
                        )
                    } else {
                        Surface(
                            shape = CircleShape,
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            modifier = Modifier.size(88.dp),
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(Icons.Outlined.Person, contentDescription = null, modifier = Modifier.size(48.dp))
                            }
                        }
                    }
                    Surface(
                        onClick = { pickMedia.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .size(28.dp)
                            .align(Alignment.BottomEnd),
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Outlined.Edit, contentDescription = null, modifier = Modifier.size(14.dp), tint = MaterialTheme.colorScheme.onPrimary)
                        }
                    }
                }

                // Name
                OutlinedTextField(
                    value = realName,
                    onValueChange = { realName = it },
                    label = { Text(AppLocale.localized("이름", "Name", "Name")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                // Major
                ExposedDropdownMenuBox(expanded = majorExpanded, onExpandedChange = { majorExpanded = it }) {
                    OutlinedTextField(
                        value = OnboardingData.majors.firstOrNull { it.id == major }?.localizedName ?: "",
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(AppLocale.localized("전공", "Major", "Hauptfach")) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(majorExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                    )
                    ExposedDropdownMenu(expanded = majorExpanded, onDismissRequest = { majorExpanded = false }) {
                        DropdownMenuItem(text = { Text(AppLocale.localized("없음", "None", "Keiner")) }, onClick = { major = ""; instrument = ""; majorExpanded = false })
                        OnboardingData.majors.forEach { m ->
                            DropdownMenuItem(text = { Text(m.localizedName) }, onClick = {
                                major = m.id
                                if (availableInstruments.none { it.id == instrument }) instrument = ""
                                majorExpanded = false
                            })
                        }
                    }
                }

                // Instrument
                if (availableInstruments.isNotEmpty()) {
                    ExposedDropdownMenuBox(expanded = instrumentExpanded, onExpandedChange = { instrumentExpanded = it }) {
                        OutlinedTextField(
                            value = availableInstruments.firstOrNull { it.id == instrument }?.localizedName ?: "",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text(AppLocale.localized("악기", "Instrument", "Instrument")) },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(instrumentExpanded) },
                            modifier = Modifier.fillMaxWidth().menuAnchor(),
                        )
                        ExposedDropdownMenu(expanded = instrumentExpanded, onDismissRequest = { instrumentExpanded = false }) {
                            DropdownMenuItem(text = { Text(AppLocale.localized("없음", "None", "Keiner")) }, onClick = { instrument = ""; instrumentExpanded = false })
                            availableInstruments.forEach { inst ->
                                DropdownMenuItem(text = { Text(inst.localizedName) }, onClick = { instrument = inst.id; instrumentExpanded = false })
                            }
                        }
                    }
                }

                // Institution (simplified)
                OutlinedTextField(
                    value = institutionName,
                    onValueChange = { institutionName = it },
                    label = { Text(AppLocale.localized("소속 학교", "School / University", "Schule / Universität")) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )

                // Bio
                OutlinedTextField(
                    value = bio,
                    onValueChange = { bio = it },
                    label = { Text(AppLocale.localized("소개글", "Bio", "Über mich")) },
                    modifier = Modifier.fillMaxWidth(),
                    minLines = 3,
                    maxLines = 6,
                )

                // Cities
                Text(
                    AppLocale.localized("활동 도시", "Home Cities", "Heimatstädte"),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (homeCities.isNotEmpty()) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        homeCities.toList().forEach { id ->
                            val city = OnboardingData.cityOptions.firstOrNull { it.id == id }
                            if (city != null) {
                                AssistChip(
                                    onClick = { homeCities = (homeCities - id).toMutableSet() },
                                    label = { Text(city.localizedName) },
                                    trailingIcon = { Icon(Icons.Outlined.Close, contentDescription = null, modifier = Modifier.size(14.dp)) },
                                )
                            }
                        }
                    }
                }
                ExposedDropdownMenuBox(expanded = cityPickerExpanded, onExpandedChange = { cityPickerExpanded = it }) {
                    TextButton(
                        onClick = { cityPickerExpanded = true },
                        modifier = Modifier.menuAnchor(),
                    ) {
                        Text(AppLocale.localized("도시 추가", "Add city", "Stadt hinzufügen"))
                    }
                    ExposedDropdownMenu(expanded = cityPickerExpanded, onDismissRequest = { cityPickerExpanded = false }) {
                        OnboardingData.cityOptions.filter { it.id !in homeCities }.forEach { city ->
                            DropdownMenuItem(
                                text = { Text("${city.flag} ${city.localizedName}") },
                                onClick = { homeCities = (homeCities + city.id).toMutableSet(); cityPickerExpanded = false },
                            )
                        }
                    }
                }

                // Visibility
                ExposedDropdownMenuBox(expanded = visibilityExpanded, onExpandedChange = { visibilityExpanded = it }) {
                    OutlinedTextField(
                        value = defaultVisibility.localizedLabel,
                        onValueChange = {},
                        readOnly = true,
                        label = { Text(AppLocale.localized("기본 공개 범위", "Default Visibility", "Standard-Sichtbarkeit")) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(visibilityExpanded) },
                        modifier = Modifier.fillMaxWidth().menuAnchor(),
                    )
                    ExposedDropdownMenu(expanded = visibilityExpanded, onDismissRequest = { visibilityExpanded = false }) {
                        Visibility.entries.forEach { v ->
                            DropdownMenuItem(text = { Text(v.localizedLabel) }, onClick = { defaultVisibility = v; visibilityExpanded = false })
                        }
                    }
                }

                if (errorText != null) {
                    Text(errorText!!, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}
