package com.trago.app.ui.home

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
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
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.RadioButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.trago.app.TragoApplication
import com.trago.app.data.model.Account
import com.trago.app.ui.UiState
import com.trago.app.ui.components.AccountTypeBadge
import com.trago.app.ui.components.DemoPill
import com.trago.app.ui.components.MessageBox
import com.trago.app.ui.components.TragoTopBar
import com.trago.app.ui.theme.BorderGray
import com.trago.app.ui.theme.Mint
import com.trago.app.ui.theme.Navy

@Composable
fun HomeScreen() {
    val app = LocalContext.current.applicationContext as TragoApplication
    val viewModel: HomeViewModel = viewModel { HomeViewModel(app.repository) }

    val state by viewModel.state.collectAsStateWithLifecycle()
    val health by viewModel.health.collectAsStateWithLifecycle()
    val accounts by viewModel.accounts.collectAsStateWithLifecycle()

    var showSettings by remember { mutableStateOf(false) }

    Column(modifier = Modifier.fillMaxSize()) {
        TragoTopBar(
            title = "Trago",
            subtitle = "MVP local — dados sintéticos",
            actions = {
                TextButton(onClick = { showSettings = true }) {
                    Text("Configurar", color = Color.White)
                }
            },
        )

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                ConnectionCard(
                    baseUrl = state.baseUrl,
                    token = state.token,
                    health = health,
                )
            }

            item {
                Text(
                    text = "Contexto (PF/PJ)",
                    style = MaterialTheme.typography.titleMedium,
                    color = Navy,
                )
                Text(
                    text = "Escolha a conta que será dona das solicitações privadas.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            when (val accountsState = accounts) {
                is UiState.Loading -> item { MessageBox(title = "Carregando contas…") }
                is UiState.Error -> {
                    item {
                        MessageBox(
                            title = "Não foi possível carregar as contas",
                            subtitle = accountsState.message,
                        )
                    }
                    item {
                        Button(
                            onClick = { viewModel.refresh() },
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("Tentar novamente") }
                    }
                }
                is UiState.Success -> items(accountsState.data, key = { it.id }) { account ->
                    AccountRow(
                        account = account,
                        selected = account.id == state.selectedAccountId,
                        onClick = { viewModel.selectAccount(account.id) },
                    )
                }
                is UiState.Idle -> Unit
            }
        }
    }

    if (showSettings) {
        SettingsDialog(
            baseUrl = state.baseUrl,
            token = state.token,
            onDismiss = { showSettings = false },
            onApply = { baseUrl, token ->
                viewModel.applyConnection(baseUrl, token)
                showSettings = false
            },
        )
    }
}

@Composable
private fun ConnectionCard(
    baseUrl: String,
    token: String,
    health: UiState<Boolean>,
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, BorderGray),
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                DemoPill(text = "demonstração")
                Spacer(Modifier.width(8.dp))
                Text(
                    text = when (health) {
                        is UiState.Success -> if (health.data) "API conectada" else "API respondeu fora do esperado"
                        is UiState.Error -> "API indisponível"
                        else -> "Verificando API…"
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    color = when (health) {
                        is UiState.Success -> if (health.data) Mint else MaterialTheme.colorScheme.error
                        is UiState.Error -> MaterialTheme.colorScheme.error
                        else -> MaterialTheme.colorScheme.onSurfaceVariant
                    },
                )
            }
            HorizontalDivider(color = BorderGray)
            Text("API base", style = MaterialTheme.typography.labelLarge)
            Text(baseUrl, style = MaterialTheme.typography.bodyMedium)
            Text("Identidade demo (Bearer)", style = MaterialTheme.typography.labelLarge)
            Text(token, style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun AccountRow(
    account: Account,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(
            containerColor = if (selected) Navy else MaterialTheme.colorScheme.surface,
        ),
        border = if (selected) null else BorderStroke(1.dp, BorderGray),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            RadioButton(
                selected = selected,
                onClick = onClick,
                colors = RadioButtonDefaults.colors(
                    selectedColor = MaterialTheme.colorScheme.primary,
                    unselectedColor = MaterialTheme.colorScheme.onSurfaceVariant,
                ),
            )
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = account.displayName,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = if (selected) Color.White else MaterialTheme.colorScheme.onSurface,
                    )
                    AccountTypeBadge(isOrganization = account.isOrganization)
                }
                if (account.taxId != null) {
                    Text(
                        text = if (account.isOrganization) "CNPJ ${account.taxId}" else "CPF ${account.taxId}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = if (selected) Color(0xFFB9C4D6) else MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsDialog(
    baseUrl: String,
    token: String,
    onDismiss: () -> Unit,
    onApply: (String, String) -> Unit,
) {
    var baseUrlValue by remember(baseUrl) { mutableStateOf(baseUrl) }
    var tokenValue by remember(token) { mutableStateOf(token) }

    Dialog(onDismissRequest = onDismiss) {
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Configuração da conexão", style = MaterialTheme.typography.titleLarge, color = Navy)
                OutlinedTextField(
                    value = baseUrlValue,
                    onValueChange = { baseUrlValue = it },
                    label = { Text("URL base da API") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = tokenValue,
                    onValueChange = { tokenValue = it },
                    label = { Text("Token demo (Bearer)") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    text = "Somente dados sintéticos. Nenhum pagamento ou importação real.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                    TextButton(onClick = onDismiss) { Text("Cancelar") }
                    Spacer(Modifier.width(8.dp))
                    Button(onClick = { onApply(baseUrlValue, tokenValue) }) { Text("Aplicar") }
                }
            }
        }
    }
}
