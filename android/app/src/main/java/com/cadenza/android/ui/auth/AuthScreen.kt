package com.cadenza.android.ui.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.theme.CadenzaAccent

@Composable
fun AuthScreen(
    session: SessionViewModel,
    onBack: () -> Unit,
) {
    val loc = AppLocale

    var isSignUp by remember { mutableStateOf(true) }
    var name by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var errorText by remember { mutableStateOf<String?>(null) }
    var emailBusy by remember { mutableStateOf(false) }
    var googleBusy by remember { mutableStateOf(false) }

    val headingSignUp = loc.localized("계정을\n만들어보세요", "Create your\nAccount", "Konto\nerstellen")
    val headingSignIn = loc.localized("다시\n만났네요", "Sign in to your\nAccount", "Wieder\nda?")
    val subtitleSignUp = loc.localized("음악 커리어의 여정을 함께 기록해요.", "Start recording your music career.", "Dokumentiere deine Musikkarriere.")
    val subtitleSignIn = loc.localized("다시 돌아오셨군요, 반갑습니다.", "Welcome back.", "Willkommen zurück.")
    val tabSignUp = loc.localized("계정 만들기", "Sign Up", "Registrieren")
    val tabSignIn = loc.localized("로그인", "Log In", "Anmelden")
    val ctaSignUp = loc.localized("시작하기", "Get Started", "Loslegen")
    val ctaSignIn = loc.localized("로그인", "Log In", "Anmelden")
    val dividerOr = loc.localized("또는", "or", "oder")
    val googleLabel = loc.localized("Google로 계속하기", "Continue with Google", "Mit Google fortfahren")
    val forgotPassword = loc.localized("비밀번호를 잊으셨나요?", "Forgot password?", "Passwort vergessen?")

    val isValid = email.contains("@") && email.length >= 5 && password.length >= 6 &&
        (!isSignUp || name.trim().length >= 2)

    val fieldContainerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.surface)
            .verticalScroll(rememberScrollState())
            .padding(bottom = 48.dp)
    ) {
        // Back button (iOS circle style)
        Box(
            modifier = Modifier
                .padding(start = 20.dp, top = 16.dp)
                .size(36.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.surfaceVariant),
            contentAlignment = Alignment.Center,
        ) {
            IconButton(onClick = onBack, modifier = Modifier.size(36.dp)) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "back",
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.onSurface,
                )
            }
        }

        // Heading
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = 20.dp, bottom = 36.dp)
        ) {
            Text(
                if (isSignUp) headingSignUp else headingSignIn,
                style = MaterialTheme.typography.headlineLarge.copy(lineHeight = 38.sp),
                color = MaterialTheme.colorScheme.onBackground,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                if (isSignUp) subtitleSignUp else subtitleSignIn,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // Mode tabs (iOS underline style)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp),
        ) {
            AuthModeTab(
                label = tabSignUp,
                active = isSignUp,
                onClick = { isSignUp = true; errorText = null },
                modifier = Modifier.weight(1f),
            )
            AuthModeTab(
                label = tabSignIn,
                active = !isSignUp,
                onClick = { isSignUp = false; errorText = null },
                modifier = Modifier.weight(1f),
            )
        }

        Spacer(Modifier.height(22.dp))

        // Fields card (iOS style: single rounded rect, rows separated by Divider)
        Column(
            modifier = Modifier
                .padding(horizontal = 22.dp)
                .clip(RoundedCornerShape(16.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)),
        ) {
            AnimatedVisibility(visible = isSignUp) {
                Column {
                    FieldRow(
                        icon = Icons.Default.Person,
                        value = name,
                        onValueChange = { name = it },
                        placeholder = loc.localized("이름", "Name", "Name"),
                        keyboardOptions = KeyboardOptions(
                            capitalization = KeyboardCapitalization.Words,
                        ),
                        fieldContainerColor = Color.Transparent,
                    )
                    HorizontalDivider(
                        modifier = Modifier.padding(start = 44.dp),
                        color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f),
                    )
                }
            }

            FieldRow(
                icon = Icons.Default.Email,
                value = email,
                onValueChange = { email = it },
                placeholder = loc.localized("이메일", "Email", "E-Mail"),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    capitalization = KeyboardCapitalization.None,
                ),
                fieldContainerColor = Color.Transparent,
            )

            HorizontalDivider(
                modifier = Modifier.padding(start = 44.dp),
                color = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f),
            )

            PasswordFieldRow(
                value = password,
                onValueChange = { password = it },
                placeholder = if (isSignUp)
                    loc.localized("비밀번호 (6자 이상)", "Password (6+ chars)", "Passwort (mind. 6)")
                else
                    loc.localized("비밀번호", "Password", "Passwort"),
                showPassword = showPassword,
                onTogglePassword = { showPassword = !showPassword },
                fieldContainerColor = Color.Transparent,
            )
        }

        // Forgot password
        AnimatedVisibility(visible = !isSignUp) {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
                TextButton(
                    onClick = {},
                    modifier = Modifier.padding(end = 12.dp),
                ) {
                    Text(
                        forgotPassword,
                        style = MaterialTheme.typography.bodySmall,
                        color = CadenzaAccent,
                    )
                }
            }
        }

        // Error text
        AnimatedVisibility(visible = errorText != null) {
            Text(
                errorText ?: "",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 6.dp),
            )
        }

        Spacer(Modifier.height(20.dp))

        // Primary CTA button
        Surface(
            onClick = {
                if (!emailBusy && !googleBusy && isValid) {
                    emailBusy = true; errorText = null
                    if (isSignUp) {
                        session.signUp(name, email, password) { errorText = it; emailBusy = false }
                    } else {
                        session.signIn(email, password) { errorText = it; emailBusy = false }
                    }
                }
            },
            shape = RoundedCornerShape(14.dp),
            color = if (isValid) CadenzaAccent else CadenzaAccent.copy(alpha = 0.3f),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp)
                .height(52.dp),
        ) {
            Box(contentAlignment = Alignment.Center, modifier = Modifier.fillMaxSize()) {
                if (emailBusy) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = Color.White,
                        strokeWidth = 2.dp,
                    )
                } else {
                    Text(
                        if (isSignUp) ctaSignUp else ctaSignIn,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                    )
                }
            }
        }

        // Divider "or"
        Row(
            modifier = Modifier.padding(horizontal = 22.dp, vertical = 26.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            HorizontalDivider(
                modifier = Modifier.weight(1f),
                color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f),
            )
            Text(
                dividerOr,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 12.dp),
            )
            HorizontalDivider(
                modifier = Modifier.weight(1f),
                color = MaterialTheme.colorScheme.outline.copy(alpha = 0.3f),
            )
        }

        // Google button
        Surface(
            onClick = {
                if (!emailBusy && !googleBusy) {
                    googleBusy = true
                    errorText = null
                    session.signInWithGoogle(
                        onLaunched = { googleBusy = false },
                        onError = {
                            errorText = it
                            googleBusy = false
                        },
                    )
                }
            },
            shape = RoundedCornerShape(14.dp),
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp)
                .height(50.dp),
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.fillMaxSize(),
            ) {
                if (googleBusy) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        color = CadenzaAccent,
                        strokeWidth = 2.dp,
                    )
                } else {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.Center,
                    ) {
                        Text(
                            "G",
                            color = CadenzaAccent,
                            fontWeight = FontWeight.ExtraBold,
                            fontSize = 16.sp,
                            modifier = Modifier.padding(end = 8.dp),
                        )
                        Text(
                            googleLabel,
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun AuthModeTab(
    label: String,
    active: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val textColor by animateColorAsState(
        if (active) CadenzaAccent else MaterialTheme.colorScheme.onSurfaceVariant,
        label = "tabColor",
    )
    val indicatorColor by animateColorAsState(
        if (active) CadenzaAccent else Color.Transparent,
        label = "indicatorColor",
    )

    Surface(
        onClick = onClick,
        color = Color.Transparent,
        modifier = modifier,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                label,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontWeight = if (active) FontWeight.SemiBold else FontWeight.Normal,
                ),
                color = textColor,
                modifier = Modifier.padding(vertical = 8.dp),
            )
            // Underline indicator
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(2.dp)
                    .clip(RoundedCornerShape(1.dp))
                    .background(indicatorColor),
            )
        }
    }
}

@Composable
private fun FieldRow(
    icon: ImageVector,
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    fieldContainerColor: Color,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .padding(start = 16.dp)
                .size(18.dp),
        )
        TextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, style = MaterialTheme.typography.bodyMedium) },
            singleLine = true,
            keyboardOptions = keyboardOptions,
            modifier = Modifier.weight(1f),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = fieldContainerColor,
                unfocusedContainerColor = fieldContainerColor,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                focusedTextColor = MaterialTheme.colorScheme.onSurface,
                unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
            ),
        )
    }
}

@Composable
private fun PasswordFieldRow(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    showPassword: Boolean,
    onTogglePassword: () -> Unit,
    fieldContainerColor: Color,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            Icons.Default.Lock,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .padding(start = 16.dp)
                .size(18.dp),
        )
        TextField(
            value = value,
            onValueChange = onValueChange,
            placeholder = { Text(placeholder, style = MaterialTheme.typography.bodyMedium) },
            singleLine = true,
            visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            modifier = Modifier.weight(1f),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = fieldContainerColor,
                unfocusedContainerColor = fieldContainerColor,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                focusedTextColor = MaterialTheme.colorScheme.onSurface,
                unfocusedTextColor = MaterialTheme.colorScheme.onSurface,
            ),
            trailingIcon = {
                IconButton(onClick = onTogglePassword, modifier = Modifier.padding(end = 4.dp)) {
                    Icon(
                        if (showPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(18.dp),
                    )
                }
            },
        )
    }
}
