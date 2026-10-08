package com.cadenza.android.ui.onboarding

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.ui.onboarding.steps.Step1ConsentScreen
import com.cadenza.android.ui.onboarding.steps.Step2InstrumentScreen
import com.cadenza.android.ui.onboarding.steps.Step3AffiliationScreen
import com.cadenza.android.ui.onboarding.steps.Step4TeacherScreen
import com.cadenza.android.ui.onboarding.steps.Step5ProfileScreen
import com.cadenza.android.ui.onboarding.steps.Step6ActivityScreen
import com.cadenza.android.ui.onboarding.steps.Step7ContactsScreen
import com.cadenza.android.ui.onboarding.steps.Step8VisibilityScreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingScreen(
    session: SessionViewModel,
    repository: Repository,
    viewModel: OnboardingViewModel = hiltViewModel(),
) {
    val step by viewModel.step.collectAsState()
    val errorText by viewModel.errorText.collectAsState()
    val userId = session.currentUserId ?: ""

    Scaffold(
        topBar = {
            if (step > 1) {
                TopAppBar(
                    title = {
                        if (step > 1) {
                            val progress = (step - 1).toFloat() / (viewModel.totalSteps - 1)
                            LinearProgressIndicator(
                                progress = { progress },
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(4.dp)
                                    .clip(RoundedCornerShape(2.dp)),
                            )
                        }
                    },
                    navigationIcon = {
                        if (step > 2) {
                            IconButton(onClick = { viewModel.back() }) {
                                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "back")
                            }
                        }
                    },
                )
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            AnimatedContent(
                targetState = step,
                transitionSpec = {
                    if (targetState > initialState) {
                        slideInHorizontally { it } togetherWith slideOutHorizontally { -it }
                    } else {
                        slideInHorizontally { -it } togetherWith slideOutHorizontally { it }
                    }
                },
                label = "onboarding_step",
            ) { s ->
                when (s) {
                    1 -> Step1ConsentScreen(viewModel)
                    2 -> Step2InstrumentScreen(viewModel, userId)
                    3 -> Step3AffiliationScreen(viewModel, userId)
                    4 -> Step4TeacherScreen(viewModel, userId, repository)
                    5 -> Step5ProfileScreen(viewModel, userId)
                    6 -> Step6ActivityScreen(viewModel)
                    7 -> Step7ContactsScreen(viewModel)
                    else -> Step8VisibilityScreen(viewModel, session)
                }
            }
        }
    }

    if (errorText != null) {
        AlertDialog(
            onDismissRequest = { viewModel.clearError() },
            title = { Text("오류") },
            text = { Text(errorText ?: "") },
            confirmButton = {
                TextButton(onClick = { viewModel.clearError() }) { Text("확인") }
            },
        )
    }
}
