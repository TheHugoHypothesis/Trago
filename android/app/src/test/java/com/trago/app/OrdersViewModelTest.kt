package com.trago.app

import com.trago.app.data.ApiResult
import com.trago.app.data.AppState
import com.trago.app.data.model.PurchaseRequestsResponse
import com.trago.app.ui.UiState
import com.trago.app.ui.orders.OrdersViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class OrdersViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    @Test
    fun `trocar de conta recarrega pedidos no novo contexto privado`() = runTest {
        val repository = FakeTragoRepository(
            AppState(
                accounts = listOf(
                    testAccount("personal-buyer", "PERSONAL"),
                    testAccount("company-demo", "ORGANIZATION"),
                ),
                selectedAccountId = "personal-buyer",
            )
        )
        repository.listResult = ApiResult.Success(
            PurchaseRequestsResponse(items = listOf(testRequest("req-1", "personal-buyer")), nextCursor = null)
        )

        val viewModel = OrdersViewModel(repository)
        advanceUntilIdle()

        assertEquals(listOf("personal-buyer"), repository.listedAccountIds)
        assertTrue((viewModel.orders.value as UiState.Success).data.size == 1)

        // Trocar o contexto PF -> PJ deve limpar o estado anterior e recarregar.
        repository.selectAccount("company-demo")
        advanceUntilIdle()

        assertEquals(listOf("personal-buyer", "company-demo"), repository.listedAccountIds)
    }
}
