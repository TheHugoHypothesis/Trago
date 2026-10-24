package com.trago.app.data

import com.trago.app.data.api.TragoApi
import com.trago.app.data.model.Account
import com.trago.app.data.model.ApiErrorBody
import com.trago.app.data.model.HealthResponse
import com.trago.app.data.model.Product
import com.trago.app.data.model.PurchaseRequest
import com.trago.app.data.model.PurchaseRequestsResponse
import com.trago.app.data.model.RequestInput
import com.trago.app.data.model.Trip
import com.trago.app.data.model.TripsResponse
import com.trago.app.data.model.Money
import com.trago.app.data.model.TripInput
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import retrofit2.HttpException
import java.io.IOException

/** Contrato de dados consumido pelos ViewModels (permite fake em testes). */
interface TragoRepository {
    val state: StateFlow<AppState>
    fun updateConnection(baseUrl: String, token: String)
    suspend fun loadAccounts(): ApiResult<List<Account>>
    fun selectAccount(accountId: String)
    fun selectTrip(trip: Trip?)
    suspend fun health(): ApiResult<HealthResponse>
    suspend fun searchTrips(
        origin: String,
        destination: String,
        departureDate: String,
        cursor: String? = null,
    ): ApiResult<TripsResponse>
    suspend fun createPurchaseRequest(
        accountId: String,
        tripId: String,
        product: Product,
        idempotencyKey: String,
    ): ApiResult<PurchaseRequest>
    suspend fun listPurchaseRequests(accountId: String): ApiResult<PurchaseRequestsResponse>
    suspend fun createTrip(input: TripInput): ApiResult<Trip>
}

/**
 * Fonte única de dados/estado do app. O backend é autoritativo; aqui apenas
 * orquestramos sessão demo, contexto PF/PJ e chamadas do contrato congelado.
 */
class DefaultTragoRepository(
    private val settings: AppSettings,
    private val apiFactory: (baseUrl: String, token: String) -> TragoApi,
) : TragoRepository {

    private val _state = MutableStateFlow(
        AppState(
            baseUrl = settings.baseUrl,
            token = settings.token,
        )
    )
    override val state: StateFlow<AppState> = _state.asStateFlow()

    private val api: TragoApi
        get() = apiFactory(_state.value.baseUrl, _state.value.token)

    override fun updateConnection(baseUrl: String, token: String) {
        val normalizedBase = baseUrl.trim().ifBlank { settings.baseUrl }
        val normalizedToken = token.trim().ifBlank { settings.token }
        settings.baseUrl = normalizedBase
        settings.token = normalizedToken
        _state.update {
            it.copy(
                baseUrl = normalizedBase,
                token = normalizedToken,
                accounts = emptyList(),
                selectedAccountId = null,
                selectedTrip = null,
            )
        }
    }

    override suspend fun loadAccounts(): ApiResult<List<Account>> = safeCall {
        val response = api.listAccounts()
        _state.update {
            val selected = it.selectedAccountId
                ?: response.items.firstOrNull()?.id
            it.copy(accounts = response.items, selectedAccountId = selected)
        }
        response.items
    }

    override fun selectAccount(accountId: String) {
        _state.update {
            // Trocar de conta limpa o rascunho selecionado (isolamento PF/PJ).
            it.copy(selectedAccountId = accountId, selectedTrip = null)
        }
    }

    override fun selectTrip(trip: Trip?) {
        _state.update { it.copy(selectedTrip = trip) }
    }

    override suspend fun health(): ApiResult<HealthResponse> = safeCall { api.health() }

    override suspend fun searchTrips(
        origin: String,
        destination: String,
        departureDate: String,
        cursor: String?,
    ): ApiResult<TripsResponse> = safeCall {
        api.searchTrips(
            origin = origin.trim().ifBlank { null },
            destination = destination.trim().ifBlank { null },
            departureDate = departureDate.trim().ifBlank { null },
            cursor = cursor,
        )
    }

    override suspend fun createPurchaseRequest(
        accountId: String,
        tripId: String,
        product: Product,
        idempotencyKey: String,
    ): ApiResult<PurchaseRequest> = safeCall {
        api.createPurchaseRequest(
            idempotencyKey = idempotencyKey,
            body = RequestInput(accountId = accountId, tripId = tripId, product = product),
        )
    }

    override suspend fun listPurchaseRequests(accountId: String): ApiResult<PurchaseRequestsResponse> =
        safeCall { api.listPurchaseRequests(accountId = accountId) }

    override suspend fun createTrip(input: TripInput): ApiResult<Trip> = safeCall { api.createTrip(input) }

    private inline fun <T> safeCall(block: () -> T): ApiResult<T> = try {
        ApiResult.Success(block())
    } catch (e: HttpException) {
        val body = runCatching {
            e.response()?.errorBody()?.string()
                ?.let { com.google.gson.Gson().fromJson(it, ApiErrorBody::class.java) }
        }.getOrNull()
        ApiResult.Failure(
            message = body?.message ?: "Erro ${e.code()} na API",
            code = body?.code,
            statusCode = e.code(),
        )
    } catch (e: IOException) {
        ApiResult.Failure(message = "Sem conexão com a API. Verifique a rede e a URL base.")
    } catch (e: Exception) {
        ApiResult.Failure(message = e.message ?: "Erro inesperado")
    }
}

/** Helper para construção de dinheiro no formato do contrato (amount = string). */
fun money(amount: String, currency: String): Money = Money(amount = amount, currency = currency)
