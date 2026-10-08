package com.cadenza.android.ui.profile

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.Affiliation
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.model.Career
import com.cadenza.android.core.data.model.Organization
import com.cadenza.android.core.data.model.Profile
import com.cadenza.android.core.data.model.ProfileAward
import com.cadenza.android.core.data.model.ProfileLanguage
import com.cadenza.android.core.data.model.ProfileSection
import com.cadenza.android.core.data.model.Recommendation
import com.cadenza.android.core.data.preferences.AppPreferences
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.ConnectionStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ProfileViewModel @Inject constructor(
    val repository: Repository,
    val connectionStore: ConnectionStore,
    val appPreferences: AppPreferences,
) : ViewModel() {

    private val _activities = MutableStateFlow<List<ActivityWithAuthor>>(emptyList())
    val activities: StateFlow<List<ActivityWithAuthor>> = _activities.asStateFlow()

    private val _affiliations = MutableStateFlow<List<Affiliation>>(emptyList())
    val affiliations: StateFlow<List<Affiliation>> = _affiliations.asStateFlow()

    private val _careers = MutableStateFlow<List<Career>>(emptyList())
    val careers: StateFlow<List<Career>> = _careers.asStateFlow()

    private val _awards = MutableStateFlow<List<ProfileAward>>(emptyList())
    val awards: StateFlow<List<ProfileAward>> = _awards.asStateFlow()

    private val _languages = MutableStateFlow<List<ProfileLanguage>>(emptyList())
    val languages: StateFlow<List<ProfileLanguage>> = _languages.asStateFlow()

    private val _orgs = MutableStateFlow<List<Organization>>(emptyList())
    val orgs: StateFlow<List<Organization>> = _orgs.asStateFlow()

    private val _recommendations = MutableStateFlow<List<Recommendation>>(emptyList())
    val recommendations: StateFlow<List<Recommendation>> = _recommendations.asStateFlow()

    private val _connectionCount = MutableStateFlow(0)
    val connectionCount: StateFlow<Int> = _connectionCount.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun load(userId: String, profile: Profile? = null) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                coroutineScope {
                    val a   = async { runCatching { repository.activities(byAuthor = userId) }.getOrElse { emptyList() } }
                    val af  = async { runCatching { repository.affiliations(forUser = userId) }.getOrElse { emptyList() } }
                    val c   = async { runCatching { repository.careers(forUser = userId) }.getOrElse { emptyList() } }
                    val aw  = async { runCatching { repository.awards(forUser = userId) }.getOrElse { emptyList() } }
                    val l   = async { runCatching { repository.languages(forUser = userId) }.getOrElse { emptyList() } }
                    val o   = async { runCatching { repository.myOrgs(userId = userId) }.getOrElse { emptyList() } }
                    val cnt = async { runCatching { repository.connectionCount(userId = userId) }.getOrElse { 0 } }
                    _activities.value    = a.await()
                    _affiliations.value  = af.await()
                    _careers.value       = c.await()
                    _awards.value        = aw.await()
                    _languages.value     = l.await()
                    _orgs.value          = o.await()
                    _connectionCount.value = cnt.await()
                }
                if (profile?.showsSection(ProfileSection.RECOMMENDATIONS) == true) {
                    _recommendations.value = runCatching { repository.recommendations(forUser = userId) }.getOrElse { emptyList() }
                }
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun reloadRecommendations(userId: String) {
        viewModelScope.launch {
            _recommendations.value = runCatching { repository.recommendations(forUser = userId) }.getOrElse { emptyList() }
        }
    }

    fun reloadConnectionCount(userId: String) {
        viewModelScope.launch {
            _connectionCount.value = runCatching { repository.connectionCount(userId = userId) }.getOrElse { 0 }
        }
    }

    fun mergeAffiliation(aff: Affiliation) {
        val list = _affiliations.value.toMutableList()
        val i = list.indexOfFirst { it.id == aff.id }
        if (i >= 0) list[i] = aff else list.add(aff)
        _affiliations.value = list.sortedByDescending { it.enrollmentYear ?: 0 }
    }

    fun removeAffiliation(id: String) {
        _affiliations.value = _affiliations.value.filter { it.id != id }
    }

    fun mergeCareer(c: Career) {
        val list = _careers.value.toMutableList()
        val i = list.indexOfFirst { it.id == c.id }
        if (i >= 0) list[i] = c else list.add(c)
        _careers.value = list.sortedByDescending { it.startYear ?: 0 }
    }

    fun removeCareer(id: String) {
        _careers.value = _careers.value.filter { it.id != id }
    }

    fun mergeAward(a: ProfileAward) {
        val list = _awards.value.toMutableList()
        val i = list.indexOfFirst { it.id == a.id }
        if (i >= 0) list[i] = a else list.add(a)
        _awards.value = list.sortedByDescending { it.year }
    }

    fun removeAward(id: String) {
        _awards.value = _awards.value.filter { it.id != id }
    }

    fun updateLanguages(languages: List<ProfileLanguage>) {
        _languages.value = languages
    }

    fun mergeRecommendation(rec: Recommendation) {
        val list = _recommendations.value.toMutableList()
        val i = list.indexOfFirst { it.id == rec.id }
        if (i >= 0) list[i] = rec else list.add(0, rec)
        _recommendations.value = list
    }

    fun removeRecommendation(id: String) {
        _recommendations.value = _recommendations.value.filter { it.id != id }
    }
}
