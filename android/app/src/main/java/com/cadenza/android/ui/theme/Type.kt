package com.cadenza.android.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

val CadenzaTypography = Typography(
    // iOS 시스템 폰트 크기 1:1 매핑 (SwiftUI points ≈ Android dp/sp)
    // iOS .largeTitle(34) → headlineLarge
    headlineLarge  = TextStyle(fontWeight = FontWeight.Bold,     fontSize = 34.sp),
    // iOS .title(28) → headlineMedium
    headlineMedium = TextStyle(fontWeight = FontWeight.Bold,     fontSize = 28.sp),
    // iOS .title2(22) → headlineSmall  [ProfileView name: .title2.bold()]
    headlineSmall  = TextStyle(fontWeight = FontWeight.Bold,     fontSize = 22.sp),
    // iOS .title3(20) → titleLarge  [SectionCard title: .title3.weight(.semibold)]
    titleLarge     = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 20.sp),
    // iOS .headline(17) → titleMedium  [ActivityCard title: .headline]
    titleMedium    = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 17.sp),
    // iOS .body(17) → bodyLarge  [CareerRow org: .body.weight(.semibold)]
    bodyLarge      = TextStyle(fontWeight = FontWeight.Normal,   fontSize = 17.sp),
    // iOS .subheadline(15) → bodyMedium  [bio, card body text]
    bodyMedium     = TextStyle(fontWeight = FontWeight.Normal,   fontSize = 15.sp),
    // iOS .footnote(13) → bodySmall  [CareerRow year: .footnote]
    bodySmall      = TextStyle(fontWeight = FontWeight.Normal,   fontSize = 13.sp),
    // iOS .caption(12) → labelMedium  [chip labels, captions]
    labelMedium    = TextStyle(fontWeight = FontWeight.Normal,   fontSize = 12.sp),
    // iOS .caption2(11) → labelSmall  [secondary metadata]
    labelSmall     = TextStyle(fontWeight = FontWeight.Normal,   fontSize = 11.sp),
    // iOS .caption.weight(.medium) → labelLarge
    labelLarge     = TextStyle(fontWeight = FontWeight.Medium,   fontSize = 12.sp),
)
