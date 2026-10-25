package com.nevutech.trama.feature.shipments

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun UrgentShipmentsScreen() {
    TramaScreen { EmptyState("Envíos urgentes", "En construcción", Icons.Filled.Construction) }
}
