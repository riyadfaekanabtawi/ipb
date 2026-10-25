package com.nevutech.trama.feature.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.material.icons.filled.CloudSync
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.core.l10n.L10n
import com.nevutech.trama.designsystem.Tokens
import kotlinx.coroutines.launch

/** "Conectar con mi licencia" entry point shown under the local sign-in and onboarding forms. */
@Composable
fun CloudSignInButton(modifier: Modifier = Modifier.fillMaxWidth()) {
    var open by remember { mutableStateOf(false) }
    OutlinedButton({ open = true }, modifier, shape = RoundedCornerShape(16.dp)) {
        Icon(Icons.Filled.Cloud, null, tint = Tokens.colors.brand, modifier = Modifier.size(18.dp))
        Text(stringResource(R.string.cloud_connect_licence), color = Tokens.colors.brand, modifier = Modifier.padding(start = 8.dp))
    }
    if (open) CloudSignInDialog(onDismiss = { open = false })
}

/**
 * Signs in to the Trama cloud with the licence's account. On success the device is linked to the
 * company, its data syncs and the user is signed in locally (later sign-ins also work offline).
 */
@Composable
fun CloudSignInDialog(onDismiss: () -> Unit, presetEmail: String = "") {
    val app = LocalApp.current
    var email by remember { mutableStateOf(presetEmail) }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    fun connect() {
        if (busy) return
        busy = true
        error = null
        // App scope: signing in swaps the root screen, which would cancel a composition scope mid-write.
        app.scope.launch {
            runCatching { app.sync.signIn(email, password) }
                .onSuccess { user ->
                    app.session.adopt(user)
                    val tenant = app.sync.status.value.account.tenantName
                    app.toasts.show(if (tenant != null) L10n.str(R.string.cloud_connected_to, tenant) else L10n.str(R.string.cloud_connected))
                    onDismiss()
                }
                .onFailure { error = it.message ?: L10n.str(R.string.cloud_connect_failed) }
            busy = false
        }
    }

    AlertDialog(
        onDismissRequest = { if (!busy) onDismiss() },
        icon = { Icon(Icons.Filled.CloudSync, null, tint = Tokens.colors.brand) },
        title = { Text(stringResource(R.string.cloud_connect_licence)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    stringResource(R.string.cloud_connect_explainer),
                    style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary,
                )
                OutlinedTextField(
                    email, { email = it; error = null }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.common_email)) }, singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email), shape = RoundedCornerShape(14.dp), enabled = !busy,
                )
                OutlinedTextField(
                    password, { password = it; error = null }, Modifier.fillMaxWidth(), label = { Text(stringResource(R.string.common_password)) }, singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password), shape = RoundedCornerShape(14.dp), enabled = !busy,
                )
                error?.let { Text(it, color = Tokens.colors.danger, style = MaterialTheme.typography.bodyMedium) }
                if (busy) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        CircularProgressIndicator(Modifier.size(18.dp), strokeWidth = 2.dp)
                        Text(stringResource(R.string.cloud_connecting), style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
                    }
                }
            }
        },
        confirmButton = { TextButton(::connect, enabled = !busy && email.isNotBlank() && password.isNotEmpty()) { Text(stringResource(R.string.cloud_connect)) } },
        dismissButton = { TextButton(onDismiss, enabled = !busy) { Text(stringResource(R.string.common_cancel)) } },
    )
}
