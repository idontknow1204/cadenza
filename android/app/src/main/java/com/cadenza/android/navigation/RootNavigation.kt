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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.theme.CadenzaAccent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
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
private val TabGatherDp = 10.dp  // 탭 사이 중심 간격을 이만큼 좁힘
private val TabIconLabelGap = 0.dp
private val TabPillHeight = 26.dp

@Composable
private fun TabBarItem(
    selected: Boolean,
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val color = if (selected) CadenzaAccent else MaterialTheme.colorScheme.onSurfaceVariant
    Column(
        modifier = modifier
            .fillMaxHeight()
            .selectable(selected = selected, role = Role.Tab, onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(width = 56.dp, height = TabPillHeight)
                .background(
                    if (selected) CadenzaAccent.copy(alpha = 0.12f) else Color.Transparent,
                    RoundedCornerShape(14.dp),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(24.dp))
        }
        Spacer(Modifier.height(TabIconLabelGap))
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
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

    Scaffold(
        bottomBar = {
            // M3 NavigationBarItem은 아이콘-라벨 간격을 조절할 수 없어 직접 그린다.
            val backStack by navController.currentBackStackEntryAsState()
            val current = backStack?.destination

            Surface(color = MaterialTheme.colorScheme.surface) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .navigationBarsPadding()
                        .height(TabBarHeight),
                    horizontalArrangement = Arrangement.Center,
                ) {
                    // 화면 5등분 폭에서 TabGatherDp만큼 줄여 탭 중심 간격을 모은다
                    val tabWidth = LocalConfiguration.current.screenWidthDp.dp / tabs.size - TabGatherDp
                    tabs.forEach { tab ->
                        TabBarItem(
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
    ) { padding ->
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
            composable("public_profile/{userId}") { backStackEntry ->
                val userId = backStackEntry.arguments?.getString("userId") ?: return@composable
                PublicProfileScreen(
                    userId = userId,
                    onBack = { navController.popBackStack() },
                    onNavigateToUser = { targetId -> navController.navigate("public_profile/$targetId") },
                    session = session,
                )
            }
        }
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
