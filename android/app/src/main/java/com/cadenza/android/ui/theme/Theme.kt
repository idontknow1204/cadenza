package com.cadenza.android.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val LightColorScheme = lightColorScheme(
    primary             = CadenzaAccent,
    onPrimary           = Color.White,
    primaryContainer    = BrandSurface,
    onPrimaryContainer  = CadenzaAccent,
    secondary           = BrandGold,
    onSecondary         = Color.White,
    secondaryContainer  = BrandSurface,
    // Surface = card/sheet background (iOS systemBackground = white)
    surface             = Color.White,
    onSurface           = Color(0xFF1C1C1E),
    // Background = screen/list background (iOS secondarySystemBackground = #F2F2F7)
    background          = Color(0xFFF2F2F7),
    onBackground        = Color(0xFF1C1C1E),
    // SurfaceVariant = subtle gray for separators and input containers
    surfaceVariant      = Color(0xFFE5E5EA),
    onSurfaceVariant    = Color(0xFF6C6C70),
    outline             = Color(0xFFC7C7CC),
)

private val DarkColorScheme = darkColorScheme(
    primary             = CadenzaAccentDark,
    onPrimary           = Color.White,
    primaryContainer    = BrandSurfaceDark,
    onPrimaryContainer  = CadenzaAccentDark,
    secondary           = BrandGoldDark,
    onSecondary         = Color.Black,
    secondaryContainer  = BrandSurfaceDark,
    // Surface = card/sheet background (iOS dark systemBackground = #1C1C1E)
    surface             = Color(0xFF1C1C1E),
    onSurface           = Color.White,
    // Background = screen/list background (iOS dark secondarySystemBackground = black)
    background          = Color.Black,
    onBackground        = Color.White,
    surfaceVariant      = Color(0xFF2C2C2E),
    onSurfaceVariant    = Color(0xFF8E8E93),
    outline             = Color(0xFF38383A),
)

@Composable
fun CadenzaTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    // Dynamic Color는 Android 12+ (API 31+). 브랜드 색상 유지가 중요하므로 기본 비활성화.
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography  = CadenzaTypography,
        content     = content
    )
}
