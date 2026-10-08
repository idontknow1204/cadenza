package com.cadenza.android.ui.jobs

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.JobType
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.util.AppLocale

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun JobFilterSheet(
    filter: JobFilter,
    sort: JobSort,
    myInstrument: String?,
    availableCountries: List<String>,
    onDismiss: () -> Unit,
    onApply: (JobFilter, JobSort) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var localFilter by remember { mutableStateOf(filter) }
    var localSort   by remember { mutableStateOf(sort) }

    val instrumentOptions = remember(myInstrument) {
        val all = OnboardingData.allInstruments
        if (myInstrument == null) all
        else all.sortedWith(compareBy { if (it.id == myInstrument) 0 else 1 })
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .padding(horizontal = 16.dp),
        ) {
            // Header row
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                TextButton(onClick = {
                    localFilter = JobFilter()
                    localSort = JobSort.CITY_FIRST
                }) {
                    Text(AppLocale.localized("초기화", "Reset", "Zurücksetzen"), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Text(
                    AppLocale.localized("필터 및 정렬", "Filters & Sort", "Filter & Sortierung"),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
                )
                TextButton(onClick = { onApply(localFilter, localSort) }) {
                    Text(AppLocale.localized("적용", "Apply", "Anwenden"), fontWeight = FontWeight.SemiBold)
                }
            }
            HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))

            Column(
                modifier = Modifier.verticalScroll(rememberScrollState()).padding(bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                // ── Sort ───────────────────────────────────────────────────
                FilterSection(AppLocale.localized("정렬", "Sort", "Sortierung")) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        JobSort.entries.forEach { s ->
                            FilterChip(
                                selected = localSort == s,
                                onClick = { localSort = s },
                                label = { Text(s.label, style = MaterialTheme.typography.labelMedium) },
                                shape = RoundedCornerShape(8.dp),
                            )
                        }
                    }
                }

                // ── Type ───────────────────────────────────────────────────
                FilterSection(AppLocale.localized("유형", "Type", "Art")) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        JobType.entries.forEach { t ->
                            FilterChip(
                                selected = t in localFilter.types,
                                onClick = {
                                    val newTypes = localFilter.types.toMutableSet()
                                    if (t in newTypes) newTypes.remove(t) else newTypes.add(t)
                                    localFilter = localFilter.copy(types = newTypes)
                                },
                                label = { Text(t.label, style = MaterialTheme.typography.labelMedium) },
                                shape = RoundedCornerShape(8.dp),
                            )
                        }
                    }
                }

                // ── Instrument ─────────────────────────────────────────────
                FilterSection(
                    title = AppLocale.localized("악기", "Instrument", "Instrument"),
                    subtitle = if (myInstrument != null) AppLocale.localized("★ 내 악기", "★ My instrument", "★ Mein Instrument") else null,
                ) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        instrumentOptions.forEach { inst ->
                            val label = inst.localizedName + if (inst.id == myInstrument) " ★" else ""
                            FilterChip(
                                selected = inst.id in localFilter.instruments,
                                onClick = {
                                    val newInsts = localFilter.instruments.toMutableSet()
                                    if (inst.id in newInsts) newInsts.remove(inst.id) else newInsts.add(inst.id)
                                    localFilter = localFilter.copy(instruments = newInsts)
                                },
                                label = { Text(label, style = MaterialTheme.typography.labelMedium) },
                                shape = RoundedCornerShape(8.dp),
                            )
                        }
                    }
                }

                // ── Region ────────────────────────────────────────────────
                if (availableCountries.isNotEmpty()) {
                    FilterSection(AppLocale.localized("지역", "Region", "Region")) {
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            availableCountries.forEach { cc ->
                                FilterChip(
                                    selected = cc in localFilter.countryCodes,
                                    onClick = {
                                        val newCodes = localFilter.countryCodes.toMutableSet()
                                        if (cc in newCodes) newCodes.remove(cc) else newCodes.add(cc)
                                        localFilter = localFilter.copy(countryCodes = newCodes)
                                    },
                                    label = { Text(localizedCountryName(cc), style = MaterialTheme.typography.labelMedium) },
                                    shape = RoundedCornerShape(8.dp),
                                )
                            }
                        }
                    }
                }

                // ── Format & cost ──────────────────────────────────────────
                FilterSection(AppLocale.localized("전형·비용", "Format & cost", "Format & Kosten")) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        SwitchRow(
                            label = AppLocale.localized("영상 예선 있음", "Video round", "Video-Vorrunde"),
                            checked = localFilter.videoOnly,
                            onCheckedChange = { localFilter = localFilter.copy(videoOnly = it) },
                        )
                        SwitchRow(
                            label = AppLocale.localized("지원료 없음", "No application fee", "Keine Gebühr"),
                            checked = localFilter.freeOnly,
                            onCheckedChange = { localFilter = localFilter.copy(freeOnly = it) },
                        )
                        SwitchRow(
                            label = AppLocale.localized("장학금 있음", "Scholarship available", "Stipendium verfügbar"),
                            checked = localFilter.scholarshipOnly,
                            onCheckedChange = { localFilter = localFilter.copy(scholarshipOnly = it) },
                        )
                    }
                }

                // ── Status ────────────────────────────────────────────────
                FilterSection(AppLocale.localized("상태", "Status", "Status")) {
                    SwitchRow(
                        label = AppLocale.localized("모집 중만 보기", "Open only", "Nur offene"),
                        checked = localFilter.openOnly,
                        onCheckedChange = { localFilter = localFilter.copy(openOnly = it) },
                    )
                }
            }
        }
    }
}

@Composable
private fun FilterSection(title: String, subtitle: String? = null, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
            if (subtitle != null) {
                Text(subtitle, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        content()
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
