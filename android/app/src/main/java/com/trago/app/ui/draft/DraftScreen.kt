package com.trago.app.ui.draft

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.trago.app.TragoApplication
import com.trago.app.ui.UiState
import com.trago.app.ui.components.AccountTypeBadge
import com.trago.app.ui.components.MessageBox
import com.trago.app.ui.components.TragoTopBar
import com.trago.app.ui.theme.BorderGray
import com.trago.app.ui.theme.Mint
import com.trago.app.ui.theme.Navy

@Composable
fun DraftScreen() {
    val app = LocalContext.current.applicationContext as TragoApplication
    val viewModel: DraftViewModel = viewModel { DraftViewModel(app.repository) }

    val state by viewModel.state.collectAsStateWithLifecycle()
    val form by viewModel.form.collectAsStateWithLifecycle()
    val submit by viewModel.submit.collectAsStateWithLifecycle()
    val validationError by viewModel.validationError.collectAsStateWithLifecycle()

    val account = state.selectedAccount
    val trip = state.selectedTrip

    Column(modifier = Modifier.fillMaxSize()) {
        TragoTopBar(title = "Novo rascunho", subtitle = "Solicitação privada (DRAFT)")

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { ContextCard(account = account, trip = trip) }

            item {
                OutlinedTextField(
                    value = form.description,
                    onValueChange = viewModel::updateDescription,
                    label = { Text("Descrição do produto") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = form.url,
                    onValueChange = viewModel::updateUrl,
                    label = { Text("Link do produto (opcional)") },
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
                        label = { Text("Valor (centavos, inteiro)") },
                        singleLine = true,
                        placeholder = { Text("ex.: 30050 = 300,50") },
                        modifier = Modifier.weight(1f),
                    )
                    CurrencyToggle(
                        currency = form.currency,
                        onSelect = viewModel::updateCurrency,
                    )
                }
            }
            item {
                OutlinedTextField(
                    value = form.weightGrams,
                    onValueChange = viewModel::updateWeightGrams,
                    label = { Text("Peso estimado (gramas)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
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
                    Text(if (submit is UiState.Loading) "Salvando…" else "Salvar rascunho")
                }
            }

            val submitState = submit
            when (submitState) {
                is UiState.Idle -> Unit
                is UiState.Loading -> item { MessageBox(title = "Salvando rascunho…") }
                is UiState.Error -> item {
                    MessageBox(title = "Não foi possível salvar", subtitle = submitState.message)
                }
                is UiState.Success -> item {
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        border = BorderStroke(1.dp, Mint),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                    ) {
                        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text("Rascunho criado", style = MaterialTheme.typography.titleMedium, color = Mint)
                            Text("ID: ${submitState.data.id}", style = MaterialTheme.typography.bodyMedium)
                            Text("Status: ${submitState.data.status}", style = MaterialTheme.typography.bodyMedium)
                            Text(
                                text = "Rascunho privado — não visível ao viajante.",
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
private fun ContextCard(account: com.trago.app.data.model.Account?, trip: com.trago.app.data.model.Trip?) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        border = BorderStroke(1.dp, BorderGray),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("Contexto da solicitação", style = MaterialTheme.typography.titleMedium, color = Navy)
            if (account != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Conta: ${account.displayName}", style = MaterialTheme.typography.bodyMedium)
                    AccountTypeBadge(isOrganization = account.isOrganization)
                }
            } else {
                Text(
                    "Nenhuma conta selecionada — escolha em Início.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                )
            }
            if (trip != null) {
                Text(
                    "Viagem: ${trip.origin} → ${trip.destination} · ${trip.departureDate}",
                    style = MaterialTheme.typography.bodyMedium,
                )
            } else {
                Text(
                    "Nenhuma viagem selecionada — escolha em Buscar.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
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
