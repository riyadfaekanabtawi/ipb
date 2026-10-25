package com.nevutech.trama.feature.styles

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun StylesScreen() {
    TramaScreen { EmptyState("Estilos", "En construcción", Icons.Filled.Construction) }
}
