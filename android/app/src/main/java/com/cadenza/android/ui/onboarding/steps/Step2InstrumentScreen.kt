package com.cadenza.android.ui.onboarding.steps

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.onboarding.OnboardingViewModel
import com.cadenza.android.ui.onboarding.components.OnboardingBottomBar
import com.cadenza.android.ui.onboarding.components.SelectChip
import com.google.accompanist.flowlayout.FlowRow

@Composable
fun Step2InstrumentScreen(viewModel: OnboardingViewModel, userId: String) {
    val loc = AppLocale
    val major by viewModel.major.collectAsState()
    val instrument by viewModel.instrument.collectAsState()
    val isBusy by viewModel.isBusy.collectAsState()

    val instruments = OnboardingData.instrumentsByMajor[major] ?: emptyList()

    Column(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            // Header
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    loc.localized("전공 & 악기", "Major & Instrument", "Hauptfach & Instrument"),
                    fontSize = 26.sp, fontWeight = FontWeight.Bold,
                )
                Text(
                    loc.localized("주 전공 분야와 악기를 선택해 주세요.", "Select your major and instrument.", "Wähle dein Hauptfach und Instrument."),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // Major section
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(loc.localized("전공", "Major", "Hauptfach"), fontWeight = FontWeight.SemiBold)
                FlowRow(mainAxisSpacing = 10.dp, crossAxisSpacing = 10.dp) {
                    OnboardingData.majors.forEach { m ->
                        SelectChip(
                            label = m.localizedName,
                            selected = major == m.id,
                            onClick = {
                                viewModel.major.value = m.id
                                viewModel.instrument.value = ""
                            },
                            modifier = Modifier.fillMaxWidth(0.3f),
                        )
                    }
                }
            }

            // Instrument section (visible only after major is selected)
            if (major.isNotEmpty() && instruments.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(loc.localized("악기", "Instrument", "Instrument"), fontWeight = FontWeight.SemiBold)
                    FlowRow(mainAxisSpacing = 10.dp, crossAxisSpacing = 10.dp) {
                        instruments.forEach { inst ->
                            SelectChip(
                                label = inst.localizedName,
                                selected = instrument == inst.id,
                                onClick = { viewModel.instrument.value = inst.id },
                                modifier = Modifier.fillMaxWidth(0.3f),
                            )
                        }
                    }
                }
            }

            Spacer(Modifier.height(8.dp))
        }

        OnboardingBottomBar(
            primaryLabel = loc.localized("다음", "Next", "Weiter"),
            onPrimary = { viewModel.saveStep2(userId) },
            primaryDisabled = major.isEmpty() || instrument.isEmpty(),
            isBusy = isBusy,
        )
    }
}
