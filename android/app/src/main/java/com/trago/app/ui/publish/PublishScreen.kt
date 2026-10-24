package com.trago.app.ui.publish

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.trago.app.TragoApplication
import com.trago.app.ui.UiState
import com.trago.app.ui.components.MessageBox
import com.trago.app.ui.components.TragoTopBar
import com.trago.app.ui.format.formatMoney
import com.trago.app.ui.theme.BorderGray
import com.trago.app.ui.theme.Mint
import com.trago.app.ui.theme.Navy

@Composable
fun PublishScreen() {
    val app = LocalContext.current.applicationContext as TragoApplication
    val viewModel: PublishViewModel = viewModel { PublishViewModel(app.repository) }

    val state by viewModel.state.collectAsStateWithLifecycle()
    val form by viewModel.form.collectAsStateWithLifecycle()
    val submit by viewModel.submit.collectAsStateWithLifecycle()
    val validationError by viewModel.validationError.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize()) {
        TragoTopBar(title = "Publicar viagem", subtitle = "Oferta fictícia de viajante")

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    border = BorderStroke(1.dp, BorderGray),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                ) {
                    Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("Identidade do viajante", style = MaterialTheme.typography.titleMedium, color = Navy)
                        Text(
                            text = "Bearer: ${state.token.ifBlank { "(não definido)" }}",
                            style = MaterialTheme.typography.bodyMedium,
                        )
                        Text(
                            text = "Publicar exige o token de viajante (ex.: dev:traveler). Configure em Início → Configurar.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
            }

            item {
                OutlinedTextField(
                    value = form.origin,
                    onValueChange = viewModel::updateOrigin,
                    label = { Text("Origem") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = form.destination,
                    onValueChange = viewModel::updateDestination,
                    label = { Text("Destino") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = form.departureDate,
                    onValueChange = viewModel::updateDepartureDate,
                    label = { Text("Data (AAAA-MM-DD)") },
                    singleLine = true,
                    placeholder = { Text("ex.: 2026-12-25") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = form.timeZone,
                    onValueChange = viewModel::updateTimeZone,
                    label = { Text("Fuso horário") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = form.weightGrams,
                    onValueChange = viewModel::updateWeightGrams,
                    label = { Text("Capacidade (gramas)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    OutlinedTextField(
                        value = form.amount,
                        onValueChange = viewModel::updateAmount,
                        label = { Text("Tarifa por kg (centavos, inteiro)") },
                        singleLine = true,
                        placeholder = { Text("ex.: 4500 = 45,00") },
                        modifier = Modifier.weight(1f),
                    )
                    CurrencyToggle(
                        currency = form.currency,
                        onSelect = viewModel::updateCurrency,
                    )
                }
            }

            validationError?.let { message ->
                item {
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }

            item {
                Button(
                    onClick = viewModel::submit,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = submit !is UiState.Loading,
                ) {
                    Text(if (submit is UiState.Loading) "Publicando…" else "Publicar viagem")
                }
            }

            val submitState = submit
            when (submitState) {
                is UiState.Idle -> Unit
                is UiState.Loading -> item { MessageBox(title = "Publicando viagem…") }
                is UiState.Error -> item {
                    MessageBox(title = "Não foi possível publicar", subtitle = submitState.message)
                }
                is UiState.Success -> item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        border = BorderStroke(1.dp, Mint),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    ) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("Viagem publicada", style = MaterialTheme.typography.titleMedium, color = Mint)
                            Text("ID: ${submitState.data.id}", style = MaterialTheme.typography.bodyMedium)
                            Text("Viajante: ${submitState.data.travelerName}", style = MaterialTheme.typography.bodyMedium)
                            Text(
                                text = "${submitState.data.origin} → ${submitState.data.destination} · ${submitState.data.departureDate}",
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            Text(
                                text = "Tarifa ${formatMoney(submitState.data.pricePerKg)}/kg · ${submitState.data.availableWeightGrams} g",
                                style = MaterialTheme.typography.bodyMedium,
                            )
                            Text(
                                text = "Oferta fictícia — visível na busca de viagens.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CurrencyToggle(currency: String, onSelect: (String) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
        listOf("USD", "BRL").forEach { code ->
            val selected = code == currency
            if (selected) {
                Button(
                    onClick = { onSelect(code) },
                    colors = ButtonDefaults.buttonColors(containerColor = Navy),
                ) { Text(code) }
            } else {
                OutlinedButton(onClick = { onSelect(code) }) { Text(code) }
            }
        }
    }
}
