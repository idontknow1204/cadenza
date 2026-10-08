package com.cadenza.android.ui.onboarding.steps

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.onboarding.OnboardingViewModel
import com.cadenza.android.ui.onboarding.components.OnboardingBottomBar

// Placeholder step — activity creation handled by the main Create tab after onboarding.
@Composable
fun Step6ActivityScreen(viewModel: OnboardingViewModel) {
    val loc = AppLocale
    val isBusy by viewModel.isBusy.collectAsState()

    Column(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Box(modifier = Modifier.padding(top = 48.dp))
            Icon(
                Icons.Default.MusicNote,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(60.dp),
            )
            Text(
                loc.localized("첫 번째 활동 기록", "Record Your First Activity", "Erste Aktivität aufzeichnen"),
                fontSize = 26.sp, fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Text(
                loc.localized(
                    "온보딩 완료 후 + 버튼을 눌러 연주·경연·교육 활동을 기록할 수 있습니다.",
                    "After onboarding, tap + to record performances, competitions, and more.",
                    "Nach dem Onboarding kannst du mit + Auftritte, Wettbewerbe und mehr aufzeichnen."
                ),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }

        OnboardingBottomBar(
            primaryLabel = loc.localized("다음", "Next", "Weiter"),
            onPrimary = { viewModel.advance() },
            skipLabel = loc.localized("건너뛰기", "Skip", "Überspringen"),
            onSkip = { viewModel.advance() },
        )
    }
}
