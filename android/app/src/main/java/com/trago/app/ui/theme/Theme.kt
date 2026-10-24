package com.trago.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
    primary = Coral,
    onPrimary = Color.White,
    primaryContainer = Coral,
    onPrimaryContainer = Color.White,
    secondary = Navy,
    onSecondary = Color.White,
    secondaryContainer = Navy,
    onSecondaryContainer = Color.White,
    tertiary = Mint,
    onTertiary = Color.White,
    background = Paper,
    onBackground = Ink,
    surface = Paper,
    onSurface = Ink,
    surfaceVariant = SurfaceLight,
    onSurfaceVariant = Muted,
    outline = BorderGray,
    error = Color(0xFFB3261E),
    onError = Color.White,
)

private val DarkColors = darkColorScheme(
    primary = Coral,
    secondary = Color(0xFFB8C6E8),
    tertiary = Mint,
)

@Composable
fun TragoTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = TragoTypography,
        content = content,
    )
}
