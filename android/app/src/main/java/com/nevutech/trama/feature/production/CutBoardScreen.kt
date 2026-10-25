package com.nevutech.trama.feature.production

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun CutBoardScreen() {
    TramaScreen { EmptyState("Tablero de corte", "En construcción", Icons.Filled.Construction) }
}
