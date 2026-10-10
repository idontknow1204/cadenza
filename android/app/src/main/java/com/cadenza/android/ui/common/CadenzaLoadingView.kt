package com.cadenza.android.ui.common

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.pulltorefresh.pullToRefresh
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.cadenza.android.R
import com.cadenza.android.core.util.AppLocale
import kotlin.math.PI
import kotlin.math.sin

// iOS CadenzaLoadingMotion.duration
private const val SpinDurationMs = 1350

// iOS UIRefreshControl: 새로고침 중 목록이 이 높이만큼 아래로 밀린 채 고정되고, 그 빈 자리 가운데에 로고가 있다.
private val RefreshHoldHeight = 60.dp
private val RefreshLogoSize = 28.dp

// 로고는 흰 배경 + 검은 잉크. iOS처럼 잉크를 알파로 쓰고 systemGray(#8E8E93)로 칠한다.
// alpha = 1 - luminance, rgb = 고정 회색
private val LogoInkToGray = ColorMatrix(
    floatArrayOf(
        0f, 0f, 0f, 0f, 142f,
        0f, 0f, 0f, 0f, 142f,
        0f, 0f, 0f, 0f, 147f,
        -0.2126f, -0.7152f, -0.0722f, 0f, 255f,
    )
)

/** iOS CadenzaLoadingView: 회색 Cadenza 로고가 가감속하며 회전한다. */
@Composable
fun CadenzaLoadingView(
    modifier: Modifier = Modifier,
    size: Dp = 24.dp,
    isAnimating: Boolean = true,
) {
    val turns by rememberInfiniteTransition(label = "cadenzaSpin").animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(SpinDurationMs, easing = LinearEasing), RepeatMode.Restart),
        label = "turns",
    )
    // iOS: 360 * (t - 0.75 * sin(2πt) / 2π) — 한 바퀴 경계에서도 속도가 이어진다
    val degrees = if (isAnimating) 360f * (turns - 0.75f * sin(2f * PI.toFloat() * turns) / (2f * PI.toFloat())) else 0f
    Image(
        painter = painterResource(R.drawable.cadenza_logo),
        contentDescription = AppLocale.localized("불러오는 중", "Loading", "Wird geladen"),
        colorFilter = ColorFilter.colorMatrix(LogoInkToGray),
        modifier = modifier
            .size(size)
            .graphicsLayer { rotationZ = degrees },
    )
}

/**
 * iOS cadenzaRefreshable: 아래로 당기면 목록 전체가 따라 내려오고, 새로고침 동안 그 자리에 고정된다.
 * 벌어진 빈 자리 가운데에 회전 로고(28)가 보인다.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CadenzaPullToRefresh(
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    val state = rememberPullToRefreshState()
    val holdPx = with(LocalDensity.current) { RefreshHoldHeight.toPx() }

    // 새로고침 중에는 임계 위치에 고정, 끝나면 되돌린다
    LaunchedEffect(isRefreshing) {
        if (isRefreshing) state.animateToThreshold() else state.animateToHidden()
    }

    Box(
        modifier = modifier
            .clipToBounds()
            .pullToRefresh(
                state = state,
                isRefreshing = isRefreshing,
                threshold = RefreshHoldHeight,
                onRefresh = onRefresh,
            ),
    ) {
        val fraction = state.distanceFraction
        if (fraction > 0f) {
            // 목록이 내려오며 생긴 빈 자리(0..gap)의 가운데에 로고
            Box(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .size(RefreshLogoSize)
                    .graphicsLayer { translationY = fraction * holdPx / 2f - size.height / 2f },
            ) {
                CadenzaLoadingView(size = RefreshLogoSize)
            }
        }
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer { translationY = state.distanceFraction.coerceAtMost(1.5f) * holdPx },
            content = content,
        )
    }
}
