package com.cadenza.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.cadenza.android.core.data.preferences.AppPreferences
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.navigation.AppNavigation
import com.cadenza.android.ui.theme.CadenzaTheme
import dagger.hilt.android.AndroidEntryPoint
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var prefs: AppPreferences
    @Inject lateinit var repository: Repository

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CadenzaTheme {
                AppNavigation(prefs = prefs, repository = repository)
            }
        }
    }
}
