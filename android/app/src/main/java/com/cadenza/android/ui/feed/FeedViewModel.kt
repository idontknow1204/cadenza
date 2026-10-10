package com.cadenza.android.ui.feed

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.model.Job
import com.cadenza.android.core.data.model.ProfileLite
import com.cadenza.android.core.data.model.SuggestedProfile
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.ConnectionStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job as CoroutineJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class FeedViewModel @Inject constructor(
    val repository: Repository,
    val connectionStore: ConnectionStore,
) : ViewModel() {

    private val _items = MutableStateFlow<List<ActivityWithAuthor>>(emptyList())
    val items: StateFlow<List<ActivityWithAuthor>> = _items.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    // Search
    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    private val _searchActive = MutableStateFlow(false)
    val searchActive: StateFlow<Boolean> = _searchActive.asStateFlow()

    private val _searchPeople = MutableStateFlow<List<ProfileLite>>(emptyList())
    val searchPeople: StateFlow<List<ProfileLite>> = _searchPeople.asStateFlow()

    private val _searchActivities = MutableStateFlow<List<ActivityWithAuthor>>(emptyList())
    val searchActivities: StateFlow<List<ActivityWithAuthor>> = _searchActivities.asStateFlow()

    private val _searchJobs = MutableStateFlow<List<Job>>(emptyList())
    val searchJobs: StateFlow<List<Job>> = _searchJobs.asStateFlow()

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching.asStateFlow()

    private val _suggestedProfiles = MutableStateFlow<List<SuggestedProfile>>(emptyList())
    val suggestedProfiles: StateFlow<List<SuggestedProfile>> = _suggestedProfiles.asStateFlow()

    private val _recentSearches = MutableStateFlow<List<String>>(emptyList())
    val recentSearches: StateFlow<List<String>> = _recentSearches.asStateFlow()

    private val _unreadNotificationCount = MutableStateFlow(0)
    val unreadNotificationCount: StateFlow<Int> = _unreadNotificationCount.asStateFlow()

    // 작성자 id → 현재 소속(근무지 우선, 없으면 학교)
    private val _affiliations = MutableStateFlow<Map<String, String>>(emptyMap())
    val affiliations: StateFlow<Map<String, String>> = _affiliations.asStateFlow()
    private val requestedAffiliationIds = mutableSetOf<String>()

    private var allJobs: List<Job> = emptyList()
    private var refreshJob: CoroutineJob? = null
    private var searchJob: CoroutineJob? = null

    fun refresh(userId: String) {
        refreshJob?.cancel()
        refreshJob = viewModelScope.launch {
            _isLoading.value = true
            _errorMessage.value = null
            launch {
                runCatching { repository.unreadNotificationCount(userId) }
                    .onSuccess { _unreadNotificationCount.value = it }
            }
            try {
                _items.value = repository.feed(userId)
                launch { loadAffiliations(_items.value) }
            } catch (e: Throwable) {
                if (e !is CancellationException) _errorMessage.value = e.message
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun remove(id: String) {
        refreshJob?.cancel()
        _items.value = _items.value.filter { it.id != id }
    }

    fun upsert(item: ActivityWithAuthor) {
        refreshJob?.cancel()
        _items.value = buildList {
            add(item)
            addAll(_items.value.filter { it.id != item.id })
        }
    }

    fun setSearchQuery(q: String, userId: String) {
        _searchQuery.value = q
        searchJob?.cancel()
        val trimmed = q.trim()
        if (trimmed.isEmpty()) {
            _searchPeople.value = emptyList()
            _searchActivities.value = emptyList()
            _searchJobs.value = emptyList()
            return
        }
        searchJob = viewModelScope.launch {
            delay(300)
            _isSearching.value = true
            try {
                _searchPeople.value = repository.searchProfiles(trimmed, userId)
                _searchActivities.value = repository.searchActivities(trimmed)
                launch { loadAffiliations(_searchActivities.value) }
                _searchJobs.value = filterJobs(allJobs, trimmed)
            } catch (_: Throwable) {
            } finally {
                _isSearching.value = false
            }
        }
    }

    fun setSearchActive(active: Boolean, userId: String) {
        _searchActive.value = active
        if (!active) return
        viewModelScope.launch {
            if (_suggestedProfiles.value.isEmpty()) {
                try { _suggestedProfiles.value = repository.suggestedProfiles(userId) } catch (_: Throwable) {}
            }
            if (allJobs.isEmpty()) {
                try { allJobs = repository.jobs() } catch (_: Throwable) {}
            }
            val q = _searchQuery.value.trim()
            if (q.isNotEmpty()) _searchJobs.value = filterJobs(allJobs, q)
        }
    }

    fun addRecent(term: String) {
        val t = term.trim()
        if (t.isEmpty()) return
        val existing = _recentSearches.value.filter { !it.equals(t, ignoreCase = true) }
        _recentSearches.value = (listOf(t) + existing).take(8)
    }

    fun removeRecent(term: String) {
        _recentSearches.value = _recentSearches.value.filter { !it.equals(term, ignoreCase = true) }
    }

    fun clearRecent() { _recentSearches.value = emptyList() }

    fun clearError() { _errorMessage.value = null }

    /** 아직 조회하지 않은 작성자만 모아 소속을 가져온다. 실패해도 피드 표시에는 영향 없음. */
    private suspend fun loadAffiliations(activities: List<ActivityWithAuthor>) {
        val ids = activities.mapNotNull { it.author?.id }.distinct()
            .filter { requestedAffiliationIds.add(it) }
        if (ids.isEmpty()) return
        try {
            val fetched = repository.currentAffiliations(ids)
            _affiliations.value = _affiliations.value + fetched
        } catch (e: Throwable) {
            if (e is CancellationException) throw e
            requestedAffiliationIds.removeAll(ids.toSet())
        }
    }

    private fun filterJobs(jobs: List<Job>, q: String): List<Job> = jobs.filter { job ->
        job.title.contains(q, ignoreCase = true)
            || job.organization?.contains(q, ignoreCase = true) == true
            || job.location?.contains(q, ignoreCase = true) == true
            || job.type.label.contains(q, ignoreCase = true)
            || job.instruments.any { it.contains(q, ignoreCase = true) }
    }
}
