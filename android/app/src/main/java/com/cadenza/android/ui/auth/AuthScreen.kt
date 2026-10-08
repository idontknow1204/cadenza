package com.cadenza.android.ui.auth

import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale

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
    var busy by remember { mutableStateOf(false) }

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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(bottom = 40.dp)
    ) {
        // Back button
        IconButton(onClick = onBack, modifier = Modifier.padding(start = 12.dp, top = 12.dp)) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "back")
        }

        // Heading
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp)
        ) {
            Text(
                if (isSignUp) headingSignUp else headingSignIn,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                lineHeight = 36.sp,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                if (isSignUp) subtitleSignUp else subtitleSignIn,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        // Mode tabs
        TabRow(selectedTabIndex = if (isSignUp) 0 else 1, modifier = Modifier.padding(horizontal = 24.dp)) {
            Tab(selected = isSignUp, onClick = { isSignUp = true; errorText = null }) {
                Text(tabSignUp, modifier = Modifier.padding(vertical = 12.dp))
            }
            Tab(selected = !isSignUp, onClick = { isSignUp = false; errorText = null }) {
                Text(tabSignIn, modifier = Modifier.padding(vertical = 12.dp))
            }
        }

        Spacer(Modifier.height(20.dp))

        // Fields
        Column(
            modifier = Modifier.padding(horizontal = 22.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            AnimatedVisibility(visible = isSignUp) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text(loc.localized("이름", "Name", "Name")) },
                    leadingIcon = { Icon(Icons.Default.Person, null) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Words,
                        imeAction = ImeAction.Next,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                )
            }

            OutlinedTextField(
                value = email,
                onValueChange = { email = it },
                label = { Text(loc.localized("이메일", "Email", "E-Mail")) },
                leadingIcon = { Icon(Icons.Default.Email, null) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    capitalization = KeyboardCapitalization.None,
                    imeAction = ImeAction.Next,
                ),
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
            )

            OutlinedTextField(
                value = password,
                onValueChange = { password = it },
                label = {
                    Text(
                        if (isSignUp) loc.localized("비밀번호 (6자 이상)", "Password (6+ chars)", "Passwort (mind. 6)")
                        else loc.localized("비밀번호", "Password", "Passwort")
                    )
                },
                leadingIcon = { Icon(Icons.Default.Lock, null) },
                trailingIcon = {
                    IconButton(onClick = { showPassword = !showPassword }) {
                        Icon(
                            if (showPassword) Icons.Default.VisibilityOff else Icons.Default.Visibility,
                            contentDescription = null,
                        )
                    }
                },
                visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done,
                ),
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
            )
        }

        // Forgot password
        AnimatedVisibility(visible = !isSignUp) {
            Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.CenterEnd) {
                TextButton(onClick = {}) {
                    Text(forgotPassword, color = MaterialTheme.colorScheme.primary)
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

        Spacer(Modifier.height(12.dp))

        // Primary CTA
        Button(
            onClick = {
                busy = true; errorText = null
                if (isSignUp) {
                    session.signUp(name, email, password) {
                        errorText = it; busy = false
                    }
                } else {
                    session.signIn(email, password) {
                        errorText = it; busy = false
                    }
                }
            },
            enabled = isValid && !busy,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp)
                .height(52.dp),
            shape = RoundedCornerShape(14.dp),
        ) {
            if (busy) {
                CircularProgressIndicator(modifier = Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
            } else {
                Text(if (isSignUp) ctaSignUp else ctaSignIn, fontWeight = FontWeight.SemiBold)
            }
        }

        // Divider "or"
        Row(
            modifier = Modifier.padding(horizontal = 22.dp, vertical = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            HorizontalDivider(modifier = Modifier.weight(1f))
            Text(
                dividerOr,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 12.dp),
            )
            HorizontalDivider(modifier = Modifier.weight(1f))
        }

        // Google button
        Surface(
            onClick = { /* TODO Step 6: Google Credential Manager */ },
            shape = RoundedCornerShape(14.dp),
            color = MaterialTheme.colorScheme.surface,
            tonalElevation = 1.dp,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 22.dp)
                .height(50.dp),
        ) {
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "G",
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 16.sp,
                    modifier = Modifier.padding(end = 8.dp),
                )
                Text(googleLabel, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium))
            }
        }
    }
}
