package com.nevutech.trama.feature.reports

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun ProductionReportsScreen() {
    TramaScreen { EmptyState("Reportes de producción", "En construcción", Icons.Filled.Construction) }
}
