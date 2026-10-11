package com.cadenza.android.core.session

import com.cadenza.android.core.data.model.ConnectedProfile
import com.cadenza.android.core.data.model.ConnectionAction
import com.cadenza.android.core.data.model.ConnectionStatus
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

internal data class ConnectionSnapshot(
    val statuses: Map<String, ConnectionStatus>,
    val pending: List<ConnectedProfile>,
)

/**
 * Reduces every row involving the signed-in user into one authoritative state.
 * Accepted always wins over pending, regardless of row order or direction.
 */
internal fun buildConnectionSnapshot(
    userId: String,
    rows: List<com.cadenza.android.core.data.model.ConnectionRecord>,
): ConnectionSnapshot {
    val statuses = mutableMapOf<String, ConnectionStatus>()
    val people = mutableMapOf<String, ConnectedProfile>()

    rows.forEach { row ->
        if (row.followerId != userId && row.followeeId != userId) return@forEach
        val other = if (row.followerId == userId) row.followeeId else row.followerId
        when {
            row.status == "accepted" -> statuses[other] = ConnectionStatus.Connected
            statuses[other] !is ConnectionStatus.Connected && row.followeeId == userId ->
                statuses[other] = ConnectionStatus.RequestReceived
            statuses[other] !is ConnectionStatus.Connected &&
                statuses[other] !is ConnectionStatus.RequestReceived ->
                statuses[other] = ConnectionStatus.RequestSent
        }
        if (row.followeeId == userId) row.follower?.let { people[other] = it }
    }

    val pending = people.values
        .filter { statuses[it.id] is ConnectionStatus.RequestReceived }
        .sortedBy { it.id }
    return ConnectionSnapshot(statuses = statuses, pending = pending)
}

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
    private var generation = 0

    fun statusFor(other: String): ConnectionStatus =
        _statuses.value[other] ?: ConnectionStatus.None

    val connectedCount: Int get() =
        _statuses.value.values.count { it is ConnectionStatus.Connected }

    fun reset(userId: String?) {
        if (_userId.value == userId) return
        generation++
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
        if (force && refreshJob != null) {
            generation++
            refreshJob?.cancel()
            refreshJob = null
        }
        if (refreshJob?.isActive == true) return
        val requestGeneration = generation
        refreshJob = scope.launch {
            try {
                val snapshot = buildConnectionSnapshot(userId, repository.connectionRecords(userId))
                if (generation != requestGeneration || _userId.value != userId) return@launch
                apply(snapshot)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Throwable) {
                if (generation == requestGeneration && _userId.value == userId) {
                    _refreshFailed.value = true
                }
            } finally {
                if (generation == requestGeneration) refreshJob = null
            }
        }
    }

    suspend fun perform(action: ConnectionAction, with: String): Boolean {
        val userId = _userId.value ?: return false
        if (with == userId || _updating.value.contains(with)) return false

        generation++
        refreshJob?.cancel()
        refreshJob = null
        _updating.value = _updating.value + with
        _errorMessage.value = null

        var succeeded = false
        try {
            val status = repository.transitionConnection(with, action)
            if (_userId.value != userId) return false
            val newStatuses = _statuses.value.toMutableMap()
            if (status is ConnectionStatus.None) newStatuses.remove(with)
            else newStatuses[with] = status
            _statuses.value = newStatuses
            if (status !is ConnectionStatus.RequestReceived) {
                _pending.value = _pending.value.filter { it.id != with }
            }
            _revision.value++
            succeeded = true
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Throwable) {
            if (_userId.value == userId) {
                _errorMessage.value = AppLocale.localized(
                    "연결 상태를 변경하지 못했습니다. 요청이 취소되었거나 네트워크에 문제가 있을 수 있습니다.",
                    "Unable to update the connection. Please try again.",
                    "Die Verbindung konnte nicht geändert werden. Bitte versuche es erneut."
                )
            }
        } finally {
            _updating.value = _updating.value - with
        }
        if (_userId.value == userId && _updating.value.isEmpty()) refreshAfterMutation(userId)
        return succeeded
    }

    fun clearError() {
        _errorMessage.value = null
    }

    private fun apply(snapshot: ConnectionSnapshot) {
        if (_statuses.value != snapshot.statuses || _pending.value != snapshot.pending || !_hasLoaded.value) {
            _statuses.value = snapshot.statuses
            _pending.value = snapshot.pending
            _revision.value++
        }
        _hasLoaded.value = true
        _refreshFailed.value = false
    }

    private suspend fun refreshAfterMutation(userId: String) {
        val requestGeneration = ++generation
        try {
            val snapshot = buildConnectionSnapshot(userId, repository.connectionRecords(userId))
            if (generation == requestGeneration && _userId.value == userId) apply(snapshot)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Throwable) {
            if (generation == requestGeneration && _userId.value == userId) {
                // Keep the optimistic result; realtime/polling will reconcile it.
                _refreshFailed.value = true
            }
        }
    }
}
