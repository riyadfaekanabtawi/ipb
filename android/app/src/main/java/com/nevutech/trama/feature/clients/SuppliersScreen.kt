package com.nevutech.trama.feature.clients

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun SuppliersScreen() {
    TramaScreen { EmptyState("Proveedores", "En construcción", Icons.Filled.Construction) }
}
