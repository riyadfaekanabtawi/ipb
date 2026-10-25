package com.nevutech.trama.app

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ViewList
import androidx.compose.material.icons.filled.Apartment
import androidx.compose.material.icons.filled.Calculate
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ContentCut
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.ManageAccounts
import androidx.compose.material.icons.filled.Checkroom
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.ViewKanban
import androidx.compose.material.icons.filled.Warning
import androidx.compose.ui.graphics.vector.ImageVector
import com.nevutech.trama.core.domain.AppSection

val AppSection.icon: ImageVector
    get() = when (this) {
        AppSection.Dashboard -> Icons.Filled.Dashboard
        AppSection.Orders -> Icons.Filled.ContentCut
        AppSection.Board -> Icons.Filled.ViewKanban
        AppSection.Production -> Icons.AutoMirrored.Filled.ViewList
        AppSection.Shipments -> Icons.Filled.Warning
        AppSection.Calendar -> Icons.Filled.CalendarMonth
        AppSection.Plants -> Icons.Filled.Apartment
        AppSection.Clients -> Icons.Filled.Groups
        AppSection.Suppliers -> Icons.Filled.LocalShipping
        AppSection.Styles -> Icons.Filled.Checkroom
        AppSection.Projects -> Icons.Filled.Folder
        AppSection.Users -> Icons.Filled.ManageAccounts
        AppSection.Calculator -> Icons.Filled.Calculate
        AppSection.Settings -> Icons.Filled.Settings
    }
