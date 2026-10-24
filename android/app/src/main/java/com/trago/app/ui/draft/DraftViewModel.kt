package com.trago.app.ui.draft

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.trago.app.data.ApiResult
import com.trago.app.data.TragoRepository
import com.trago.app.data.model.Money
import com.trago.app.data.model.Product
import com.trago.app.data.model.PurchaseRequest
import com.trago.app.ui.UiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.util.UUID

data class DraftForm(
    val description: String = "",
    val url: String = "",
    val amount: String = "",
    val currency: String = "USD",
    val weightGrams: String = "",
)

class DraftViewModel(
    private val repository: TragoRepository,
    private val newIdempotencyKey: () -> String = { UUID.randomUUID().toString() },
) : ViewModel() {

    val state = repository.state

    private val _form = MutableStateFlow(DraftForm())
    val form: StateFlow<DraftForm> = _form.asStateFlow()

    private val _submit = MutableStateFlow<UiState<PurchaseRequest>>(UiState.Idle)
    val submit: StateFlow<UiState<PurchaseRequest>> = _submit.asStateFlow()

    private val _validationError = MutableStateFlow<String?>(null)
    val validationError: StateFlow<String?> = _validationError.asStateFlow()

    // A mesma chave é reutilizada em reenvios do mesmo rascunho (idempotência AC-04).
    private var idempotencyKey: String? = null

    init {
        // Trocar sessão/conta/viagem limpa o resultado e a chave do rascunho
        // anterior para não vazar estado privado entre contextos (AC-06).
        viewModelScope.launch {
            repository.state
                .map { it.contextKey }
                .distinctUntilChanged()
                .drop(1)
                .collect {
                    idempotencyKey = null
                    _submit.value = UiState.Idle
                    _validationError.value = null
                }
        }
    }

    fun updateDescription(value: String) { _form.value = _form.value.copy(description = value) }
    fun updateUrl(value: String) { _form.value = _form.value.copy(url = value) }
    fun updateAmount(value: String) { _form.value = _form.value.copy(amount = value) }
    fun updateCurrency(value: String) { _form.value = _form.value.copy(currency = value) }
    fun updateWeightGrams(value: String) { _form.value = _form.value.copy(weightGrams = value) }

    fun submit() {
        val validation = validate(_form.value)
        if (validation != null) {
            _validationError.value = validation
            _submit.value = UiState.Error(validation)
            return
        }
        _validationError.value = null

        val account = state.value.selectedAccount
        val trip = state.value.selectedTrip
        if (account == null || trip == null) {
            val message = "Selecione uma conta (PF/PJ) e uma viagem antes de criar o rascunho."
            _validationError.value = message
            _submit.value = UiState.Error(message)
            return
        }

        val key = idempotencyKey ?: newIdempotencyKey().also { idempotencyKey = it }
        val product = Product(
            description = _form.value.description.trim(),
            url = _form.value.url.trim().ifBlank { null },
            price = Money(amount = _form.value.amount.trim(), currency = _form.value.currency),
            estimatedWeightGrams = _form.value.weightGrams.trim().toInt(),
        )
        val contextKey = state.value.contextKey

        viewModelScope.launch {
            _submit.value = UiState.Loading
            val result = repository.createPurchaseRequest(
                accountId = account.id,
                tripId = trip.id,
                product = product,
                idempotencyKey = key,
            )
            // Contexto mudou durante o envio: descarta resultado do contexto anterior.
            if (state.value.contextKey != contextKey) return@launch

            _submit.value = when (result) {
                is ApiResult.Success -> {
                    idempotencyKey = null
                    UiState.Success(result.data)
                }
                is ApiResult.Failure -> UiState.Error(result.message)
            }
        }
    }

    fun clearResult() {
        _submit.value = UiState.Idle
        _validationError.value = null
    }

    private fun validate(form: DraftForm): String? = when {
        form.description.isBlank() -> "Descreva o produto."
        form.description.trim().length > 500 -> "Descrição longa demais (máx. 500)."
        // amount é string de inteiros (centavos/centésimos); sem ponto decimal.
        form.amount.isBlank() || !form.amount.trim().all { it.isDigit() } ->
            "Valor deve ser um inteiro em centavos (somente dígitos)."
        form.weightGrams.isBlank() || form.weightGrams.trim().toIntOrNull() == null ||
            (form.weightGrams.trim().toIntOrNull() ?: 0) < 1 ->
            "Peso deve ser um inteiro em gramas, no mínimo 1."
        else -> null
    }
}
