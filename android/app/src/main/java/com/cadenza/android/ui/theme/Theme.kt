package com.cadenza.android.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

private val LightColorScheme = lightColorScheme(
    primary          = CadenzaAccent,
    onPrimary        = androidx.compose.ui.graphics.Color.White,
    primaryContainer = BrandSurface,
    onPrimaryContainer = CadenzaAccent,
    secondary        = BrandGold,
    onSecondary      = androidx.compose.ui.graphics.Color.White,
    surface          = BrandSurface,
    background       = androidx.compose.ui.graphics.Color.White,
)

private val DarkColorScheme = darkColorScheme(
    primary          = CadenzaAccentDark,
    onPrimary        = androidx.compose.ui.graphics.Color.White,
    primaryContainer = BrandSurfaceDark,
    onPrimaryContainer = CadenzaAccentDark,
    secondary        = BrandGoldDark,
    onSecondary      = androidx.compose.ui.graphics.Color.Black,
    surface          = BrandSurfaceDark,
    background       = androidx.compose.ui.graphics.Color.Black,
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
