package com.cadenza.android.core.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.cadenza.android.core.util.AppLocale
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "cadenza_prefs")

@Singleton
class AppPreferences @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    companion object {
        val KEY_LANGUAGE         = stringPreferencesKey("appLanguage")
        val KEY_LANGUAGE_CHOSEN  = booleanPreferencesKey("languageChosen")
    }

    val languageFlow: Flow<String> =
        context.dataStore.data.map { it[KEY_LANGUAGE] ?: "" }

    val languageChosenFlow: Flow<Boolean> =
        context.dataStore.data.map { it[KEY_LANGUAGE_CHOSEN] ?: false }

    suspend fun setLanguage(code: String) {
        context.dataStore.edit { prefs ->
            prefs[KEY_LANGUAGE]        = code
            prefs[KEY_LANGUAGE_CHOSEN] = true
        }
        AppLocale.language = code
    }

    suspend fun readInitial() {
        val prefs = context.dataStore.data.first()
        val lang = prefs[KEY_LANGUAGE] ?: ""
        if (lang.isNotEmpty()) AppLocale.language = lang
    }
}
