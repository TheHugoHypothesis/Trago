package com.trago.app.ui.search

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
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
import com.trago.app.data.model.Trip
import com.trago.app.ui.UiState
import com.trago.app.ui.components.DemoPill
import com.trago.app.ui.components.MessageBox
import com.trago.app.ui.components.TragoTopBar
import com.trago.app.ui.format.formatMoney
import com.trago.app.ui.theme.BorderGray
import com.trago.app.ui.theme.Mint
import com.trago.app.ui.theme.Navy

@Composable
fun SearchScreen() {
    val app = LocalContext.current.applicationContext as TragoApplication
    val viewModel: SearchViewModel = viewModel { SearchViewModel(app.repository) }

    val query by viewModel.query.collectAsStateWithLifecycle()
    val results by viewModel.results.collectAsStateWithLifecycle()
    val nextCursor by viewModel.nextCursor.collectAsStateWithLifecycle()
    val loadingMore by viewModel.loadingMore.collectAsStateWithLifecycle()
    val loadMoreError by viewModel.loadMoreError.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize()) {
        TragoTopBar(title = "Buscar viagens", subtitle = "Ofertas fictícias de viajantes")

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                OutlinedTextField(
                    value = query.origin,
                    onValueChange = viewModel::updateOrigin,
                    label = { Text("Origem") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = query.destination,
                    onValueChange = viewModel::updateDestination,
                    label = { Text("Destino") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                OutlinedTextField(
                    value = query.departureDate,
                    onValueChange = viewModel::updateDepartureDate,
                    label = { Text("Data (AAAA-MM-DD)") },
                    singleLine = true,
                    placeholder = { Text("ex.: 2026-12-15") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item {
                Button(
                    onClick = viewModel::search,
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Buscar") }
            }

            when (val state = results) {
                is UiState.Idle -> item {
                    MessageBox(
                        title = "Busque por rota ou data",
                        subtitle = "Use pelo menos um filtro para listar viagens compatíveis.",
                    )
                }
                is UiState.Loading -> item { MessageBox(title = "Buscando viagens…") }
                is UiState.Error -> item {
                    MessageBox(title = "Falha na busca", subtitle = state.message)
                }
                is UiState.Success -> {
                    if (state.data.items.isEmpty()) {
                        item {
                            MessageBox(
                                title = "Nenhuma viagem encontrada",
                                subtitle = "Tente outra rota ou data.",
                            )
                        }
                    } else {
                        items(state.data.items, key = { it.id }) { trip ->
                            TripCard(
                                trip = trip,
                                onDraft = { viewModel.chooseTrip(trip) },
                            )
                        }
                    }
                    if (nextCursor != null) {
                        item {
                            OutlinedButton(
                                onClick = viewModel::loadMore,
                                enabled = !loadingMore,
                                modifier = Modifier.fillMaxWidth(),
                            ) {
                                Text(if (loadingMore) "Carregando…" else "Carregar mais")
                            }
                        }
                    }
                    loadMoreError?.let { message ->
                        item {
                            Text(
                                text = message,
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TripCard(trip: Trip, onDraft: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        border = BorderStroke(1.dp, BorderGray),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                DemoPill(text = "exemplo")
                Text(
                    text = trip.travelerName,
                    style = MaterialTheme.typography.titleMedium,
                    color = Navy,
                )
            }
            Text(
                text = "${trip.origin} → ${trip.destination}",
                style = MaterialTheme.typography.titleLarge,
            )
            Text(
                text = "Data: ${trip.departureDate} · Fuso: ${trip.timeZone}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "Capacidade: ${trip.availableWeightGrams} g",
                    style = MaterialTheme.typography.bodyMedium,
                )
                Spacer(Modifier.width(16.dp))
                Text(
                    text = "${formatMoney(trip.pricePerKg)}/kg",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Mint,
                )
            }
            Button(
                onClick = onDraft,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Criar rascunho") }
        }
    }
}
