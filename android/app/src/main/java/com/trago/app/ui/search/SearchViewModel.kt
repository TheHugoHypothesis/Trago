package com.trago.app.ui.search

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.trago.app.data.ApiResult
import com.trago.app.data.TragoRepository
import com.trago.app.data.model.Trip
import com.trago.app.data.model.TripsResponse
import com.trago.app.ui.UiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

data class SearchQuery(
    val origin: String = "",
    val destination: String = "",
    val departureDate: String = "",
)

class SearchViewModel(private val repository: TragoRepository) : ViewModel() {

    private val _query = MutableStateFlow(SearchQuery())
    val query: StateFlow<SearchQuery> = _query.asStateFlow()

    private val _results = MutableStateFlow<UiState<TripsResponse>>(UiState.Idle)
    val results: StateFlow<UiState<TripsResponse>> = _results.asStateFlow()

    private val _nextCursor = MutableStateFlow<String?>(null)
    val nextCursor: StateFlow<String?> = _nextCursor.asStateFlow()

    private val _loadingMore = MutableStateFlow(false)
    val loadingMore: StateFlow<Boolean> = _loadingMore.asStateFlow()

    private val _loadMoreError = MutableStateFlow<String?>(null)
    val loadMoreError: StateFlow<String?> = _loadMoreError.asStateFlow()

    init {
        // Trocar sessão (URL/token) limpa resultados da sessão anterior para
        // não exibir ofertas/erros de um contexto que não é mais o atual.
        viewModelScope.launch {
            repository.state
                .map { it.sessionKey }
                .distinctUntilChanged()
                .drop(1)
                .collect {
                    _results.value = UiState.Idle
                    _nextCursor.value = null
                    _loadMoreError.value = null
                }
        }
    }

    fun updateOrigin(value: String) { _query.value = _query.value.copy(origin = value) }
    fun updateDestination(value: String) { _query.value = _query.value.copy(destination = value) }
    fun updateDepartureDate(value: String) { _query.value = _query.value.copy(departureDate = value) }

    fun search() {
        val q = _query.value
        if (q.origin.isBlank() && q.destination.isBlank() && q.departureDate.isBlank()) {
            _results.value = UiState.Error("Informe ao menos um filtro (origem, destino ou data).")
            return
        }
        fetch(q, cursor = null, append = false)
    }

    fun loadMore() {
        val cursor = _nextCursor.value ?: return
        if (_loadingMore.value) return
        fetch(_query.value, cursor = cursor, append = true)
    }

    private fun fetch(q: SearchQuery, cursor: String?, append: Boolean) {
        val sessionKey = repository.state.value.sessionKey
        viewModelScope.launch {
            if (append) {
                _loadingMore.value = true
                _loadMoreError.value = null
            } else {
                _results.value = UiState.Loading
                _nextCursor.value = null
                _loadMoreError.value = null
            }

            val result = repository.searchTrips(q.origin, q.destination, q.departureDate, cursor)

            // Sessão mudou enquanto a chamada estava em voo: descarta o
            // resultado antigo para não vazar o contexto anterior.
            if (repository.state.value.sessionKey != sessionKey) {
                if (append) _loadingMore.value = false
                return@launch
            }

            when (result) {
                is ApiResult.Success -> {
                    val combined = if (append) {
                        val previous = (_results.value as? UiState.Success)?.data
                        TripsResponse(
                            items = (previous?.items ?: emptyList()) + result.data.items,
                            nextCursor = result.data.nextCursor,
                        )
                    } else {
                        result.data
                    }
                    _results.value = UiState.Success(combined)
                    _nextCursor.value = result.data.nextCursor
                }
                is ApiResult.Failure -> {
                    if (append) {
                        // Mantém os itens já carregados; expõe o erro para nova tentativa.
                        _loadMoreError.value = result.message
                    } else {
                        _results.value = UiState.Error(result.message)
                    }
                }
            }

            if (append) _loadingMore.value = false
        }
    }

    fun chooseTrip(trip: Trip) = repository.selectTrip(trip)
}
