package com.trago.app.ui.orders

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.trago.app.data.ApiResult
import com.trago.app.data.TragoRepository
import com.trago.app.data.model.PurchaseRequest
import com.trago.app.ui.UiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

class OrdersViewModel(private val repository: TragoRepository) : ViewModel() {

    val state = repository.state

    private val _orders = MutableStateFlow<UiState<List<PurchaseRequest>>>(UiState.Loading)
    val orders: StateFlow<UiState<List<PurchaseRequest>>> = _orders.asStateFlow()

    init {
        viewModelScope.launch {
            repository.state
                .map { it.selectedAccountId }
                .distinctUntilChanged()
                .collectLatest { accountId -> load(accountId) }
        }
    }

    fun refresh() = load(repository.state.value.selectedAccountId)

    private fun load(accountId: String?) {
        viewModelScope.launch {
            if (accountId == null) {
                _orders.value = UiState.Error("Selecione uma conta (PF/PJ) para ver os pedidos.")
                return@launch
            }
            _orders.value = UiState.Loading
            _orders.value = when (val result = repository.listPurchaseRequests(accountId)) {
                is ApiResult.Success -> UiState.Success(result.data.items)
                is ApiResult.Failure -> UiState.Error(result.message)
            }
        }
    }
}
