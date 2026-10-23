package com.cadenza.android.navigation

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.HorizontalDivider
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Shadow
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.offset
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.unit.IntOffset
import kotlin.math.roundToInt
import kotlinx.coroutines.launch
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.theme.CadenzaAccent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.navArgument
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.cadenza.android.R
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.ui.activity.CreateActivitySheet
import com.cadenza.android.ui.feed.FeedScreen
import com.cadenza.android.ui.jobs.JobsScreen
import com.cadenza.android.ui.notifications.NotificationsScreen
import com.cadenza.android.ui.org.OrgPageScreen
import com.cadenza.android.ui.profile.ProfileScreen
import com.cadenza.android.ui.profile.PublicProfileScreen
import androidx.hilt.navigation.compose.hiltViewModel

// iOS RootTabView 상당 — 5탭 (tab 2 = 활동 기록 액션, 네비게이션 아님)
sealed class Tab(
    val route: String,
    @StringRes val labelRes: Int,
    val icon: ImageVector,
) {
    data object Feed          : Tab("feed",          R.string.tab_feed,          Icons.Default.Home)
    data object Notifications : Tab("notifications", R.string.tab_notifications, Icons.Default.Notifications)
    data object Create        : Tab("create",        R.string.tab_record,        Icons.Default.AddCircle)
    data object Jobs          : Tab("jobs",          R.string.tab_jobs,          Icons.Default.Work)
    data object Profile       : Tab("profile",       R.string.tab_profile,       Icons.Default.Person)
}

private val tabs = listOf(Tab.Feed, Tab.Notifications, Tab.Create, Tab.Jobs, Tab.Profile)

// 탭바 치수 — 화면 보며 조정하는 값
private val TabBarHeight = 46.dp
private val TabBarTopMargin = 8.dp  // 캡슐 안쪽 윗 여유
private val TabBarBottomMargin = 4.dp  // 캡슐 안쪽 아랫 여유
private val FloatingBarBottomGap = 8.dp  // 캡슐과 화면(내비게이션 바) 아래 사이 간격
private val TabGatherDp = 10.dp  // 탭 사이 중심 간격을 이만큼 좁힘
private val TabIconLabelGap = 0.dp
private val TabPillHeight = 26.dp
private val TabPillWidth = 56.dp
private val TabShadowColor = Color.Black.copy(alpha = 0.10f)  // 탭바 아이콘·라벨·pill 그림자

/** 선택된 탭 뒤의 pill — 탭이 바뀌면 옆 탭으로 부드럽게 이동한다. */
@Composable
private fun SlidingTabPill(target: Offset?, containerOrigin: Offset) {
    if (target == null) return
    val x = remember { Animatable(0f) }
    val y = remember { Animatable(0f) }
    var placed by remember { mutableStateOf(false) }
    val rel = target - containerOrigin
    LaunchedEffect(rel) {
        if (!placed) {
            x.snapTo(rel.x); y.snapTo(rel.y); placed = true
        } else {
            launch { x.animateTo(rel.x, spring(dampingRatio = 0.8f, stiffness = 500f)) }
            launch { y.animateTo(rel.y, spring(dampingRatio = 0.8f, stiffness = 500f)) }
        }
    }
    if (placed) {
        Box(
            Modifier
                .offset { IntOffset(x.value.roundToInt(), y.value.roundToInt()) }
                .size(width = TabPillWidth, height = TabPillHeight)
                .shadow(
                    elevation = 3.dp,
                    shape = RoundedCornerShape(14.dp),
                    ambientColor = TabShadowColor,
                    spotColor = TabShadowColor,
                )
                .background(CadenzaAccent.copy(alpha = 0.12f), RoundedCornerShape(14.dp)),
        )
    }
}

@Composable
private fun TabBarItem(
    selected: Boolean,
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    onPillPositioned: (Offset) -> Unit,
    modifier: Modifier = Modifier,
) {
    val color = if (selected) CadenzaAccent else MaterialTheme.colorScheme.onSurfaceVariant
    Column(
        modifier = modifier
            .fillMaxHeight()
            .selectable(
                selected = selected,
                role = Role.Tab,
                interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
                indication = null, // 눌림 시 회색 사각 리플 제거 (선택 pill은 유지)
                onClick = onClick,
            ),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(width = TabPillWidth, height = TabPillHeight)
                // 선택 pill은 탭바에서 하나만 그려 탭 간에 슬라이드시킨다 (위치만 보고)
                .onGloballyPositioned { onPillPositioned(it.positionInWindow()) },
            contentAlignment = Alignment.Center,
        ) {
            // 은은한 글리프 그림자: 아래로 1dp 밀린 반투명 검정 복사본 (API 31+는 블러)
            Icon(
                icon, contentDescription = null, tint = TabShadowColor,
                modifier = Modifier.size(24.dp).offset(y = 1.dp).blur(1.5.dp),
            )
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(24.dp))
        }
        Spacer(Modifier.height(TabIconLabelGap))
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium.copy(
                shadow = Shadow(TabShadowColor, offset = Offset(0f, 2f), blurRadius = 3f),
            ),
            color = color,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
fun RootNavigation(
    session: SessionViewModel = hiltViewModel(),
) {
    val navController = rememberNavController()
    var showCreateActivity by remember { mutableStateOf(false) }
    val connectionError by session.connectionStore.errorMessage.collectAsState()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(connectionError) {
        connectionError?.let {
            snackbarHostState.showSnackbar(it)
            session.connectionStore.clearError()
        }
    }

    // 탭바는 Scaffold bottomBar가 아니라 콘텐츠 위에 겹쳐 띄운다 (캡슐 바깥은 콘텐츠가 그대로 보임)
    val tabBar: @Composable () -> Unit = {
            // M3 NavigationBarItem은 아이콘-라벨 간격을 조절할 수 없어 직접 그린다.
            val backStack by navController.currentBackStackEntryAsState()
            val current = backStack?.destination

            // iOS식 플로팅 글래스 탭바: 둥근 캡슐 + 반투명 + 가장자리 하이라이트 + 부드러운 그림자
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .navigationBarsPadding()
                    .padding(horizontal = 16.dp)
                    .padding(bottom = FloatingBarBottomGap),
            ) {
            val barShape = RoundedCornerShape(30.dp)
            Surface(
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.94f),
                shape = barShape,
                border = BorderStroke(
                    0.8.dp,
                    Brush.verticalGradient(
                        listOf(Color.White.copy(alpha = 0.65f), Color.White.copy(alpha = 0.12f)),
                    ),
                ),
                modifier = Modifier.shadow(
                    elevation = 18.dp,
                    shape = barShape,
                    ambientColor = Color.Black.copy(alpha = 0.25f),
                    spotColor = Color.Black.copy(alpha = 0.25f),
                ),
            ) {
                val pillPositions = remember { mutableStateMapOf<Int, Offset>() }
                var rowOrigin by remember { mutableStateOf(Offset.Zero) }
                val selectedIndex = tabs.indexOfFirst { tab ->
                    tab !is Tab.Create && current?.hierarchy?.any { it.route == tab.route } == true
                }
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = TabBarTopMargin, bottom = TabBarBottomMargin)
                        .height(TabBarHeight)
                        .onGloballyPositioned { rowOrigin = it.positionInWindow() },
                ) {
                SlidingTabPill(target = pillPositions[selectedIndex], containerOrigin = rowOrigin)
                Row(
                    modifier = Modifier.fillMaxSize(),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    // 화면 5등분 폭에서 TabGatherDp만큼 줄여 탭 중심 간격을 모은다
                    val tabWidth = LocalConfiguration.current.screenWidthDp.dp / tabs.size - TabGatherDp
                    tabs.forEachIndexed { index, tab ->
                        TabBarItem(
                            onPillPositioned = { pillPositions[index] = it },
                            selected = current?.hierarchy?.any { it.route == tab.route } == true,
                            icon = tab.icon,
                            label = when (tab) {
                                Tab.Feed          -> AppLocale.localized("피드", "Feed", "Feed")
                                Tab.Notifications -> AppLocale.localized("알림", "Alerts", "Benachr.")
                                Tab.Create        -> AppLocale.localized("기록", "Record", "Aufnahme")
                                Tab.Jobs          -> AppLocale.localized("기회", "Jobs", "Stellen")
                                Tab.Profile       -> AppLocale.localized("프로필", "Profile", "Profil")
                            },
                            onClick = {
                                when (tab) {
                                    Tab.Create -> showCreateActivity = true
                                    else -> navController.navigate(tab.route) {
                                        popUpTo(navController.graph.findStartDestination().id) {
                                            saveState = true
                                        }
                                        launchSingleTop = true
                                        restoreState = true
                                    }
                                }
                            },
                            modifier = Modifier.width(tabWidth),
                        )
                    }
                }
                }
            }
            }
    }

    var barHeightPx by remember { mutableIntStateOf(0) }
    val barHeight = with(LocalDensity.current) { barHeightPx.toDp() }

    Box(Modifier.fillMaxSize()) {
    Scaffold { _ ->
        // 화면들은 이 값만큼 목록 하단을 비워 마지막 항목이 캡슐에 가리지 않게 한다
        val padding = PaddingValues(bottom = barHeight)
        NavHost(navController = navController, startDestination = Tab.Feed.route) {
            composable(Tab.Feed.route) {
                FeedScreen(
                    contentPadding = padding,
                    session = session,
                    onNotifications = {
                        navController.navigate(Tab.Notifications.route) {
                            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                    onCreateActivity = { showCreateActivity = true },
                    onNavigateToUser = { userId -> navController.navigate("public_profile/$userId") },
                    onNavigateToOrg = { orgId -> navController.navigate("org_page/$orgId") },
                )
            }
            composable(Tab.Notifications.route) {
                NotificationsScreen(
                    contentPadding = padding,
                    session = session,
                    onNavigateToUser = { userId -> navController.navigate("public_profile/$userId") },
                )
            }
            composable(Tab.Jobs.route)          { JobsScreen(contentPadding = padding, session = session) }
            composable(Tab.Profile.route) {
                ProfileScreen(
                    contentPadding = padding,
                    session = session,
                    onNavigateToUser = { userId -> navController.navigate("public_profile/$userId") },
                    onPreview = { userId -> navController.navigate("public_profile/$userId?preview=true") },
                )
            }
            composable("org_page/{orgId}") { backStackEntry ->
                val orgId = backStackEntry.arguments?.getString("orgId") ?: return@composable
                OrgPageScreen(
                    orgId = orgId,
                    onBack = { navController.popBackStack() },
                    onNavigateToUser = { userId -> navController.navigate("public_profile/$userId") },
                    session = session,
                )
            }
            composable(
                route = "public_profile/{userId}?preview={preview}",
                arguments = listOf(
                    navArgument("userId") { type = NavType.StringType },
                    navArgument("preview") { type = NavType.StringType; defaultValue = "false" },
                ),
            ) { backStackEntry ->
                val userId = backStackEntry.arguments?.getString("userId") ?: return@composable
                val preview = backStackEntry.arguments?.getString("preview") == "true"
                PublicProfileScreen(
                    userId = userId,
                    isPreview = preview,
                    onBack = { navController.popBackStack() },
                    onNavigateToUser = { targetId -> navController.navigate("public_profile/$targetId") },
                    session = session,
                )
            }
        }
    }
    SnackbarHost(
        snackbarHostState,
        modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = barHeight),
    )
    Box(
        Modifier
            .align(Alignment.BottomCenter)
            .onSizeChanged { barHeightPx = it.height },
    ) { tabBar() }
    }

    val createActivityUserId = if (showCreateActivity) session.currentUserId else null
    if (showCreateActivity && createActivityUserId != null) {
        CreateActivitySheet(
            userId = createActivityUserId,
            repository = session.repository,
            onDismiss = { showCreateActivity = false },
            onPosted = { showCreateActivity = false },
        )
    }
}
