package com.trago.app.ui.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Search
import androidx.compose.ui.graphics.vector.ImageVector

enum class Destination(
    val route: String,
    val label: String,
    val icon: ImageVector,
) {
    HOME("home", "Início", Icons.Filled.Home),
    SEARCH("search", "Buscar", Icons.Filled.Search),
    PUBLISH("publish", "Publicar", Icons.Filled.Add),
    DRAFT("draft", "Rascunho", Icons.Filled.Edit),
    ORDERS("orders", "Pedidos", Icons.AutoMirrored.Filled.List),
}
