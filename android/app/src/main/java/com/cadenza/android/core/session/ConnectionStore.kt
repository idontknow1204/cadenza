package com.cadenza.android.core.session

import com.cadenza.android.core.data.model.ConnectedProfile
import com.cadenza.android.core.data.model.ConnectionAction
import com.cadenza.android.core.data.model.ConnectionStatus
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class ConnectionStore @Inject constructor(
    private val repository: Repository,
) {
    private val _userId = MutableStateFlow<String?>(null)

    private val _statuses = MutableStateFlow<Map<String, ConnectionStatus>>(emptyMap())
    val statuses: StateFlow<Map<String, ConnectionStatus>> = _statuses.asStateFlow()

    private val _pending = MutableStateFlow<List<ConnectedProfile>>(emptyList())
    val pending: StateFlow<List<ConnectedProfile>> = _pending.asStateFlow()

    private val _updating = MutableStateFlow<Set<String>>(emptySet())
    val updating: StateFlow<Set<String>> = _updating.asStateFlow()

    private val _hasLoaded = MutableStateFlow(false)
    val hasLoaded: StateFlow<Boolean> = _hasLoaded.asStateFlow()

    private val _refreshFailed = MutableStateFlow(false)
    val refreshFailed: StateFlow<Boolean> = _refreshFailed.asStateFlow()

    private val _revision = MutableStateFlow(0)
    val revision: StateFlow<Int> = _revision.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    private var refreshJob: Job? = null

    fun statusFor(other: String): ConnectionStatus =
        _statuses.value[other] ?: ConnectionStatus.None

    val connectedCount: Int get() =
        _statuses.value.values.count { it is ConnectionStatus.Connected }

    fun reset(userId: String?) {
        if (_userId.value == userId) return
        refreshJob?.cancel()
        refreshJob = null
        _userId.value = userId
        _statuses.value = emptyMap()
        _pending.value = emptyList()
        _updating.value = emptySet()
        _hasLoaded.value = false
        _refreshFailed.value = false
        _errorMessage.value = null
        _revision.value++
    }

    fun refresh(scope: CoroutineScope, force: Boolean = false) {
        val userId = _userId.value ?: return
        if (_updating.value.isNotEmpty()) return
        if (force) { refreshJob?.cancel(); refreshJob = null }
        if (refreshJob?.isActive == true) return
        refreshJob = scope.launch {
            try {
                val rows = repository.connections(userId)
                val pending = repository.pendingConnectionRequests(userId)

                // Build status map from connections list
                val newStatuses = mutableMapOf<String, ConnectionStatus>()
                rows.forEach { profile -> newStatuses[profile.id] = ConnectionStatus.Connected }
                pending.forEach { profile ->
                    if (newStatuses[profile.id] !is ConnectionStatus.Connected) {
                        newStatuses[profile.id] = ConnectionStatus.RequestReceived
                    }
                }

                _statuses.value = newStatuses
                _pending.value = pending
                _hasLoaded.value = true
                _refreshFailed.value = false
                _revision.value++
            } catch (_: Throwable) {
                _refreshFailed.value = true
            } finally {
                refreshJob = null
            }
        }
    }

    suspend fun perform(action: ConnectionAction, with: String): Boolean {
        val userId = _userId.value ?: return false
        if (with == userId || _updating.value.contains(with)) return false

        _updating.value = _updating.value + with
        _errorMessage.value = null

        return try {
            val status = repository.transitionConnection(with, action)
            val newStatuses = _statuses.value.toMutableMap()
            newStatuses[with] = status
            _statuses.value = newStatuses
            if (status !is ConnectionStatus.RequestReceived) {
                _pending.value = _pending.value.filter { it.id != with }
            }
            _revision.value++
            true
        } catch (_: Throwable) {
            _errorMessage.value = AppLocale.localized(
                "연결 상태를 변경하지 못했습니다. 요청이 취소되었거나 네트워크에 문제가 있을 수 있습니다.",
                "Unable to update the connection. Please try again.",
                "Die Verbindung konnte nicht geändert werden. Bitte versuche es erneut."
            )
            false
        } finally {
            _updating.value = _updating.value - with
        }
    }
}
