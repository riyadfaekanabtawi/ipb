package com.nevutech.trama.feature.plants

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Construction
import androidx.compose.runtime.Composable
import com.nevutech.trama.designsystem.EmptyState
import com.nevutech.trama.designsystem.TramaScreen

@Composable
fun PlantCalendarScreen() {
    TramaScreen { EmptyState("Calendario de plantas", "En construcción", Icons.Filled.Construction) }
}
