package com.trago.app.ui.publish

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.trago.app.data.ApiResult
import com.trago.app.data.TragoRepository
import com.trago.app.data.model.Money
import com.trago.app.data.model.Trip
import com.trago.app.data.model.TripInput
import com.trago.app.ui.UiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

data class PublishForm(
    val origin: String = "",
    val destination: String = "",
    val departureDate: String = "",
    val timeZone: String = "America/Sao_Paulo",
    val weightGrams: String = "",
    val amount: String = "",
    val currency: String = "USD",
)

/**
 * Publicação de viagem fictícia (POST /v1/trips). Exige identidade de viajante
 * (`dev:traveler`); o backend é autoritativo e recusa outras identidades.
 */
class PublishViewModel(
    private val repository: TragoRepository,
) : ViewModel() {

    val state = repository.state

    private val _form = MutableStateFlow(PublishForm())
    val form: StateFlow<PublishForm> = _form.asStateFlow()

    private val _submit = MutableStateFlow<UiState<Trip>>(UiState.Idle)
    val submit: StateFlow<UiState<Trip>> = _submit.asStateFlow()

    private val _validationError = MutableStateFlow<String?>(null)
    val validationError: StateFlow<String?> = _validationError.asStateFlow()

    init {
        // Trocar sessão limpa o resultado da publicação anterior.
        viewModelScope.launch {
            repository.state
                .map { it.sessionKey }
                .distinctUntilChanged()
                .drop(1)
                .collect {
                    _submit.value = UiState.Idle
                    _validationError.value = null
                }
        }
    }

    fun updateOrigin(value: String) { _form.value = _form.value.copy(origin = value) }
    fun updateDestination(value: String) { _form.value = _form.value.copy(destination = value) }
    fun updateDepartureDate(value: String) { _form.value = _form.value.copy(departureDate = value) }
    fun updateTimeZone(value: String) { _form.value = _form.value.copy(timeZone = value) }
    fun updateWeightGrams(value: String) { _form.value = _form.value.copy(weightGrams = value) }
    fun updateAmount(value: String) { _form.value = _form.value.copy(amount = value) }
    fun updateCurrency(value: String) { _form.value = _form.value.copy(currency = value) }

    fun submit() {
        val form = _form.value
        val validation = validate(form)
        if (validation != null) {
            _validationError.value = validation
            _submit.value = UiState.Error(validation)
            return
        }
        _validationError.value = null

        val input = TripInput(
            origin = form.origin.trim(),
            destination = form.destination.trim(),
            departureDate = form.departureDate.trim(),
            timeZone = form.timeZone.trim(),
            availableWeightGrams = form.weightGrams.trim().toInt(),
            pricePerKg = Money(amount = form.amount.trim(), currency = form.currency),
        )
        val sessionKey = state.value.sessionKey

        viewModelScope.launch {
            _submit.value = UiState.Loading
            val result = repository.createTrip(input)
            if (state.value.sessionKey != sessionKey) return@launch

            _submit.value = when (result) {
                is ApiResult.Success -> UiState.Success(result.data)
                is ApiResult.Failure -> UiState.Error(result.message)
            }
        }
    }

    fun clearResult() {
        _submit.value = UiState.Idle
        _validationError.value = null
    }

    private fun validate(form: PublishForm): String? = when {
        form.origin.trim().length < 2 -> "Origem deve ter ao menos 2 caracteres."
        form.destination.trim().length < 2 -> "Destino deve ter ao menos 2 caracteres."
        !DATE_REGEX.matches(form.departureDate.trim()) -> "Data deve estar no formato AAAA-MM-DD."
        form.timeZone.isBlank() -> "Informe o fuso horário (ex.: America/Sao_Paulo)."
        form.weightGrams.isBlank() || form.weightGrams.trim().toIntOrNull() == null ||
            (form.weightGrams.trim().toIntOrNull() ?: 0) < 1 ->
            "Capacidade deve ser um inteiro em gramas, no mínimo 1."
        form.amount.isBlank() || !form.amount.trim().all { it.isDigit() } ->
            "Tarifa deve ser um inteiro em centavos (somente dígitos)."
        else -> null
    }

    companion object {
        private val DATE_REGEX = Regex("""\d{4}-\d{2}-\d{2}""")
    }
}
