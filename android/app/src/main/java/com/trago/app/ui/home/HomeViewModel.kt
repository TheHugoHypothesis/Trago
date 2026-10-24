package com.trago.app.ui.home

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.trago.app.data.ApiResult
import com.trago.app.data.TragoRepository
import com.trago.app.data.model.Account
import com.trago.app.ui.UiState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class HomeViewModel(private val repository: TragoRepository) : ViewModel() {

    val state = repository.state

    private val _health = MutableStateFlow<UiState<Boolean>>(UiState.Loading)
    val health: StateFlow<UiState<Boolean>> = _health.asStateFlow()

    private val _accounts = MutableStateFlow<UiState<List<Account>>>(UiState.Loading)
    val accounts: StateFlow<UiState<List<Account>>> = _accounts.asStateFlow()

    init {
        refresh()
    }

    fun refresh() {
        val sessionKey = state.value.sessionKey
        viewModelScope.launch {
            _health.value = UiState.Loading
            val healthResult = repository.health()
            // Sessão mudou durante a chamada: descarta o resultado antigo.
            if (state.value.sessionKey != sessionKey) return@launch
            _health.value = when (healthResult) {
                is ApiResult.Success -> UiState.Success(healthResult.data.status == "ok")
                is ApiResult.Failure -> UiState.Error(healthResult.message)
            }
            loadAccounts(sessionKey)
        }
    }

    private suspend fun loadAccounts(sessionKey: String) {
        _accounts.value = UiState.Loading
        val result = repository.loadAccounts()
        if (state.value.sessionKey != sessionKey) return
        _accounts.value = when (result) {
            is ApiResult.Success -> UiState.Success(result.data)
            is ApiResult.Failure -> UiState.Error(result.message)
        }
    }

    fun selectAccount(accountId: String) = repository.selectAccount(accountId)

    fun applyConnection(baseUrl: String, token: String) {
        repository.updateConnection(baseUrl, token)
        refresh()
    }
}
