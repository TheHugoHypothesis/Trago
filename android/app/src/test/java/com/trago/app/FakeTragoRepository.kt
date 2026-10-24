package com.trago.app

import com.trago.app.data.ApiResult
import com.trago.app.data.AppState
import com.trago.app.data.TragoRepository
import com.trago.app.data.model.Account
import com.trago.app.data.model.HealthResponse
import com.trago.app.data.model.Money
import com.trago.app.data.model.Product
import com.trago.app.data.model.PurchaseRequest
import com.trago.app.data.model.PurchaseRequestsResponse
import com.trago.app.data.model.Trip
import com.trago.app.data.model.TripInput
import com.trago.app.data.model.TripsResponse
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Fake do repositório para testes de estado/UI. Captura chamadas de criação de
 * rascunho (idempotência) e de listagem (isolamento por conta).
 */
class FakeTragoRepository(initial: AppState = AppState()) : TragoRepository {

    override val state = MutableStateFlow(initial)

    var createResult: ApiResult<PurchaseRequest> =
        ApiResult.Failure("não configurado")

    val createdKeys = mutableListOf<String>()
    val createdAccountIds = mutableListOf<String>()
    val createdTripIds = mutableListOf<String>()
    val createdProducts = mutableListOf<Product>()

    val listedAccountIds = mutableListOf<String>()
    var listResult: ApiResult<PurchaseRequestsResponse> =
        ApiResult.Success(PurchaseRequestsResponse(items = emptyList(), nextCursor = null))

    override fun updateConnection(baseUrl: String, token: String) {
        state.value = state.value.copy(
            baseUrl = baseUrl,
            token = token,
            accounts = emptyList(),
            selectedAccountId = null,
            selectedTrip = null,
        )
    }

    override suspend fun loadAccounts(): ApiResult<List<Account>> =
        ApiResult.Success(state.value.accounts)

    override fun selectAccount(accountId: String) {
        state.value = state.value.copy(selectedAccountId = accountId, selectedTrip = null)
    }

    override fun selectTrip(trip: Trip?) {
        state.value = state.value.copy(selectedTrip = trip)
    }

    override suspend fun health(): ApiResult<HealthResponse> =
        ApiResult.Success(HealthResponse(status = "ok"))

    override suspend fun searchTrips(
        origin: String,
        destination: String,
        departureDate: String,
        cursor: String?,
    ): ApiResult<TripsResponse> = ApiResult.Success(TripsResponse(emptyList(), null))

    override suspend fun createPurchaseRequest(
        accountId: String,
        tripId: String,
        product: Product,
        idempotencyKey: String,
    ): ApiResult<PurchaseRequest> {
        createdKeys += idempotencyKey
        createdAccountIds += accountId
        createdTripIds += tripId
        createdProducts += product
        return createResult
    }

    override suspend fun listPurchaseRequests(accountId: String): ApiResult<PurchaseRequestsResponse> {
        listedAccountIds += accountId
        return listResult
    }

    override suspend fun createTrip(input: TripInput): ApiResult<Trip> {
        createdTripInputs += input
        return createTripResult
    }

    val createdTripInputs = mutableListOf<TripInput>()
    var createTripResult: ApiResult<Trip> = ApiResult.Failure("não configurado")
}

fun testAccount(id: String, type: String = "PERSONAL") = Account(
    id = id,
    type = type,
    displayName = "Conta $id",
    taxId = if (type == "ORGANIZATION") "12.ABC.345/01DE-35" else null,
)

fun testTrip() = Trip(
    id = "trip-1",
    travelerName = "Ana C. (exemplo)",
    origin = "Nova York (EUA)",
    destination = "São Paulo (SP)",
    departureDate = "2026-12-15",
    timeZone = "America/Sao_Paulo",
    availableWeightGrams = 8000,
    pricePerKg = Money(amount = "4500", currency = "USD"),
    isDemo = true,
)

fun testRequest(id: String, accountId: String) = PurchaseRequest(
    id = id,
    accountId = accountId,
    tripId = "trip-1",
    product = Product(
        description = "Fone de ouvido",
        url = null,
        price = Money(amount = "3000", currency = "USD"),
        estimatedWeightGrams = 300,
    ),
    status = "DRAFT",
    createdAt = "2026-10-19T00:00:00Z",
)
