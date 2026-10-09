package com.cadenza.android.ui.auth

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.foundation.Image
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.layout.offset
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.R
import com.cadenza.android.core.data.preferences.AppPreferences
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private data class LangOption(val code: String, val display: String, val tag: String)

private val langOptions = listOf(
    LangOption("ko", "한국어", "KO"),
    LangOption("en", "English", "EN"),
    LangOption("de", "Deutsch", "DE"),
)

@Composable
fun LanguagePickerScreen(
    prefs: AppPreferences,
    alreadyChosen: Boolean,
    onChosen: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    // If user came back from AuthScreen, skip the splash
    var showSelection by remember { mutableStateOf(alreadyChosen) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
    ) {
        AnimatedContent(
            targetState = showSelection,
            transitionSpec = {
                if (targetState) {
                    slideInHorizontally { it } togetherWith slideOutHorizontally { -it }
                } else {
                    slideInHorizontally { -it } togetherWith slideOutHorizontally { it }
                }
            },
            label = "langPicker",
        ) { showSel ->
            if (showSel) {
                LanguageSelectionPage(onSelect = { code ->
                    scope.launch {
                        prefs.setLanguage(code)
                        onChosen()
                    }
                })
            } else {
                SplashPage(onTimeout = { showSelection = true })
            }
        }
    }
}

@Composable
private fun SplashPage(onTimeout: () -> Unit) {
    LaunchedEffect(Unit) {
        delay(2_000)
        onTimeout()
    }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Image(
                painter = painterResource(R.drawable.cadenza_logo),
                contentDescription = null,
                contentScale = ContentScale.Fit,
                modifier = Modifier.size(140.dp),
            )
            // iOS: .padding(.bottom, -24) — pulls the title up under the logo
            Text(
                "Cadenza",
                fontSize = 34.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.Black,
                modifier = Modifier.offset(y = (-24).dp),
            )
        }
    }
}

@Composable
private fun LanguageSelectionPage(onSelect: (String) -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 28.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Image(
            painter = painterResource(R.drawable.cadenza_logo),
            contentDescription = null,
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .size(44.dp)
                .alpha(0.5f)
                .padding(bottom = 0.dp),
        )
        Spacer(Modifier.height(6.dp))
        Text(
            "언어를 선택하세요\nSelect your language\nSprache wählen",
            style = MaterialTheme.typography.bodyMedium,
            color = Color.Gray,
            textAlign = TextAlign.Center,
            lineHeight = 22.sp,
            modifier = Modifier.padding(bottom = 36.dp),
        )

        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            langOptions.forEach { lang ->
                Surface(
                    onClick = { onSelect(lang.code) },
                    shape = RoundedCornerShape(14.dp),
                    color = Color(0xFFF2F2F7),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 18.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Box(
                            modifier = Modifier
                                .size(36.dp)
                                .background(Color.White, RoundedCornerShape(8.dp)),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                lang.tag,
                                fontFamily = FontFamily.Monospace,
                                fontWeight = FontWeight.Bold,
                                fontSize = 12.sp,
                                color = Color.Black,
                            )
                        }
                        Text(
                            lang.display,
                            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
                            color = Color.Black,
                            modifier = Modifier.weight(1f),
                        )
                        Icon(
                            Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = Color.LightGray,
                        )
                    }
                }
            }
        }
    }
}
