package com.trago.app

import com.trago.app.data.ApiResult
import com.trago.app.data.AppState
import com.trago.app.data.model.Money
import com.trago.app.data.model.Trip
import com.trago.app.ui.UiState
import com.trago.app.ui.publish.PublishViewModel
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class PublishViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private fun readyState() = AppState(
        baseUrl = "http://10.0.2.2:3001",
        token = "dev:traveler",
    )

    private fun fillValidForm(viewModel: PublishViewModel) {
        viewModel.updateOrigin("Lisboa")
        viewModel.updateDestination("São Paulo (SP)")
        viewModel.updateDepartureDate("2026-12-25")
        viewModel.updateTimeZone("Europe/Lisbon")
        viewModel.updateWeightGrams("6000")
        viewModel.updateAmount("5000")
        viewModel.updateCurrency("USD")
    }

    private fun testCreatedTrip() = Trip(
        id = "trip-new",
        travelerName = "Viajante (exemplo)",
        origin = "Lisboa",
        destination = "São Paulo (SP)",
        departureDate = "2026-12-25",
        timeZone = "Europe/Lisbon",
        availableWeightGrams = 6000,
        pricePerKg = Money(amount = "5000", currency = "USD"),
        isDemo = true,
    )

    @Test
    fun `publicar válido encaminha campos do contrato`() = runTest {
        val repository = FakeTragoRepository(readyState())
        repository.createTripResult = ApiResult.Success(testCreatedTrip())
        val viewModel = PublishViewModel(repository)

        fillValidForm(viewModel)
        viewModel.submit()
        advanceUntilIdle()

        val input = repository.createdTripInputs.single()
        assertEquals("Lisboa", input.origin)
        assertEquals("São Paulo (SP)", input.destination)
        assertEquals("2026-12-25", input.departureDate)
        assertEquals("Europe/Lisbon", input.timeZone)
        assertEquals(6000, input.availableWeightGrams)
        assertEquals("5000", input.pricePerKg.amount)
        assertEquals("USD", input.pricePerKg.currency)
        assertTrue(viewModel.submit.value is UiState.Success)
    }

    @Test
    fun `formulário inválido não chama a API`() = runTest {
        val repository = FakeTragoRepository(readyState())
        val viewModel = PublishViewModel(repository)

        viewModel.updateOrigin("L") // < 2 caracteres
        viewModel.updateAmount("12.5") // não inteiro (centavos)
        viewModel.submit()
        advanceUntilIdle()

        assertTrue(repository.createdTripInputs.isEmpty())
        assertTrue(viewModel.submit.value is UiState.Error)
    }

    @Test
    fun `trocar de sessão limpa o resultado da publicação`() = runTest {
        val repository = FakeTragoRepository(readyState())
        repository.createTripResult = ApiResult.Success(testCreatedTrip())
        val viewModel = PublishViewModel(repository)

        fillValidForm(viewModel)
        viewModel.submit()
        advanceUntilIdle()
        assertTrue(viewModel.submit.value is UiState.Success)

        repository.updateConnection("http://10.0.2.2:3001", "dev:buyer")
        advanceUntilIdle()

        assertTrue(viewModel.submit.value is UiState.Idle)
    }
}
