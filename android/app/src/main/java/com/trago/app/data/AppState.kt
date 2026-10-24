package com.trago.app.data

import com.trago.app.data.model.Account
import com.trago.app.data.model.Trip

/**
 * Estado compartilhado do aplicativo (sessão demo + contexto selecionado).
 * A troca de conta limpa o rascunho/viagem selecionada para não vazar dados
 * privados entre contextos PF/PJ (AC-06).
 */
data class AppState(
    val baseUrl: String = "",
    val token: String = "",
    val accounts: List<Account> = emptyList(),
    val selectedAccountId: String? = null,
    val selectedTrip: Trip? = null,
) {
    val selectedAccount: Account?
        get() = accounts.firstOrNull { it.id == selectedAccountId }

    /** Identidade da sessão (URL + token). Trocar sessão deve limpar estados. */
    val sessionKey: String get() = "$baseUrl|$token"

    /** Contexto privado (sessão + conta + viagem selecionada). */
    val contextKey: String
        get() = "$baseUrl|$token|$selectedAccountId|${selectedTrip?.id}"
}
