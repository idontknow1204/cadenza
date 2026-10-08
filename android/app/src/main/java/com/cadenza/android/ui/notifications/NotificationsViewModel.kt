package com.cadenza.android.ui.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.ActivityWithAuthor
import com.cadenza.android.core.data.model.ConnectionAction
import com.cadenza.android.core.data.model.ConnectionStatus
import com.cadenza.android.core.data.model.SuggestedProfile
import com.cadenza.android.core.data.model.AppNotification
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.ConnectionStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class NotificationsViewModel @Inject constructor(
    val repository: Repository,
    val connectionStore: ConnectionStore,
) : ViewModel() {

    private val _notifications = MutableStateFlow<List<AppNotification>>(emptyList())
    val notifications: StateFlow<List<AppNotification>> = _notifications.asStateFlow()

    private val _pendingTags = MutableStateFlow<List<ActivityWithAuthor>>(emptyList())
    val pendingTags: StateFlow<List<ActivityWithAuthor>> = _pendingTags.asStateFlow()

    private val _suggestedProfiles = MutableStateFlow<List<SuggestedProfile>>(emptyList())
    val suggestedProfiles: StateFlow<List<SuggestedProfile>> = _suggestedProfiles.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _actingTagIds = MutableStateFlow<Set<String>>(emptySet())
    val actingTagIds: StateFlow<Set<String>> = _actingTagIds.asStateFlow()

    fun load(userId: String) {
        if (_isLoading.value) return
        connectionStore.refresh(viewModelScope)
        viewModelScope.launch {
            _isLoading.value = true
            try {
                coroutineScope {
                    val notifsDeferred    = async { runCatching { repository.notifications(userId) }.getOrElse { emptyList() } }
                    val tagsDeferred      = async { runCatching { repository.pendingTags(userId) }.getOrElse { emptyList() } }
                    val suggestedDeferred = async { runCatching { repository.suggestedProfiles(userId) }.getOrElse { emptyList() } }

                    val notifs    = notifsDeferred.await()
                    val tags      = tagsDeferred.await()
                    val suggested = suggestedDeferred.await()

                    _notifications.value = notifs
                    _pendingTags.value   = tags

                    // Keep just-requested cards actionable, similar to iOS logic
                    val available = suggested.map { it.id }.toSet()
                    val retained  = _suggestedProfiles.value.filter {
                        connectionStore.statusFor(it.id) is ConnectionStatus.RequestSent || it.id in available
                    }
                    val retainedIds = retained.map { it.id }.toSet()
                    _suggestedProfiles.value = retained + suggested.filter { it.id !in retainedIds }

                    // Mark unread notifications as read
                    val unreadIds = notifs.filter { !it.isRead }.map { it.id }
                    if (unreadIds.isNotEmpty()) {
                        runCatching { repository.markNotificationsRead(userId, unreadIds) }
                        _notifications.update { list -> list.map { n -> if (n.id in unreadIds.toSet()) n.copy(isRead = true) else n } }
                    }
                }
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun acceptTag(activityId: String, userId: String) {
        viewModelScope.launch {
            _actingTagIds.update { it + activityId }
            try {
                repository.acceptTag(activityId, userId)
                _pendingTags.update { it.filter { t -> t.id != activityId } }
            } catch (_: Exception) {}
            finally {
                _actingTagIds.update { it - activityId }
            }
        }
    }

    fun declineTag(activityId: String, userId: String) {
        viewModelScope.launch {
            _actingTagIds.update { it + activityId }
            try {
                repository.declineTag(activityId, userId)
                _pendingTags.update { it.filter { t -> t.id != activityId } }
            } catch (_: Exception) {}
            finally {
                _actingTagIds.update { it - activityId }
            }
        }
    }

    fun toggleSuggestedConnection(personId: String) {
        viewModelScope.launch {
            val action = if (connectionStore.statusFor(personId) is ConnectionStatus.RequestSent)
                ConnectionAction.CANCEL else ConnectionAction.REQUEST
            connectionStore.perform(action, personId)
        }
    }
}
