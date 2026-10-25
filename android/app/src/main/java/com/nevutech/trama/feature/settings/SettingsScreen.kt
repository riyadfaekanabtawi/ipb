package com.nevutech.trama.feature.settings

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun SettingsScreen() {
    TramaScreen { EmptyState("Ajustes", "En construcción", Icons.Filled.Construction) }
}
