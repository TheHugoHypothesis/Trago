package com.trago.app.data.api

import com.trago.app.data.model.AccountsResponse
import com.trago.app.data.model.HealthResponse
import com.trago.app.data.model.PurchaseRequest
import com.trago.app.data.model.PurchaseRequestsResponse
import com.trago.app.data.model.RequestInput
import com.trago.app.data.model.Trip
import com.trago.app.data.model.TripInput
import com.trago.app.data.model.TripsResponse
import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.Header
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Cliente Kotlin gerado manualmente a partir do contrato congelado
 * `contracts/http/openapi.json`. As operações espelham operationId/paths
 * daquele documento; nenhum endpoint é inventado aqui.
 */
interface TragoApi {

    @GET("health")
    suspend fun health(): HealthResponse

    @GET("v1/me/accounts")
    suspend fun listAccounts(): AccountsResponse

    @GET("v1/trips")
    suspend fun searchTrips(
        @Query("origin") origin: String?,
        @Query("destination") destination: String?,
        @Query("departureDate") departureDate: String?,
        @Query("cursor") cursor: String?,
    ): TripsResponse

    @POST("v1/trips")
    suspend fun createTrip(@Body body: TripInput): Trip

    @GET("v1/purchase-requests")
    suspend fun listPurchaseRequests(
        @Query("accountId") accountId: String,
    ): PurchaseRequestsResponse

    @POST("v1/purchase-requests")
    suspend fun createPurchaseRequest(
        @Header("Idempotency-Key") idempotencyKey: String,
        @Body body: RequestInput,
    ): PurchaseRequest

    @GET("v1/purchase-requests/{id}")
    suspend fun getPurchaseRequest(@Path("id") id: String): PurchaseRequest
}
