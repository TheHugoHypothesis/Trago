package com.trago.app

import com.trago.app.data.ApiResult
import com.trago.app.data.AppState
import com.trago.app.ui.UiState
import com.trago.app.ui.draft.DraftViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class DraftViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private fun readyState() = AppState(
        baseUrl = "http://10.0.2.2:3001",
        token = "dev:buyer",
        accounts = listOf(testAccount("personal-buyer", "PERSONAL")),
        selectedAccountId = "personal-buyer",
        selectedTrip = testTrip(),
    )

    private fun fillValidForm(viewModel: DraftViewModel) {
        viewModel.updateDescription("Fone de ouvido sem fio")
        viewModel.updateUrl("")
        viewModel.updateAmount("3000")
        viewModel.updateCurrency("USD")
        viewModel.updateWeightGrams("300")
    }

    @Test
    fun `submit válido encaminha conta, viagem, produto e chave de idempotência`() = runTest {
        val repository = FakeTragoRepository(readyState())
        repository.createResult = ApiResult.Success(testRequest("req-1", "personal-buyer"))
        val viewModel = DraftViewModel(repository, newIdempotencyKey = { "key-123" })

        fillValidForm(viewModel)
        viewModel.submit()
        advanceUntilIdle()

        assertEquals(listOf("key-123"), repository.createdKeys)
        assertEquals(listOf("personal-buyer"), repository.createdAccountIds)
        assertEquals(listOf("trip-1"), repository.createdTripIds)
        assertEquals("3000", repository.createdProducts.single().price.amount)
        assertEquals(300, repository.createdProducts.single().estimatedWeightGrams)
        assertTrue(viewModel.submit.value is UiState.Success)
    }

    @Test
    fun `falha de rede não vira sucesso e reenvio reutiliza a mesma chave`() = runTest {
        val repository = FakeTragoRepository(readyState())
        repository.createResult = ApiResult.Failure("Sem conexão com a API.")
        val viewModel = DraftViewModel(repository, newIdempotencyKey = { "key-123" })

        fillValidForm(viewModel)
        viewModel.submit()
        advanceUntilIdle()

        assertTrue(viewModel.submit.value is UiState.Error)
        assertEquals("Sem conexão com a API.", (viewModel.submit.value as UiState.Error).message)

        // Reenvio idêntico: mesma chave (idempotência) e, agora, sucesso real.
        repository.createResult = ApiResult.Success(testRequest("req-1", "personal-buyer"))
        viewModel.submit()
        advanceUntilIdle()

        assertEquals(listOf("key-123", "key-123"), repository.createdKeys)
        assertTrue(viewModel.submit.value is UiState.Success)
    }

    @Test
    fun `formulário inválido não chama a API`() = runTest {
        val repository = FakeTragoRepository(readyState())
        val viewModel = DraftViewModel(repository, newIdempotencyKey = { "key-123" })

        // Peso inválido e valor não inteiro.
        viewModel.updateDescription("Produto")
        viewModel.updateAmount("abc")
        viewModel.updateWeightGrams("0")
        viewModel.submit()
        advanceUntilIdle()

        assertTrue(repository.createdKeys.isEmpty())
        assertTrue(viewModel.submit.value is UiState.Error)
    }
}
