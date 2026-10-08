package com.cadenza.android.navigation

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.cadenza.android.R
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.ui.feed.FeedScreen
import com.cadenza.android.ui.jobs.JobsScreen
import com.cadenza.android.ui.notifications.NotificationsScreen
import com.cadenza.android.ui.profile.ProfileScreen
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
private val navTabs = listOf(Tab.Feed, Tab.Notifications, Tab.Jobs, Tab.Profile)

@Composable
fun RootNavigation(
    session: SessionViewModel = hiltViewModel(),
) {
    val navController = rememberNavController()
    var showCreateActivity by remember { mutableStateOf(false) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                val backStack by navController.currentBackStackEntryAsState()
                val current = backStack?.destination

                tabs.forEach { tab ->
                    NavigationBarItem(
                        selected = current?.hierarchy?.any { it.route == tab.route } == true,
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
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(stringResource(tab.labelRes)) }
                    )
                }
            }
        }
    ) { padding ->
        NavHost(navController = navController, startDestination = Tab.Feed.route) {
            composable(Tab.Feed.route) {
                FeedScreen(
                    contentPadding = padding,
                    session = session,
                    onCreateActivity = { showCreateActivity = true },
                    onNavigateToUser = { /* TODO: ProfileScreen */ },
                    onNavigateToOrg = { /* TODO: OrgPageScreen */ },
                )
            }
            composable(Tab.Notifications.route) { NotificationsScreen(contentPadding = padding) }
            composable(Tab.Jobs.route)          { JobsScreen(contentPadding = padding) }
            composable(Tab.Profile.route)       { ProfileScreen(contentPadding = padding) }
        }
    }

    // TODO(5단계-5d): CreateActivitySheet 구현 후 연결
    if (showCreateActivity) {
        // CreateActivitySheet(onDismiss = { showCreateActivity = false })
        showCreateActivity = false
    }
}
