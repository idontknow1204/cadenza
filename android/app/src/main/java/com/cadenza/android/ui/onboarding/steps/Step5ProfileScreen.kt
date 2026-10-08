package com.cadenza.android.ui.onboarding.steps

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.onboarding.OnboardingViewModel
import com.cadenza.android.ui.onboarding.components.OnboardingBottomBar
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun Step5ProfileScreen(viewModel: OnboardingViewModel, userId: String) {
    val loc = AppLocale
    val bio by viewModel.bio.collectAsState()
    val avatarUri by viewModel.avatarUri.collectAsState()
    val isBusy by viewModel.isBusy.collectAsState()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val imagePicker = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        if (uri != null) {
            viewModel.avatarUri.value = uri
            scope.launch {
                val bytes = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(uri)?.readBytes()
                }
                viewModel.avatarBytes.value = bytes
            }
        }
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
                    loc.localized("프로필 설정", "Set Up Profile", "Profil einrichten"),
                    fontSize = 26.sp, fontWeight = FontWeight.Bold,
                )
                Text(
                    loc.localized("프로필 사진과 소개글을 추가하세요.", "Add a profile photo and bio.", "Füge ein Profilfoto und eine Bio hinzu."),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // Avatar
            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                Box(
                    modifier = Modifier
                        .size(100.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .clickable { imagePicker.launch("image/*") },
                    contentAlignment = Alignment.Center,
                ) {
                    if (avatarUri != null) {
                        AsyncImage(
                            model = avatarUri,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.size(100.dp).clip(CircleShape),
                        )
                    } else {
                        Icon(
                            Icons.Default.Person,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                            modifier = Modifier.size(56.dp),
                        )
                    }
                }
                Icon(
                    Icons.Default.AddCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(start = 60.dp, top = 60.dp)
                        .size(28.dp)
                        .background(MaterialTheme.colorScheme.surface, CircleShape),
                )
            }

            // Bio
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(loc.localized("소개", "Bio", "Biografie"), fontWeight = FontWeight.SemiBold)
                    Text(
                        "${bio.length}/300",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                OutlinedTextField(
                    value = bio,
                    onValueChange = { if (it.length <= 300) viewModel.bio.value = it },
                    placeholder = { Text(loc.localized("음악 활동을 소개해 보세요...", "Introduce your music journey...", "Stelle deine Musik vor...")) },
                    modifier = Modifier.fillMaxWidth().height(140.dp),
                )
                Text(
                    loc.localized("소개글은 나중에 언제든 수정할 수 있습니다.", "You can update your bio at any time.", "Du kannst deine Bio jederzeit ändern."),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Spacer(Modifier.height(8.dp))
        }

        OnboardingBottomBar(
            primaryLabel = loc.localized("다음", "Next", "Weiter"),
            onPrimary = { viewModel.saveStep5(userId) },
            isBusy = isBusy,
            skipLabel = loc.localized("건너뛰기", "Skip", "Überspringen"),
            onSkip = { viewModel.advance() },
        )
    }
}
