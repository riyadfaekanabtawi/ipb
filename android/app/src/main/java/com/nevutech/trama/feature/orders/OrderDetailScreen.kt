package com.nevutech.trama.feature.orders

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun OrderDetailScreen(id: String) {
    TramaScreen { EmptyState("Corte", "En construcción", Icons.Filled.Construction) }
}
