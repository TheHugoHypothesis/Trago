package com.trago.app.data.model

/**
 * Modelos de dados espelhando `contracts/http/openapi.json` (contrato congelado).
 * Campos derivados de identidade/contexto são sempre validados pelo backend.
 */
data class Money(
    val amount: String,
    val currency: String,
)

data class Account(
    val id: String,
    val type: String, // PERSONAL | ORGANIZATION
    val displayName: String,
    val taxId: String? = null,
) {
    val isOrganization: Boolean get() = type == "ORGANIZATION"
}

data class Trip(
    val id: String,
    val travelerName: String,
    val origin: String,
    val destination: String,
    val departureDate: String,
    val timeZone: String,
    val availableWeightGrams: Int,
    val pricePerKg: Money,
    val isDemo: Boolean,
)

data class Product(
    val description: String,
    val url: String? = null,
    val price: Money,
    val estimatedWeightGrams: Int,
)

data class PurchaseRequest(
    val id: String,
    val accountId: String,
    val tripId: String,
    val product: Product,
    val status: String, // DRAFT
    val createdAt: String,
)

data class TripInput(
    val origin: String,
    val destination: String,
    val departureDate: String,
    val timeZone: String,
    val availableWeightGrams: Int,
    val pricePerKg: Money,
)

data class RequestInput(
    val accountId: String,
    val tripId: String,
    val product: Product,
)

data class HealthResponse(
    val status: String,
)

data class AccountsResponse(
    val items: List<Account>,
)

data class TripsResponse(
    val items: List<Trip>,
    val nextCursor: String?,
)

data class PurchaseRequestsResponse(
    val items: List<PurchaseRequest>,
    val nextCursor: String?,
)

data class ApiErrorBody(
    val code: String? = null,
    val message: String? = null,
    val correlationId: String? = null,
)
