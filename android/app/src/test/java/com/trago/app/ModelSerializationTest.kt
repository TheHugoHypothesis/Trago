package com.trago.app

import com.google.gson.Gson
import com.trago.app.data.model.Account
import com.trago.app.data.model.ApiErrorBody
import com.trago.app.data.model.PurchaseRequest
import com.trago.app.data.model.Trip
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Valida o mapeamento dos DTOs Kotlin contra o formato real do contrato
 * congelado (`contracts/http/openapi.json`) e das respostas da API de preview.
 * Em especial: `Money.amount` é string de inteiros (centavos) e `isDemo`/
 * `taxId` opcional desserializam corretamente.
 */
class ModelSerializationTest {

    private val gson = Gson()

    @Test
    fun `Trip desserializa isDemo e money como string de centavos`() {
        val json = """
            {"id":"trip-ny-sp","isDemo":true,"origin":"Nova York (EUA)",
             "timeZone":"America/Sao_Paulo","pricePerKg":{"amount":"4500","currency":"USD"},
             "destination":"São Paulo (SP)","travelerName":"Ana C. (exemplo)",
             "departureDate":"2026-12-15","availableWeightGrams":8000}
        """.trimIndent()

        val trip = gson.fromJson(json, Trip::class.java)

        assertEquals("trip-ny-sp", trip.id)
        assertTrue(trip.isDemo)
        assertEquals("4500", trip.pricePerKg.amount)
        assertEquals("USD", trip.pricePerKg.currency)
        assertEquals(8000, trip.availableWeightGrams)
    }

    @Test
    fun `Account desserializa taxId opcional e tipo PF ou PJ`() {
        val org = gson.fromJson(
            """{"id":"company-demo","type":"ORGANIZATION","taxId":"12.ABC.345/01DE-35","displayName":"Empresa"}""",
            Account::class.java,
        )
        assertEquals("12.ABC.345/01DE-35", org.taxId)
        assertTrue(org.isOrganization)

        val personal = gson.fromJson(
            """{"id":"personal-buyer","type":"PERSONAL","displayName":"Minha conta"}""",
            Account::class.java,
        )
        assertNull(personal.taxId)
        assertEquals("PERSONAL", personal.type)
    }

    @Test
    fun `PurchaseRequest e Error desserializam campos do contrato`() {
        val request = gson.fromJson(
            """{"id":"req-1","accountId":"personal-buyer","tripId":"trip-ny-sp",
               "product":{"description":"Fone","url":"https://example.com",
               "price":{"amount":"30050","currency":"BRL"},"estimatedWeightGrams":800},
               "status":"DRAFT","createdAt":"2026-10-19T02:36:09.712Z"}""",
            PurchaseRequest::class.java,
        )
        assertEquals("30050", request.product.price.amount)
        assertEquals("BRL", request.product.price.currency)
        assertEquals("DRAFT", request.status)

        val error = gson.fromJson(
            """{"code":"FORBIDDEN","message":"Operação indisponível","correlationId":"abc"}""",
            ApiErrorBody::class.java,
        )
        assertEquals("FORBIDDEN", error.code)
        assertEquals("Operação indisponível", error.message)
        assertEquals("abc", error.correlationId)
    }
}
