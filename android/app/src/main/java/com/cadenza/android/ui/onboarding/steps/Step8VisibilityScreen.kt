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
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.data.model.Visibility
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.onboarding.OnboardingViewModel
import com.cadenza.android.ui.onboarding.components.OnboardingBottomBar

private data class VisibilityOption(
    val visibility: Visibility,
    val label: String,
    val icon: ImageVector,
)

@Composable
fun Step8VisibilityScreen(viewModel: OnboardingViewModel, session: SessionViewModel) {
    val loc = AppLocale
    val defaultVisibility by viewModel.defaultVisibility.collectAsState()
    val isBusy by viewModel.isBusy.collectAsState()

    val options = listOf(
        VisibilityOption(Visibility.INDUSTRY_FOLLOWERS, loc.localized("업계+팔로워", "Industry + followers", "Branche + Follower"), Icons.Default.People),
        VisibilityOption(Visibility.PUBLIC,             loc.localized("전체 공개",   "Public",                "Öffentlich"),         Icons.Default.Language),
        VisibilityOption(Visibility.FOLLOWERS,          loc.localized("팔로워만",    "Followers only",        "Nur Follower"),        Icons.Default.Person),
        VisibilityOption(Visibility.PRIVATE,            loc.localized("비공개",      "Private",               "Privat"),             Icons.Default.Lock),
    )

    Column(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    loc.localized("기본 공개 범위", "Default Visibility", "Standard-Sichtbarkeit"),
                    fontSize = 26.sp, fontWeight = FontWeight.Bold,
                )
                Text(
                    loc.localized(
                        "활동 기록의 기본 공개 범위를 설정하세요. 언제든지 변경 가능합니다.",
                        "Set the default visibility for your activities. You can change this anytime.",
                        "Lege die Standardsichtbarkeit deiner Aktivitäten fest. Du kannst sie jederzeit ändern."
                    ),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                options.forEach { option ->
                    val selected = defaultVisibility == option.visibility
                    Surface(
                        onClick = { viewModel.defaultVisibility.value = option.visibility },
                        shape = RoundedCornerShape(12.dp),
                        color = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(14.dp),
                        ) {
                            Icon(
                                option.icon,
                                contentDescription = null,
                                tint = if (selected) Color.White else MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(24.dp),
                            )
                            Text(
                                option.label,
                                fontWeight = FontWeight.Medium,
                                color = if (selected) Color.White else MaterialTheme.colorScheme.onSurface,
                                modifier = Modifier.weight(1f),
                            )
                            if (selected) {
                                Icon(
                                    Icons.Default.Check,
                                    contentDescription = null,
                                    tint = Color.White,
                                    modifier = Modifier.size(18.dp),
                                )
                            }
                        }
                    }
                }
            }

            // Info card
            Surface(
                shape = RoundedCornerShape(10.dp),
                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.08f),
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(Icons.Default.Info, null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(18.dp))
                    Text(
                        loc.localized(
                            "기본값은 '업계+팔로워'입니다. 활동 등록 시 개별 변경도 가능합니다.",
                            "Default is 'Industry + followers'. You can change visibility per activity.",
                            "Standard ist 'Branche + Follower'. Du kannst die Sichtbarkeit pro Aktivität ändern."
                        ),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Spacer(Modifier.height(8.dp))
        }

        OnboardingBottomBar(
            primaryLabel = loc.localized("완료", "Done", "Fertig"),
            onPrimary = {
                val uid = session.currentUserId ?: return@OnboardingBottomBar
                viewModel.completeOnboarding(uid, session)
            },
            isBusy = isBusy,
        )
    }
}
