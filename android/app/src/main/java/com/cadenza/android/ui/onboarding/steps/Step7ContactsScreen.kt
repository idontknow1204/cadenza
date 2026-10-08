package com.cadenza.android.ui.onboarding.steps

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.People
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.onboarding.OnboardingViewModel
import com.cadenza.android.ui.onboarding.components.OnboardingBottomBar

// Contact-based discovery — placeholder (M2). Same iOS placeholder behavior.
@Composable
fun Step7ContactsScreen(viewModel: OnboardingViewModel) {
    val loc = AppLocale

    Column(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            androidx.compose.foundation.layout.Spacer(Modifier.size(40.dp))
            Icon(
                Icons.Default.People,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(60.dp),
            )
            Text(
                loc.localized("지인 찾기", "Find Connections", "Bekannte finden"),
                fontSize = 26.sp, fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Text(
                loc.localized(
                    "연락처를 기반으로 Cadenza에 있는 지인을 찾아드립니다.",
                    "Find your contacts already on Cadenza.",
                    "Finde Bekannte auf Cadenza."
                ),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            // Placeholder card — contacts access is M2
            Surface(
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.fillMaxWidth().padding(top = 16.dp),
            ) {
                Column(
                    modifier = Modifier.padding(20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(
                        Icons.Default.Lock,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(32.dp),
                    )
                    Text(
                        loc.localized("연락처 접근 기능은 곧 추가됩니다.", "Contact access coming soon.", "Kontaktzugriff kommt bald."),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }

        OnboardingBottomBar(
            primaryLabel = loc.localized("다음", "Next", "Weiter"),
            onPrimary = { viewModel.advance() },
            skipLabel = loc.localized("건너뛰기", "Skip", "Überspringen"),
            onSkip = { viewModel.advance() },
        )
    }
}
