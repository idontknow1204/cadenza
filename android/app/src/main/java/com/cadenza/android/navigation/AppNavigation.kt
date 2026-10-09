package com.cadenza.android.navigation

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import com.cadenza.android.core.data.preferences.AppPreferences
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.ui.auth.AuthScreen
import com.cadenza.android.ui.auth.LanguagePickerScreen
import com.cadenza.android.ui.onboarding.OnboardingScreen
import io.github.jan.supabase.gotrue.SessionStatus

// AppNavigation mirrors iOS CadenzaApp body decision tree:
//   !languageChosen → LanguagePickerScreen
//   bootstrapping   → loading spinner
//   not authed      → AuthScreen
//   needsOnboarding → OnboardingScreen
//   else            → RootNavigation (main tabs)

sealed class AppScreen {
    data object LanguagePicker : AppScreen()
    data object Loading        : AppScreen()
    data object Auth           : AppScreen()
    data object Onboarding     : AppScreen()
    data object Main           : AppScreen()
}

@Composable
fun AppNavigation(
    prefs: AppPreferences,
    session: SessionViewModel = hiltViewModel(),
    repository: Repository,
) {
    val languageChosen by prefs.languageChosenFlow.collectAsState(initial = false)
    val languageCode   by prefs.languageFlow.collectAsState(initial = "")
    val sessionStatus  by session.sessionStatus.collectAsState()
    val profile        by session.profile.collectAsState()

    // Sync language preference into AppLocale on first composition
    LaunchedEffect(languageCode) {
        if (languageCode.isNotEmpty()) {
            com.cadenza.android.core.util.AppLocale.language = languageCode
        }
    }

    val screen: AppScreen = when {
        !languageChosen                       -> AppScreen.LanguagePicker
        sessionStatus is SessionStatus.LoadingFromStorage -> AppScreen.Loading
        sessionStatus !is SessionStatus.Authenticated    -> AppScreen.Auth
        profile == null                       -> AppScreen.Loading
        profile?.onboardingComplete == false  -> AppScreen.Onboarding
        else                                  -> AppScreen.Main
    }

    AnimatedContent(
        targetState = screen,
        transitionSpec = { fadeIn() togetherWith fadeOut() },
        label = "app_screen",
    ) { s ->
        when (s) {
            AppScreen.LanguagePicker -> LanguagePickerScreen(
                prefs = prefs,
                alreadyChosen = languageCode.isNotEmpty(),
                onChosen = { /* state updates reactively via prefs flow */ },
            )
            AppScreen.Loading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            AppScreen.Auth -> AuthScreen(
                session = session,
                onBack = { /* no-op — back means language picker only via deep press */ },
            )
            AppScreen.Onboarding -> OnboardingScreen(
                session = session,
                repository = repository,
            )
            AppScreen.Main -> RootNavigation()
        }
    }
}
