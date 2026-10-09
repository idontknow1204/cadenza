package com.cadenza.android.ui.onboarding.steps

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.onboarding.OnboardingViewModel
import com.cadenza.android.ui.onboarding.components.OnboardingBottomBar
import com.cadenza.android.ui.onboarding.components.SelectChip

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun Step3AffiliationScreen(viewModel: OnboardingViewModel, userId: String) {
    val loc = AppLocale
    val institutionName by viewModel.institutionName.collectAsState()
    val courseType by viewModel.courseType.collectAsState()
    val enrollmentYear by viewModel.enrollmentYear.collectAsState()
    val homeCities by viewModel.homeCities.collectAsState()
    val isBusy by viewModel.isBusy.collectAsState()

    var schoolQuery by remember { mutableStateOf(institutionName) }
    var showSuggestions by remember { mutableStateOf(false) }
    var showCityPicker by remember { mutableStateOf(false) }

    val filteredSchools = remember(schoolQuery) {
        if (schoolQuery.isEmpty()) emptyList()
        else OnboardingData.schools.filter { it.contains(schoolQuery, ignoreCase = true) }
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            // Header
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    loc.localized("소속 학교", "School Affiliation", "Schulzugehörigkeit"),
                    fontSize = 26.sp, fontWeight = FontWeight.Bold,
                )
                Text(
                    loc.localized("현재 재학 중이거나 졸업한 학교를 입력해 주세요.", "Enter your current or most recent school.", "Gib deine aktuelle oder letzte Schule ein."),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // School search
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(loc.localized("학교명", "School", "Schule"), fontWeight = FontWeight.SemiBold)
                OutlinedTextField(
                    value = schoolQuery,
                    onValueChange = { v ->
                        schoolQuery = v
                        viewModel.institutionName.value = v
                        showSuggestions = v.isNotEmpty()
                    },
                    placeholder = { Text(loc.localized("학교 검색...", "Search school...", "Schule suchen...")) },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    singleLine = true,
                )
                if (showSuggestions && filteredSchools.isNotEmpty()) {
                    Card(shape = RoundedCornerShape(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Column {
                            filteredSchools.take(6).forEach { school ->
                                Text(
                                    school,
                                    style = MaterialTheme.typography.bodyMedium,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            viewModel.institutionName.value = school
                                            schoolQuery = school
                                            showSuggestions = false
                                        }
                                        .padding(horizontal = 14.dp, vertical = 12.dp),
                                )
                                HorizontalDivider()
                            }
                        }
                    }
                }
            }

            // Course type
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(loc.localized("과정", "Program", "Studiengang"), fontWeight = FontWeight.SemiBold)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    OnboardingData.courseOptions.forEach { option ->
                        SelectChip(
                            label = option.label,
                            selected = courseType == option.id,
                            onClick = { viewModel.courseType.value = option.id },
                            modifier = Modifier.fillMaxWidth(0.28f),
                        )
                    }
                }
            }

            // Enrollment year
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(loc.localized("입학 연도", "Enrollment Year", "Immatrikulationsjahr"), fontWeight = FontWeight.SemiBold)
                var expanded by remember { mutableStateOf(false) }
                ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
                    OutlinedTextField(
                        value = enrollmentYear.toString(),
                        onValueChange = {},
                        readOnly = true,
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded) },
                        modifier = Modifier.menuAnchor().fillMaxWidth(),
                        shape = RoundedCornerShape(12.dp),
                    )
                    ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                        OnboardingData.enrollmentYears.forEach { yr ->
                            DropdownMenuItem(
                                text = { Text(yr.toString()) },
                                onClick = {
                                    viewModel.enrollmentYear.value = yr
                                    expanded = false
                                },
                            )
                        }
                    }
                }
            }

            // Home cities
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Column {
                    Text(loc.localized("거주 도시", "Home Cities", "Heimatstadt"), fontWeight = FontWeight.SemiBold)
                    Text(
                        loc.localized("활동 거점 도시를 선택하세요.", "Choose your home base cities.", "Wähle deine Heimatstädte."),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                if (homeCities.isNotEmpty()) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        homeCities.forEach { id ->
                            val city = OnboardingData.cityOptions.firstOrNull { it.id == id }
                            if (city != null) {
                                Surface(
                                    shape = RoundedCornerShape(50),
                                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                                    modifier = Modifier.clickable {
                                        viewModel.homeCities.value = viewModel.homeCities.value - id
                                    },
                                ) {
                                    Row(
                                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                                    ) {
                                        Text(city.localizedName, style = MaterialTheme.typography.bodyMedium)
                                        Icon(Icons.Default.Close, null, modifier = Modifier.size(14.dp))
                                    }
                                }
                            }
                        }
                    }
                }
                TextButton(
                    onClick = { showCityPicker = true },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Icon(Icons.Default.Search, null, modifier = Modifier.size(16.dp))
                    Text(
                        loc.localized("도시 검색", "Search city", "Stadt suchen"),
                        modifier = Modifier.padding(start = 6.dp),
                    )
                }
            }

            Spacer(Modifier.height(8.dp))
        }

        OnboardingBottomBar(
            primaryLabel = loc.localized("다음", "Next", "Weiter"),
            onPrimary = { viewModel.saveStep3(userId) },
            primaryDisabled = institutionName.isEmpty(),
            isBusy = isBusy,
        )
    }

    if (showCityPicker) {
        CityPickerDialog(
            selectedIds = homeCities,
            onToggle = { id ->
                val current = viewModel.homeCities.value
                viewModel.homeCities.value = if (current.contains(id)) current - id else current + id
            },
            onDismiss = { showCityPicker = false },
        )
    }
}

@Composable
private fun CityPickerDialog(
    selectedIds: Set<String>,
    onToggle: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    val loc = AppLocale
    var query by remember { mutableStateOf("") }
    val groups = remember(query) {
        if (query.isEmpty()) OnboardingData.cityGroups
        else {
            val q = query.lowercase()
            OnboardingData.cityGroups.mapNotNull { g ->
                val matches = g.cities.filter {
                    it.ko.contains(q, true) || it.en.contains(q, true) || it.de.contains(q, true)
                }
                if (matches.isEmpty()) null else g.copy(cities = matches)
            }
        }
    }

    Dialog(onDismissRequest = onDismiss) {
        Card(shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text(
                    loc.localized("도시 선택", "Select Cities", "Städte auswählen"),
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(bottom = 12.dp),
                )
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text(loc.localized("검색...", "Search...", "Suchen...")) },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(10.dp),
                )
                Spacer(Modifier.height(8.dp))
                Column(
                    modifier = Modifier
                        .weight(1f, fill = false)
                        .verticalScroll(rememberScrollState()),
                ) {
                    groups.forEach { g ->
                        Text(
                            "${g.flag} ${g.country}",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
                        )
                        g.cities.forEach { city ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onToggle(city.id) }
                                    .padding(vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(city.localizedName, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium))
                                    if (city.localizedName != city.en) {
                                        Text(city.en, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                if (selectedIds.contains(city.id)) {
                                    Icon(
                                        Icons.Default.Search,
                                        null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(18.dp),
                                    )
                                }
                            }
                            HorizontalDivider()
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.End, modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) {
                    TextButton(onClick = onDismiss) {
                        Text(loc.localized("확인", "OK", "OK"), fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}
