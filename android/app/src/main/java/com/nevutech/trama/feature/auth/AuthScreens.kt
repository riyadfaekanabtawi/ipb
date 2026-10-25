package com.nevutech.trama.feature.auth

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.nevutech.trama.R
import com.nevutech.trama.app.LocalApp
import com.nevutech.trama.core.data.AuthException
import com.nevutech.trama.core.data.DemoSeeder
import com.nevutech.trama.core.data.Session
import com.nevutech.trama.core.domain.Role
import com.nevutech.trama.designsystem.LoomBackdrop
import com.nevutech.trama.designsystem.PrimaryButton
import com.nevutech.trama.designsystem.Tokens
import kotlinx.coroutines.launch

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun LoginScreen() {
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    val demoSeeded by app.settings.demoSeeded.collectAsState(initial = false)
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    fun signIn(e: String = email, p: String = password) = scope.launch {
        runCatching { app.session.signIn(e, p) }.onFailure { error = (it as? AuthException)?.message ?: it.message }
    }

    AuthLayout {
        Text("Bienvenido de nuevo", style = MaterialTheme.typography.displaySmall)
        Text("Ingresa con tu correo de trabajo para continuar.", color = Tokens.colors.secondary)
        AuthField(email, { email = it; error = null }, "Correo electrónico", Icons.Filled.Email, KeyboardType.Email, ImeAction.Next)
        AuthField(password, { password = it; error = null }, "Contraseña", Icons.Filled.Lock, KeyboardType.Password, ImeAction.Go, secure = true, onGo = { signIn() })
        error?.let { Text(it, color = Tokens.colors.danger, style = MaterialTheme.typography.bodyMedium) }
        PrimaryButton("Entrar", { signIn() }, Modifier.fillMaxWidth(), icon = Icons.AutoMirrored.Filled.ArrowForward)
        CloudSignInButton()
        if (demoSeeded) {
            Text("Cuentas de demostración", style = MaterialTheme.typography.labelMedium, color = Tokens.colors.secondary)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf("admin" to Role.Admin, "cortes" to Role.CutManager, "planta" to Role.PlantManager, "envios" to Role.ShippingManager).forEach { (prefix, role) ->
                    Text(
                        role.title, color = Tokens.colors.brand, style = MaterialTheme.typography.labelMedium,
                        modifier = Modifier.clip(Tokens.chipShape).background(Tokens.colors.brand.copy(alpha = 0.1f))
                            .clickable { signIn("$prefix@demo.local", DemoSeeder.DEMO_PASSWORD) }.padding(horizontal = 12.dp, vertical = 8.dp),
                    )
                }
            }
        }
    }
}

@Composable
fun OnboardingScreen() {
    val app = LocalApp.current
    val scope = rememberCoroutineScope()
    var company by remember { mutableStateOf("") }
    var first by remember { mutableStateOf("") }
    var last by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    AuthLayout {
        Text("Configura Trama", style = MaterialTheme.typography.displaySmall)
        Text("Registra tu empresa y la cuenta de administrador de este dispositivo. Podrás agregar a tus gerentes después.", color = Tokens.colors.secondary)
        AuthField(company, { company = it }, "Nombre de tu empresa", Icons.Filled.Business)
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            AuthField(first, { first = it }, "Nombre", Icons.Filled.Person, modifier = Modifier.weight(1f))
            AuthField(last, { last = it }, "Apellido", Icons.Filled.Person, modifier = Modifier.weight(1f))
        }
        AuthField(email, { email = it }, "Correo electrónico", Icons.Filled.Email, KeyboardType.Email)
        AuthField(password, { password = it }, "Contraseña (mín. 6 caracteres)", Icons.Filled.Lock, KeyboardType.Password, secure = true)
        error?.let { Text(it, color = Tokens.colors.danger) }
        PrimaryButton("Crear administrador", {
            scope.launch {
                runCatching {
                    val user = Session.createUser(app.db.dao(), first, last, email, "", password, Role.Admin, null)
                    app.settings.setCompanyName(company)
                    app.session.adopt(user)
                    app.toasts.show("¡Listo, ${user.firstName}! Trama está configurado.")
                }.onFailure { error = it.message }
            }
        }, Modifier.fillMaxWidth(), icon = Icons.Filled.WorkspacePremium)
        Text("¿Tu empresa ya tiene licencia de Trama? Conecta este dispositivo para descargar sus datos.", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
        CloudSignInButton()
        Column(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Tokens.colors.thread.copy(alpha = 0.14f))
                .border(1.dp, Tokens.colors.thread.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
                .clickable {
                    scope.launch {
                        DemoSeeder.seed(app.db)
                        app.settings.setDemoSeeded(true)
                        app.settings.setCompanyName(DemoSeeder.DEMO_COMPANY)
                        app.db.dao().userByEmail("admin@demo.local")?.let { app.session.adopt(it) }
                        app.toasts.show("Datos de ejemplo cargados. Sesión iniciada como administrador.")
                    }
                }
                .padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Filled.AutoAwesome, null, tint = Tokens.colors.thread)
                Text("Explorar con datos de ejemplo", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(start = 8.dp))
            }
            Text("Plantas, clientes, cortes y reportes ficticios. Puedes borrarlos en Ajustes.", style = MaterialTheme.typography.bodySmall, color = Tokens.colors.secondary)
        }
    }
}

/** Split brand/form layout shared by login and onboarding (same as iOS AuthLayout). */
@Composable
private fun AuthLayout(content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize().background(Tokens.colors.canvas)) {
        val wide = maxWidth > 900.dp
        Row(Modifier.fillMaxSize()) {
            if (wide) BrandPanel(Modifier.weight(0.48f).fillMaxHeight(), compact = false)
            Column(
                Modifier.weight(0.52f).fillMaxHeight().verticalScroll(rememberScrollState()).imePadding().padding(horizontal = 32.dp, vertical = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            ) {
                if (!wide) BrandPanel(Modifier.fillMaxWidth().height(240.dp).clip(RoundedCornerShape(28.dp)), compact = true)
                Column(Modifier.widthIn(max = 440.dp).padding(top = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp), content = content)
            }
        }
    }
}

@Composable
private fun BrandPanel(modifier: Modifier, compact: Boolean) {
    val app = LocalApp.current
    val company by app.settings.companyName.collectAsState(initial = "")
    Box(modifier) {
        LoomBackdrop(Modifier.fillMaxSize())
        Column(Modifier.align(Alignment.BottomStart).padding(if (compact) 24.dp else 56.dp), verticalArrangement = Arrangement.spacedBy(if (compact) 8.dp else 14.dp)) {
            Image(painterResource(R.drawable.trama_mark), null, Modifier.size(if (compact) 60.dp else 92.dp).clip(RoundedCornerShape(if (compact) 16.dp else 24.dp)))
            Text("Trama", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = if (compact) 30.sp else 46.sp)
            Text(
                if (company.isBlank()) "Control de producción textil" else "Control de producción textil · $company",
                color = Tokens.colors.thread, fontWeight = FontWeight.SemiBold, fontSize = if (compact) 16.sp else 22.sp,
            )
            if (!compact) Text("Cortes, plantas y envíos en un solo tablero.\nFunciona sin conexión: tus datos viven en este dispositivo.", color = Color.White.copy(alpha = 0.8f), fontSize = 18.sp)
        }
    }
}

@Composable
private fun AuthField(
    value: String, onChange: (String) -> Unit, label: String, icon: ImageVector,
    keyboard: KeyboardType = KeyboardType.Text, ime: ImeAction = ImeAction.Next, secure: Boolean = false,
    onGo: () -> Unit = {}, modifier: Modifier = Modifier.fillMaxWidth(),
) {
    var reveal by remember { mutableStateOf(false) }
    OutlinedTextField(
        value, onChange, modifier, label = { Text(label) }, singleLine = true,
        leadingIcon = { Icon(icon, null, tint = Tokens.colors.brand) },
        trailingIcon = if (secure) { { IconButton({ reveal = !reveal }) { Icon(if (reveal) Icons.Filled.VisibilityOff else Icons.Filled.Visibility, if (reveal) "Ocultar contraseña" else "Mostrar contraseña") } } } else null,
        visualTransformation = if (secure && !reveal) PasswordVisualTransformation() else VisualTransformation.None,
        keyboardOptions = KeyboardOptions(keyboardType = keyboard, imeAction = ime),
        keyboardActions = KeyboardActions(onGo = { onGo() }),
        shape = RoundedCornerShape(16.dp),
        colors = OutlinedTextFieldDefaults.colors(unfocusedContainerColor = Tokens.colors.surface, focusedContainerColor = Tokens.colors.surface, unfocusedBorderColor = Tokens.colors.stroke),
    )
}
