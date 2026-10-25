package com.nevutech.trama.feature.styles

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun StyleDetailScreen(id: String) {
    TramaScreen { EmptyState("Estilo", "En construcción", Icons.Filled.Construction) }
}
