package com.cadenza.android.ui.onboarding.steps

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.data.model.ProfileLite
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.onboarding.OnboardingViewModel
import com.cadenza.android.ui.onboarding.components.OnboardingBottomBar
import kotlinx.coroutines.delay

@Composable
fun Step4TeacherScreen(
    viewModel: OnboardingViewModel,
    userId: String,
    repository: Repository,
) {
    val loc = AppLocale
    val teacherName by viewModel.teacherName.collectAsState()
    val teacherId by viewModel.teacherId.collectAsState()
    val isBusy by viewModel.isBusy.collectAsState()

    var searchQuery by remember { mutableStateOf(teacherName) }
    var results by remember { mutableStateOf<List<ProfileLite>>(emptyList()) }

    LaunchedEffect(searchQuery) {
        delay(300)
        if (searchQuery.length < 2) { results = emptyList(); return@LaunchedEffect }
        results = try { repository.searchProfiles(searchQuery, userId) } catch (_: Throwable) { emptyList() }
    }

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
                    loc.localized("사사 교수", "Teacher / Mentor", "Lehrer / Mentor"),
                    fontSize = 26.sp, fontWeight = FontWeight.Bold,
                )
                Text(
                    loc.localized("현재 또는 가장 최근에 사사한 선생님을 검색하세요.", "Search for your current or most recent teacher.", "Suche nach deinem aktuellen oder letzten Lehrer."),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(loc.localized("교수명", "Teacher name", "Lehrername"), fontWeight = FontWeight.SemiBold)
                OutlinedTextField(
                    value = searchQuery,
                    onValueChange = { v ->
                        searchQuery = v
                        viewModel.teacherName.value = v
                        viewModel.teacherId.value = null
                    },
                    placeholder = { Text(loc.localized("이름 검색...", "Search by name...", "Nach Name suchen...")) },
                    leadingIcon = { Icon(Icons.Default.Search, null) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    shape = RoundedCornerShape(12.dp),
                )

                if (results.isNotEmpty()) {
                    Card(shape = RoundedCornerShape(10.dp), modifier = Modifier.fillMaxWidth()) {
                        Column {
                            results.forEach { person ->
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .clickable {
                                            viewModel.teacherName.value = person.realName
                                            viewModel.teacherId.value = person.id
                                            searchQuery = person.realName
                                            results = emptyList()
                                        }
                                        .padding(horizontal = 14.dp, vertical = 10.dp),
                                ) {
                                    Text(person.realName, fontWeight = FontWeight.Medium)
                                    person.instrument?.let {
                                        Text(it, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                                HorizontalDivider()
                            }
                        }
                    }
                }

                when {
                    teacherId != null -> Text(
                        loc.localized("✓ Cadenza 계정과 연결되었습니다.", "✓ Linked to a Cadenza account.", "✓ Mit Cadenza-Konto verknüpft."),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    teacherName.isNotEmpty() -> Text(
                        loc.localized("직접 입력된 이름으로 저장됩니다.", "Will be saved as a custom name.", "Wird als benutzerdefinierter Name gespeichert."),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Spacer(Modifier.height(8.dp))
        }

        OnboardingBottomBar(
            primaryLabel = loc.localized("다음", "Next", "Weiter"),
            onPrimary = { viewModel.saveStep4(userId) },
            isBusy = isBusy,
            skipLabel = loc.localized("건너뛰기", "Skip", "Überspringen"),
            onSkip = { viewModel.advance() },
        )
    }
}
