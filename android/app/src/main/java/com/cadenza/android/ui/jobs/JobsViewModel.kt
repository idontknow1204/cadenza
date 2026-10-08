package com.cadenza.android.ui.jobs

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.cadenza.android.core.data.model.City
import com.cadenza.android.core.data.model.Job
import com.cadenza.android.core.data.model.JobType
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.util.AppLocale
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class JobsViewModel @Inject constructor(
    val repository: Repository,
) : ViewModel() {

    private val _jobs = MutableStateFlow<List<Job>>(emptyList())
    val jobs: StateFlow<List<Job>> = _jobs.asStateFlow()

    private val _cityById = MutableStateFlow<Map<String, City>>(emptyMap())
    val cityById: StateFlow<Map<String, City>> = _cityById.asStateFlow()

    private val _baseCityIds = MutableStateFlow<List<String>>(emptyList())
    val baseCityIds: StateFlow<List<String>> = _baseCityIds.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _loadError = MutableStateFlow<String?>(null)
    val loadError: StateFlow<String?> = _loadError.asStateFlow()

    private val _searchResults = MutableStateFlow<List<Job>>(emptyList())
    val searchResults: StateFlow<List<Job>> = _searchResults.asStateFlow()

    private val _isSearchLoading = MutableStateFlow(false)
    val isSearchLoading: StateFlow<Boolean> = _isSearchLoading.asStateFlow()

    private val _searchError = MutableStateFlow<String?>(null)
    val searchError: StateFlow<String?> = _searchError.asStateFlow()

    private val _filter = MutableStateFlow(JobFilter())
    val filter: StateFlow<JobFilter> = _filter.asStateFlow()

    private val _sort = MutableStateFlow(JobSort.CITY_FIRST)
    val sort: StateFlow<JobSort> = _sort.asStateFlow()

    private var searchTask: kotlinx.coroutines.Job? = null

    fun load(userId: String) {
        if (_isLoading.value) return
        viewModelScope.launch {
            _isLoading.value = true
            _loadError.value = null
            try {
                coroutineScope {
                    val jobsDeferred  = async { repository.jobs() }
                    val citiesDeferred = async { runCatching { repository.cities() }.getOrElse { emptyList() } }
                    val basesDeferred  = async { runCatching { repository.baseCityIds(userId) }.getOrElse { emptyList() } }
                    _jobs.value       = jobsDeferred.await()
                    _cityById.value   = citiesDeferred.await().associateBy { it.id }
                    _baseCityIds.value = basesDeferred.await()
                }
            } catch (e: Exception) {
                _loadError.value = AppLocale.localized(
                    "연결을 확인하고 다시 시도해 주세요.",
                    "Check your connection and try again.",
                    "Verbindung prüfen und erneut versuchen."
                )
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun search(query: String) {
        searchTask?.cancel()
        if (query.isBlank()) {
            _searchResults.value = emptyList()
            _isSearchLoading.value = false
            _searchError.value = null
            return
        }
        searchTask = viewModelScope.launch {
            _isSearchLoading.value = true
            _searchError.value = null
            try {
                delay(300)
                _searchResults.value = repository.searchOpportunities(query)
            } catch (e: Exception) {
                if (e !is CancellationException) {
                    _searchResults.value = emptyList()
                    _searchError.value = AppLocale.localized(
                        "검색에 실패했어요.",
                        "Search failed.",
                        "Suche fehlgeschlagen."
                    )
                }
            } finally {
                _isSearchLoading.value = false
            }
        }
    }

    fun updateFilter(filter: JobFilter) { _filter.value = filter }
    fun updateSort(sort: JobSort) { _sort.value = sort }

    fun closeJob(jobId: String, onSuccess: () -> Unit) {
        viewModelScope.launch {
            try {
                repository.closeJob(jobId)
                _jobs.update { list -> list.filter { it.id != jobId } }
                _searchResults.update { list -> list.filter { it.id != jobId } }
                onSuccess()
            } catch (_: Exception) {}
        }
    }
}

// ─── Filter / Sort ────────────────────────────────────────────────────────────

data class JobFilter(
    val types: Set<JobType>        = emptySet(),
    val instruments: Set<String>   = emptySet(),
    val countryCodes: Set<String>  = emptySet(),
    val videoOnly: Boolean         = false,
    val freeOnly: Boolean          = false,
    val scholarshipOnly: Boolean   = false,
    val openOnly: Boolean          = true,
) {
    val activeCount: Int get() {
        var n = 0
        if (types.isNotEmpty()) n++
        if (instruments.isNotEmpty()) n++
        if (countryCodes.isNotEmpty()) n++
        if (videoOnly) n++
        if (freeOnly) n++
        if (scholarshipOnly) n++
        if (!openOnly) n++
        return n
    }

    fun apply(jobs: List<Job>, cityById: Map<String, City>): List<Job> = jobs.filter { j ->
        if (types.isNotEmpty() && j.type !in types) return@filter false
        if (instruments.isNotEmpty() && j.instruments.none { it in instruments }) return@filter false
        if (countryCodes.isNotEmpty()) {
            val cc = j.cityId?.let { cityById[it]?.countryCode }
            if (cc == null || cc !in countryCodes) return@filter false
        }
        if (videoOnly && j.videoAudition != true) return@filter false
        if (freeOnly && j.applicationFee != 0) return@filter false
        if (scholarshipOnly && j.hasScholarship != true) return@filter false
        if (openOnly && !j.isAcceptingApplications) return@filter false
        true
    }
}

enum class JobSort {
    CITY_FIRST, DEADLINE, RECENT;
    val label: String get() = when (this) {
        CITY_FIRST -> AppLocale.localized("내 도시 우선", "My city first", "Meine Stadt zuerst")
        DEADLINE   -> AppLocale.localized("마감 임박순", "By deadline", "Nach Frist")
        RECENT     -> AppLocale.localized("최근 등록순", "Newest", "Neueste")
    }
}

// ─── Section model ────────────────────────────────────────────────────────────

data class JobSection(
    val id: String,
    val title: String,
    val kind: Kind,
    val jobs: List<Job>,
) {
    enum class Kind { BASE_CITY, BASE_COUNTRY, VIDEO, REST }

    companion object {
        fun build(
            jobs: List<Job>,
            baseCityIds: List<String>,
            cityById: Map<String, City>,
        ): List<JobSection> {
            val used = mutableSetOf<String>()
            val out  = mutableListOf<JobSection>()

            for (cid in baseCityIds) {
                val group = jobs.filter { it.cityId == cid && it.id !in used }.sortedWith(deadlineComparator)
                if (group.isEmpty()) continue
                group.forEach { used.add(it.id) }
                out.add(JobSection("city-$cid", cityById[cid]?.localizedName ?: cid, Kind.BASE_CITY, group))
            }

            val seenCountry = mutableSetOf<String>()
            val baseCountries = baseCityIds.mapNotNull { cityById[it]?.countryCode }
                .filter { seenCountry.add(it) }
            for (cc in baseCountries) {
                val group = jobs.filter { j ->
                    j.id !in used && j.cityId?.let { cityById[it]?.countryCode } == cc
                }.sortedWith(deadlineComparator)
                if (group.isEmpty()) continue
                group.forEach { used.add(it.id) }
                out.add(JobSection("country-$cc", localizedCountryName(cc), Kind.BASE_COUNTRY, group))
            }

            val video = jobs.filter { it.videoAudition == true && it.id !in used }.sortedWith(deadlineComparator)
            if (video.isNotEmpty()) {
                video.forEach { used.add(it.id) }
                out.add(JobSection(
                    "video",
                    AppLocale.localized("영상으로 지원 가능", "Apply by video", "Bewerbung per Video"),
                    Kind.VIDEO,
                    video,
                ))
            }

            val rest = jobs.filter { it.id !in used }.sortedWith(deadlineComparator)
            if (rest.isNotEmpty()) {
                out.add(JobSection(
                    "rest",
                    AppLocale.localized("그 외", "Others", "Weitere"),
                    Kind.REST,
                    rest,
                ))
            }
            return out
        }

        private val deadlineComparator = Comparator<Job> { a, b ->
            fun key(j: Job) = j.daysLeft?.let { if (it < 0) Int.MAX_VALUE - 1 else it } ?: Int.MAX_VALUE
            val ka = key(a); val kb = key(b)
            if (ka != kb) ka.compareTo(kb)
            else (b.createdAt ?: "").compareTo(a.createdAt ?: "")
        }
    }
}

fun localizedCountryName(code: String): String = when (code) {
    "KR" -> AppLocale.localized("한국",        "Korea",             "Südkorea")
    "DE" -> AppLocale.localized("독일",        "Germany",           "Deutschland")
    "AT" -> AppLocale.localized("오스트리아",  "Austria",           "Österreich")
    "CH" -> AppLocale.localized("스위스",      "Switzerland",       "Schweiz")
    "FR" -> AppLocale.localized("프랑스",      "France",            "Frankreich")
    "GB" -> AppLocale.localized("영국",        "UK",                "Vereinigtes Königreich")
    "NL" -> AppLocale.localized("네덜란드",    "Netherlands",       "Niederlande")
    "IT" -> AppLocale.localized("이탈리아",    "Italy",             "Italien")
    "US" -> AppLocale.localized("미국",        "USA",               "USA")
    else -> code
}
