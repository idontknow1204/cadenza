package com.cadenza.android.ui.org

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.model.Organization
import com.cadenza.android.core.data.repository.Repository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OrgPageViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: Repository,
) : ViewModel() {

    val orgId: String = savedStateHandle.get<String>("orgId") ?: ""

    private val _org = MutableStateFlow<Organization?>(null)
    val org: StateFlow<Organization?> = _org.asStateFlow()

    private val _activities = MutableStateFlow<List<ActivityWithAuthor>>(emptyList())
    val activities: StateFlow<List<ActivityWithAuthor>> = _activities.asStateFlow()

    private val _followerCount = MutableStateFlow(0)
    val followerCount: StateFlow<Int> = _followerCount.asStateFlow()

    private val _isFollowing = MutableStateFlow(false)
    val isFollowing: StateFlow<Boolean> = _isFollowing.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _followBusy = MutableStateFlow(false)
    val followBusy: StateFlow<Boolean> = _followBusy.asStateFlow()

    fun load(orgId: String, userId: String?) {
        if (_isLoading.value) return
        viewModelScope.launch {
            _isLoading.value = true
            try {
                coroutineScope {
                    val orgDeferred       = async { runCatching { repository.fetchOrg(orgId) }.getOrNull() }
                    val actsDeferred      = async { runCatching { repository.orgActivities(orgId) }.getOrElse { emptyList() } }
                    val countDeferred     = async { runCatching { repository.orgFollowerCount(orgId) }.getOrElse { 0 } }
                    val followingDeferred = async { userId?.let { runCatching { repository.isFollowingOrg(orgId, it) }.getOrElse { false } } ?: false }

                    _org.value           = orgDeferred.await()
                    _activities.value    = actsDeferred.await()
                    _followerCount.value = countDeferred.await()
                    _isFollowing.value   = followingDeferred.await()
                }
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun toggleFollow(orgId: String, userId: String) {
        if (_followBusy.value) return
        viewModelScope.launch {
            _followBusy.value = true
            try {
                if (_isFollowing.value) {
                    repository.unfollowOrg(orgId, userId)
                    _isFollowing.value = false
                    _followerCount.value = (_followerCount.value - 1).coerceAtLeast(0)
                } else {
                    repository.followOrg(orgId, userId)
                    _isFollowing.value = true
                    _followerCount.value = _followerCount.value + 1
                }
            } catch (_: Exception) {}
            finally {
                _followBusy.value = false
            }
        }
    }
}
