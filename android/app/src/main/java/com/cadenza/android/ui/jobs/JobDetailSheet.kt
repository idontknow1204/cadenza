package com.cadenza.android.ui.jobs

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.Done
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material.icons.outlined.Place
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.Job
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun JobDetailSheet(
    job: Job,
    isOwner: Boolean,
    onDismiss: () -> Unit,
    onJobClosed: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var showCloseConfirm by remember { mutableStateOf(false) }
    var closing by remember { mutableStateOf(false) }
    var contactCopied by remember { mutableStateOf(false) }

    LaunchedEffect(contactCopied) {
        if (contactCopied) { delay(3000); contactCopied = false }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars)
                .verticalScroll(rememberScrollState())
                .padding(bottom = 24.dp),
        ) {
            // ── Header ─────────────────────────────────────────────────────
            Column(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Surface(
                        shape = RoundedCornerShape(6.dp),
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                    ) {
                        Text(
                            job.type.label,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        )
                    }
                    JobDeadlineBadge(job = job)
                }
                Text(job.title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                if (!job.organization.isNullOrEmpty()) {
                    Text(job.organization, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (!job.location.isNullOrEmpty()) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Icon(Icons.Outlined.Place, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(job.location, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    if (!job.deadline.isNullOrEmpty()) {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Icon(Icons.Outlined.CalendarMonth, contentDescription = null, modifier = Modifier.size(16.dp), tint = MaterialTheme.colorScheme.onSurfaceVariant)
                            Text(
                                AppLocale.localized("마감일 ${job.deadline}", "Deadline ${job.deadline}", "Bewerbungsfrist ${job.deadline}"),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
                if (job.instruments.isNotEmpty()) {
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        job.instruments.forEach { inst ->
                            Surface(shape = RoundedCornerShape(6.dp), color = MaterialTheme.colorScheme.surfaceVariant) {
                                Text(
                                    OnboardingData.instrumentDisplay(inst),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                                )
                            }
                        }
                    }
                }
            }

            HorizontalDivider()

            // ── Application info ───────────────────────────────────────────
            val facts = buildList {
                if (job.videoAudition == true) add(AppLocale.localized("영상 예선 가능", "Video round available", "Video-Vorrunde möglich"))
                if (job.applicationFee == 0)   add(AppLocale.localized("지원료 없음", "No application fee", "Keine Bewerbungsgebühr"))
                if (job.hasScholarship == true) add(AppLocale.localized("장학금 있음", "Scholarship available", "Stipendium verfügbar"))
                if (!job.eventStart.isNullOrEmpty()) {
                    val period = job.eventStart + (job.eventEnd?.let { " – $it" } ?: "")
                    add(AppLocale.localized("진행 일정: $period", "Event dates: $period", "Zeitraum: $period"))
                }
                if (job.ageMin != null && job.ageMax != null)
                    add(AppLocale.localized("지원 연령: ${job.ageMin}–${job.ageMax}세", "Age: ${job.ageMin}–${job.ageMax}", "Alter: ${job.ageMin}–${job.ageMax}"))
                else if (job.ageMin != null)
                    add(AppLocale.localized("지원 연령: ${job.ageMin}세 이상", "Minimum age: ${job.ageMin}", "Mindestalter: ${job.ageMin}"))
                else if (job.ageMax != null)
                    add(AppLocale.localized("지원 연령: ${job.ageMax}세 이하", "Maximum age: ${job.ageMax}", "Höchstalter: ${job.ageMax}"))
            }
            if (facts.isNotEmpty()) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(
                        AppLocale.localized("지원 정보", "Application information", "Bewerbungsinformationen"),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    facts.forEach { fact -> Text(fact, style = MaterialTheme.typography.bodyMedium) }
                }
                HorizontalDivider()
            }

            // ── Description ────────────────────────────────────────────────
            if (!job.description.isNullOrEmpty()) {
                DetailSection(AppLocale.localized("상세 내용", "Details", "Details"), job.description)
                HorizontalDivider()
            }
            if (!job.requirements.isNullOrEmpty()) {
                DetailSection(AppLocale.localized("지원 자격", "Requirements", "Voraussetzungen"), job.requirements)
                HorizontalDivider()
            }
            if (!job.contact.isNullOrEmpty()) {
                DetailSection(AppLocale.localized("지원 방법 / 연락처", "How to apply / contact", "Bewerbung / Kontakt"), job.contact)
                HorizontalDivider()
            }

            // ── Source link (curated) ──────────────────────────────────────
            if (job.isCurated && !job.sourceUrl.isNullOrEmpty()) {
                TextButton(
                    onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(job.sourceUrl))) },
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                ) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(AppLocale.localized("공식 원문 보기", "View official source", "Offizielle Quelle"), style = MaterialTheme.typography.bodyMedium)
                        Icon(Icons.Outlined.OpenInNew, contentDescription = null, modifier = Modifier.size(16.dp))
                    }
                }
                HorizontalDivider()
            }

            // ── Poster (user-posted) ───────────────────────────────────────
            if (!job.isCurated && job.poster != null) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Surface(
                        shape = androidx.compose.foundation.shape.CircleShape,
                        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.12f),
                        modifier = Modifier.size(40.dp),
                    ) {
                        androidx.compose.foundation.layout.Box(contentAlignment = androidx.compose.ui.Alignment.Center) {
                            Text(
                                job.poster.realName.take(2),
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                    Column(modifier = Modifier.weight(1f)) {
                        Text(job.poster.realName, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
                        if (!job.poster.instrument.isNullOrEmpty()) {
                            Text(OnboardingData.instrumentDisplay(job.poster.instrument), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Text(AppLocale.localized("게시자", "Posted by", "Veröffentlicht von"), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                HorizontalDivider()
            }

            // ── Action buttons ─────────────────────────────────────────────
            val applyUrl = job.applicationUrl ?: if (job.isCurated) job.sourceUrl else null
            if (!applyUrl.isNullOrEmpty()) {
                Button(
                    onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(applyUrl))) },
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                ) {
                    Icon(Icons.Outlined.OpenInNew, contentDescription = null, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.size(8.dp))
                    Text(AppLocale.localized("공식 페이지에서 지원", "Apply on official page", "Auf offizieller Seite bewerben"), fontWeight = FontWeight.SemiBold)
                }
            } else if (!job.contact.isNullOrEmpty()) {
                Button(
                    onClick = {
                        val cm = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        cm.setPrimaryClip(ClipData.newPlainText("contact", job.contact))
                        contactCopied = true
                    },
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                ) {
                    Icon(
                        if (contactCopied) Icons.Outlined.Done else Icons.Outlined.ContentCopy,
                        contentDescription = null,
                        modifier = Modifier.size(16.dp),
                    )
                    Spacer(Modifier.size(8.dp))
                    Text(
                        if (contactCopied)
                            AppLocale.localized("연락처 복사 완료", "Copied!", "Kopiert!")
                        else
                            AppLocale.localized("연락처 복사", "Copy contact", "Kontakt kopieren"),
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }

            // ── Owner close button ─────────────────────────────────────────
            if (isOwner && job.isActive) {
                TextButton(
                    onClick = { showCloseConfirm = true },
                    enabled = !closing,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                    colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.error),
                ) {
                    Text(
                        if (closing)
                            AppLocale.localized("처리 중…", "Closing…", "Wird geschlossen…")
                        else
                            AppLocale.localized("공고 마감 처리", "Close opportunity", "Ausschreibung schließen"),
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }
    }

    if (showCloseConfirm) {
        AlertDialog(
            onDismissRequest = { showCloseConfirm = false },
            title = { Text(AppLocale.localized("공고를 마감 처리하시겠어요?", "Close this opportunity?", "Ausschreibung schließen?")) },
            confirmButton = {
                TextButton(onClick = {
                    showCloseConfirm = false
                    closing = true
                    scope.launch {
                        onJobClosed()
                        closing = false
                    }
                }) {
                    Text(AppLocale.localized("마감", "Close", "Schließen"), color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showCloseConfirm = false }) {
                    Text(AppLocale.localized("취소", "Cancel", "Abbrechen"))
                }
            },
        )
    }
}

@Composable
private fun DetailSection(heading: String, text: String) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(heading, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(text, style = MaterialTheme.typography.bodyMedium, lineHeight = MaterialTheme.typography.bodyMedium.lineHeight)
    }
}
