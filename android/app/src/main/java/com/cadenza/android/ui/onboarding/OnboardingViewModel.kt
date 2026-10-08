package com.cadenza.android.ui.onboarding

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.Visibility
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.SessionViewModel
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val repository: Repository,
) : ViewModel() {

    private val _step = MutableStateFlow(1)
    val step: StateFlow<Int> = _step.asStateFlow()

    val totalSteps = 8

    // Draft values (mirrors iOS OnboardingCoordinator)
    var major = MutableStateFlow("")
    var instrument = MutableStateFlow("")
    var institutionName = MutableStateFlow("")
    var courseType = MutableStateFlow("")
    var enrollmentYear = MutableStateFlow(java.util.Calendar.getInstance().get(java.util.Calendar.YEAR))
    var homeCities = MutableStateFlow<Set<String>>(emptySet())
    var teacherName = MutableStateFlow("")
    var teacherId = MutableStateFlow<String?>(null)
    var bio = MutableStateFlow("")
    var avatarUri = MutableStateFlow<Uri?>(null)
    var avatarBytes = MutableStateFlow<ByteArray?>(null)
    var defaultVisibility = MutableStateFlow(Visibility.INDUSTRY_FOLLOWERS)

    private val _errorText = MutableStateFlow<String?>(null)
    val errorText: StateFlow<String?> = _errorText.asStateFlow()

    private val _isBusy = MutableStateFlow(false)
    val isBusy: StateFlow<Boolean> = _isBusy.asStateFlow()

    val canSkip: Boolean get() = _step.value in 4..7
    val isLastStep: Boolean get() = _step.value == totalSteps

    fun advance() { if (_step.value < totalSteps) _step.value++ }
    fun back() { if (_step.value > 2) _step.value-- }
    fun advanceFromConsent() { _step.value = 2 }
    fun clearError() { _errorText.value = null }

    fun saveStep2(userId: String) = viewModelScope.launch {
        if (major.value.isEmpty() || instrument.value.isEmpty()) return@launch
        _isBusy.value = true
        try {
            repository.saveInstrument(userId, major.value, instrument.value)
            advance()
        } catch (e: Throwable) {
            _errorText.value = e.message
        } finally {
            _isBusy.value = false
        }
    }

    fun saveStep3(userId: String) = viewModelScope.launch {
        if (institutionName.value.isEmpty()) return@launch
        _isBusy.value = true
        try {
            val ct = courseType.value.ifEmpty { null }
            repository.upsertAffiliation(userId, institutionName.value, ct, enrollmentYear.value)
            repository.saveHomeCities(userId, homeCities.value.toList())
            advance()
        } catch (e: Throwable) {
            _errorText.value = e.message
        } finally {
            _isBusy.value = false
        }
    }

    fun saveStep4(userId: String) = viewModelScope.launch {
        _isBusy.value = true
        try {
            if (teacherName.value.isNotEmpty()) {
                repository.saveTeacher(userId, teacherId.value, teacherName.value)
            }
            advance()
        } catch (e: Throwable) {
            _errorText.value = e.message
        } finally {
            _isBusy.value = false
        }
    }

    fun saveStep5(userId: String) = viewModelScope.launch {
        _isBusy.value = true
        try {
            if (bio.value.isNotEmpty()) repository.saveBio(userId, bio.value)
            val bytes = avatarBytes.value
            if (bytes != null) repository.uploadAvatar(userId, bytes)
            advance()
        } catch (e: Throwable) {
            _errorText.value = e.message
        } finally {
            _isBusy.value = false
        }
    }

    fun completeOnboarding(userId: String, session: SessionViewModel) = viewModelScope.launch {
        _isBusy.value = true
        try {
            repository.completeOnboarding(userId, defaultVisibility.value)
            session.refreshProfile()
        } catch (e: Throwable) {
            _errorText.value = e.message
        } finally {
            _isBusy.value = false
        }
    }
}
