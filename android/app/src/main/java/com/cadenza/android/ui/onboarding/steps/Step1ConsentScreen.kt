package com.cadenza.android.ui.onboarding.steps

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material.icons.filled.Security
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.onboarding.OnboardingViewModel

@Composable
fun Step1ConsentScreen(viewModel: OnboardingViewModel) {
    val loc = AppLocale

    var agreedPrivacy by remember { mutableStateOf(false) }
    var agreedTerms by remember { mutableStateOf(false) }
    var agreedMarketing by remember { mutableStateOf(false) }

    val allRequired = agreedPrivacy && agreedTerms
    val allChecked = agreedPrivacy && agreedTerms && agreedMarketing

    val heading = loc.localized(
        "서비스를 시작하기 전에\n약관에 동의해 주세요",
        "Before you begin,\nplease agree to our terms",
        "Bevor du loslegst,\nbitte stimme zu"
    )
    val subtitle = loc.localized(
        "Cadenza를 안전하게 사용하기 위한 필수 동의 사항입니다.",
        "Required agreements to use Cadenza safely.",
        "Pflichtangaben zur sicheren Nutzung von Cadenza."
    )
    val allAgreeLabel = loc.localized("모두 동의", "Agree to all", "Allem zustimmen")
    val ctaLabel = loc.localized("동의하고 시작하기", "Agree and continue", "Zustimmen und weiter")
    val ageNote = loc.localized(
        "계속하면 만 14세 이상임을 확인하는 것입니다.",
        "By continuing you confirm you are at least 14 years old.",
        "Mit Fortfahren bestätigst du, mindestens 14 Jahre alt zu sein."
    )

    Column(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
        ) {
            Spacer(Modifier.height(32.dp))

            // Icon + heading
            Icon(
                Icons.Default.Security,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .size(48.dp)
                    .padding(bottom = 4.dp),
            )
            Spacer(Modifier.height(8.dp))
            Text(heading, fontSize = 24.sp, fontWeight = FontWeight.Bold, lineHeight = 32.sp)
            Spacer(Modifier.height(8.dp))
            Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)

            Spacer(Modifier.height(28.dp))

            // All agree
            Surface(
                onClick = {
                    val next = !allChecked
                    agreedPrivacy = next; agreedTerms = next; agreedMarketing = next
                },
                shape = RoundedCornerShape(14.dp),
                color = MaterialTheme.colorScheme.surfaceVariant,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Checkbox(checked = allChecked, onCheckedChange = null)
                    Text(
                        allAgreeLabel,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.padding(start = 8.dp),
                    )
                }
            }

            HorizontalDivider(modifier = Modifier.padding(vertical = 14.dp))

            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                ConsentRow(
                    checked = agreedPrivacy,
                    onChecked = { agreedPrivacy = it },
                    title = loc.localized("개인정보 처리방침 동의", "Privacy policy", "Datenschutzerklärung"),
                    badge = loc.localized("필수", "Required", "Pflicht"),
                    required = true,
                )
                ConsentRow(
                    checked = agreedTerms,
                    onChecked = { agreedTerms = it },
                    title = loc.localized("서비스 이용약관 동의", "Terms of service", "Nutzungsbedingungen"),
                    badge = loc.localized("필수", "Required", "Pflicht"),
                    required = true,
                )
                ConsentRow(
                    checked = agreedMarketing,
                    onChecked = { agreedMarketing = it },
                    title = loc.localized("마케팅 정보 수신 동의", "Receive marketing updates", "Marketingnachrichten erhalten"),
                    badge = loc.localized("선택", "Optional", "Optional"),
                    required = false,
                )
            }

            Spacer(Modifier.height(20.dp))
            Text(ageNote, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.outline)
            Spacer(Modifier.height(16.dp))
        }

        // Bottom CTA
        HorizontalDivider()
        Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 16.dp)) {
            Button(
                onClick = { viewModel.advanceFromConsent() },
                enabled = allRequired,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(14.dp),
            ) {
                Text(ctaLabel, fontWeight = FontWeight.SemiBold)
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

@Composable
private fun ConsentRow(
    checked: Boolean,
    onChecked: (Boolean) -> Unit,
    title: String,
    badge: String,
    required: Boolean,
) {
    Surface(
        onClick = { onChecked(!checked) },
        shape = RoundedCornerShape(14.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Checkbox(checked = checked, onCheckedChange = null)
            Column(modifier = Modifier.weight(1f).padding(start = 8.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Surface(
                        shape = RoundedCornerShape(50),
                        color = if (required) MaterialTheme.colorScheme.error.copy(alpha = 0.12f)
                                else MaterialTheme.colorScheme.surfaceVariant,
                    ) {
                        Text(
                            badge,
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                            color = if (required) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp),
                        )
                    }
                    Text(title, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}
