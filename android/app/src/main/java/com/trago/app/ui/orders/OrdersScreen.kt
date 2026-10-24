package com.trago.app.ui.orders

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
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
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
import com.trago.app.data.model.PurchaseRequest
import com.trago.app.ui.UiState
import com.trago.app.ui.components.MessageBox
import com.trago.app.ui.components.TragoTopBar
import com.trago.app.ui.format.formatMoney
import com.trago.app.ui.theme.BorderGray
import com.trago.app.ui.theme.Mint
import com.trago.app.ui.theme.Navy

@Composable
fun OrdersScreen() {
    val app = LocalContext.current.applicationContext as TragoApplication
    val viewModel: OrdersViewModel = viewModel { OrdersViewModel(app.repository) }

    val state by viewModel.state.collectAsStateWithLifecycle()
    val orders by viewModel.orders.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize()) {
        TragoTopBar(
            title = "Pedidos",
            subtitle = state.selectedAccount?.displayName ?: "Nenhuma conta selecionada",
            actions = {
                IconButton(onClick = { viewModel.refresh() }) {
                    Icon(
                        imageVector = Icons.Filled.Refresh,
                        contentDescription = "Atualizar",
                        tint = Color.White,
                    )
                }
            },
        )

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            when (val ordersState = orders) {
                is UiState.Loading -> item { MessageBox(title = "Carregando pedidos…") }
                is UiState.Error -> item {
                    MessageBox(title = "Pedidos indisponíveis", subtitle = ordersState.message)
                }
                is UiState.Success -> {
                    if (ordersState.data.isEmpty()) {
                        item {
                            MessageBox(
                                title = "Nenhum pedido neste contexto",
                                subtitle = "Rascunhos criados aparecem aqui, isolados por conta PF/PJ.",
                            )
                        }
                    } else {
                        items(ordersState.data, key = { it.id }) { request ->
                            RequestCard(request)
                        }
                    }
                }
                is UiState.Idle -> Unit
            }
        }
    }
}

@Composable
private fun RequestCard(request: PurchaseRequest) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        border = BorderStroke(1.dp, BorderGray),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = request.status,
                    style = MaterialTheme.typography.labelLarge,
                    color = Mint,
                )
                Spacer(Modifier.width(12.dp))
                Text(
                    text = request.createdAt,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                text = request.product.description,
                style = MaterialTheme.typography.titleMedium,
                color = Navy,
            )
            Text(
                text = "${formatMoney(request.product.price)} · ${request.product.estimatedWeightGrams} g",
                style = MaterialTheme.typography.bodyMedium,
            )
            if (request.product.url != null) {
                Text(
                    text = request.product.url,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}
