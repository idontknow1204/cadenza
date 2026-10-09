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
    primary                 = CadenzaAccent,
    onPrimary               = Color.White,
    primaryContainer        = BrandSurface,
    onPrimaryContainer      = CadenzaAccent,
    inversePrimary          = Color(0xFFFFB3C1),
    secondary               = BrandGold,
    onSecondary             = Color.White,
    secondaryContainer      = BrandSurface,
    onSecondaryContainer    = Color(0xFF4A3520),
    // tertiary: neutral blue-gray — never leave unset (defaults to purple)
    tertiary                = Color(0xFF5D6B78),
    onTertiary              = Color.White,
    tertiaryContainer       = Color(0xFFE1E8EF),
    onTertiaryContainer     = Color(0xFF37474F),
    // Background = screen/list background (iOS secondarySystemBackground = #F2F2F7)
    background              = Color(0xFFF2F2F7),
    onBackground            = Color(0xFF1C1C1E),
    // Surface = card/sheet background (iOS systemBackground = white)
    surface                 = Color.White,
    onSurface               = Color(0xFF1C1C1E),
    surfaceVariant          = Color(0xFFE5E5EA),
    onSurfaceVariant        = Color(0xFF6C6C70),
    // surfaceTint must be set to brand color or M3 will tint with primary (= purple in baseline)
    surfaceTint             = CadenzaAccent,
    inverseSurface          = Color(0xFF1C1C1E),
    inverseOnSurface        = Color.White,
    error                   = Color(0xFFBA1A1A),
    onError                 = Color.White,
    errorContainer          = Color(0xFFFFDAD6),
    onErrorContainer        = Color(0xFF410002),
    outline                 = Color(0xFFC7C7CC),
    outlineVariant          = Color(0xFFD8D8DC),
    scrim                   = Color.Black,
    surfaceBright           = Color.White,
    surfaceDim              = Color(0xFFE8E8ED),
    surfaceContainerLowest  = Color.White,
    // NavigationBar uses surfaceContainerLow — white = matches iOS tab bar
    surfaceContainerLow     = Color.White,
    surfaceContainer        = Color(0xFFF2F2F7),
    surfaceContainerHigh    = Color(0xFFE8E8ED),
    surfaceContainerHighest = Color(0xFFE5E5EA),
)

private val DarkColorScheme = darkColorScheme(
    primary                 = CadenzaAccentDark,
    onPrimary               = Color.White,
    primaryContainer        = BrandSurfaceDark,
    onPrimaryContainer      = CadenzaAccentDark,
    inversePrimary          = CadenzaAccent,
    secondary               = BrandGoldDark,
    onSecondary             = Color.Black,
    secondaryContainer      = BrandSurfaceDark,
    onSecondaryContainer    = BrandGoldDark,
    tertiary                = Color(0xFF90A4AE),
    onTertiary              = Color(0xFF1A2B34),
    tertiaryContainer       = Color(0xFF2C3E4A),
    onTertiaryContainer     = Color(0xFFCBDEE8),
    // Background = screen/list background (iOS dark secondarySystemBackground = black)
    background              = Color.Black,
    onBackground            = Color.White,
    // Surface = card/sheet background (iOS dark systemBackground = #1C1C1E)
    surface                 = Color(0xFF1C1C1E),
    onSurface               = Color.White,
    surfaceVariant          = Color(0xFF2C2C2E),
    onSurfaceVariant        = Color(0xFF8E8E93),
    surfaceTint             = CadenzaAccentDark,
    inverseSurface          = Color(0xFFF2F2F7),
    inverseOnSurface        = Color(0xFF1C1C1E),
    error                   = Color(0xFFFFB4AB),
    onError                 = Color(0xFF690005),
    errorContainer          = Color(0xFF93000A),
    onErrorContainer        = Color(0xFFFFDAD6),
    outline                 = Color(0xFF48484A),
    outlineVariant          = Color(0xFF38383A),
    scrim                   = Color.Black,
    surfaceBright           = Color(0xFF3A3A3C),
    surfaceDim              = Color.Black,
    surfaceContainerLowest  = Color.Black,
    // NavigationBar dark uses surfaceContainerLow
    surfaceContainerLow     = Color(0xFF1C1C1E),
    surfaceContainer        = Color(0xFF2C2C2E),
    surfaceContainerHigh    = Color(0xFF38383A),
    surfaceContainerHighest = Color(0xFF48484A),
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
