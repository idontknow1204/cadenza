package com.cadenza.android.core.session

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.Profile
import com.cadenza.android.core.data.repository.Repository
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.gotrue.SessionStatus
import io.github.jan.supabase.gotrue.user.UserInfo
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.serialization.json.put
import javax.inject.Inject

@HiltViewModel
class SessionViewModel @Inject constructor(
    private val client: SupabaseClient,
    val repository: Repository,
) : ViewModel() {

    private val _sessionStatus = MutableStateFlow<SessionStatus>(SessionStatus.LoadingFromStorage)
    val sessionStatus: StateFlow<SessionStatus> = _sessionStatus.asStateFlow()

    private val _profile = MutableStateFlow<Profile?>(null)
    val profile: StateFlow<Profile?> = _profile.asStateFlow()

    private val _profileError = MutableStateFlow<String?>(null)
    val profileError: StateFlow<String?> = _profileError.asStateFlow()

    // Incremented each time a new authenticated session completes bootstrap —
    // screens subscribe to this instead of racing raw auth events.
    private val _authenticatedDataRevision = MutableStateFlow(0)
    val authenticatedDataRevision: StateFlow<Int> = _authenticatedDataRevision.asStateFlow()

    val currentUserId: String?
        get() = client.auth.currentSessionOrNull()?.user?.id

    val needsOnboarding: Boolean
        get() = _profile.value?.onboardingComplete == false

    init {
        client.auth.sessionStatus
            .onEach { status -> handleStatusChange(status) }
            .launchIn(viewModelScope)
    }

    private suspend fun handleStatusChange(status: SessionStatus) {
        _sessionStatus.value = status
        when (status) {
            is SessionStatus.Authenticated -> {
                val uid = status.session.user?.id ?: return
                loadProfile(uid)
                _authenticatedDataRevision.value++
            }
            is SessionStatus.NotAuthenticated -> {
                _profile.value = null
                _profileError.value = null
                _authenticatedDataRevision.value++
            }
            else -> Unit
        }
    }

    private fun loadProfile(userId: String) {
        viewModelScope.launch {
            try {
                _profile.value = repository.myProfile(userId)
                _profileError.value = null
            } catch (e: Throwable) {
                _profileError.value = e.message
            }
        }
    }

    fun refreshProfile() {
        val uid = currentUserId ?: return
        loadProfile(uid)
    }

    fun signUp(name: String, email: String, password: String, onError: (String) -> Unit) {
        viewModelScope.launch {
            try {
                client.auth.signUpWith(io.github.jan.supabase.gotrue.providers.builtin.Email) {
                    this.email = email
                    this.password = password
                    data = kotlinx.serialization.json.buildJsonObject {
                        put("real_name", name)
                    }
                }
            } catch (e: Throwable) {
                onError(e.message ?: "Sign-up failed")
            }
        }
    }

    fun signIn(email: String, password: String, onError: (String) -> Unit) {
        viewModelScope.launch {
            try {
                client.auth.signInWith(io.github.jan.supabase.gotrue.providers.builtin.Email) {
                    this.email = email
                    this.password = password
                }
            } catch (e: Throwable) {
                onError(e.message ?: "Sign-in failed")
            }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            try { client.auth.signOut() } catch (_: Throwable) {}
            _profile.value = null
            _profileError.value = null
            _authenticatedDataRevision.value++
        }
    }
}
