package com.trago.app.ui.format

import com.trago.app.data.model.Money

/**
 * Formatação de dinheiro do contrato congelado.
 *
 * O contrato representa `Money.amount` como **string de inteiros em unidades
 * menores** (centavos/centésimos), sem ponto decimal. Esta função converte para
 * unidades maiores com duas casas, deixando o mapeamento explícito e sem
 * multiplicação silenciosa de decimais:
 *
 * - `"4500"`  → `USD 45.00`
 * - `"30050"` → `USD 300.50` (R$ 300,50 = 30050 centavos)
 * - `"5"`     → `USD 0.05`
 *
 * Valores que não seguem o padrão `^[0-9]+$` são rejeitados na entrada
 * (ViewModels de formulário) antes de chegarem aqui.
 */
fun formatMoney(money: Money): String {
    val amount = money.amount
    val major = when {
        amount.length <= 2 -> "0.${amount.padStart(2, '0')}"
        else -> amount.dropLast(2) + "." + amount.takeLast(2)
    }
    return "${money.currency} $major"
}
