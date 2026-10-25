package com.nevutech.trama.feature.orders

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun OrdersScreen() {
    TramaScreen { EmptyState("Cortes por asignar", "En construcción", Icons.Filled.Construction) }
}
