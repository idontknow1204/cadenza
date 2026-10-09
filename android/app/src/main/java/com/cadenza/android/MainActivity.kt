package com.cadenza.android

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.lifecycleScope
import com.cadenza.android.core.AppConfig
import com.cadenza.android.core.data.preferences.AppPreferences
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.navigation.AppNavigation
import com.cadenza.android.ui.theme.CadenzaTheme
import dagger.hilt.android.AndroidEntryPoint
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.parseFragmentAndImportSession
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var prefs: AppPreferences
    @Inject lateinit var repository: Repository
    @Inject lateinit var supabaseClient: SupabaseClient

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleAuthDeepLink(intent)
        setContent {
            CadenzaTheme {
                AppNavigation(prefs = prefs, repository = repository)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAuthDeepLink(intent)
    }

    private fun handleAuthDeepLink(intent: Intent) {
        val uri = intent.data ?: return
        if (uri.scheme != AppConfig.authCallbackScheme) return
        // PKCE flow: ?code=xxx
        val code = uri.getQueryParameter("code")
        if (code != null) {
            lifecycleScope.launch {
                runCatching { supabaseClient.auth.exchangeCodeForSession(code) }
            }
            return
        }
        // Implicit flow: #access_token=xxx
        val fragment = uri.fragment
        if (!fragment.isNullOrEmpty()) {
            runCatching { supabaseClient.auth.parseFragmentAndImportSession(fragment) }
        }
    }
}
