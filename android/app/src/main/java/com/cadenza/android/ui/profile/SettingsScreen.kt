package com.cadenza.android.ui.profile

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Email
import androidx.compose.material.icons.outlined.ExitToApp
import androidx.compose.material.icons.outlined.Gavel
import androidx.compose.material.icons.outlined.Language
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Policy
import androidx.compose.material.icons.outlined.PrivacyTip
import androidx.compose.material.icons.outlined.QuestionMark
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.cadenza.android.core.data.preferences.AppPreferences
import com.cadenza.android.core.data.repository.Repository
import com.cadenza.android.core.session.SessionViewModel
import com.cadenza.android.core.util.AppLocale
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileSettingsSheet(
    session: SessionViewModel,
    repository: Repository,
    appPreferences: AppPreferences,
    onDismiss: () -> Unit,
    onSignOut: () -> Unit,
    onEditCv: () -> Unit = {},
    onEditLanguages: () -> Unit = {},
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val userId = session.currentUserId

    var showSignOutConfirm by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }
    var deleteError by remember { mutableStateOf<String?>(null) }
    var showLangPicker by remember { mutableStateOf(false) }
    var showDataPrivacy by remember { mutableStateOf(false) }

    val currentLang = AppLocale.language
    val langName = when (currentLang) {
        "en" -> AppLocale.localized("영어", "English", "Englisch")
        "de" -> AppLocale.localized("독일어", "German", "Deutsch")
        else -> AppLocale.localized("한국어", "Korean", "Koreanisch")
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars),
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(AppLocale.localized("설정 및 개인정보", "Settings and privacy", "Einstellungen"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    TextButton(onClick = onDismiss) { Text(AppLocale.localized("닫기", "Done", "Fertig"), style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold)) }
                }
                HorizontalDivider()
            }

            // ── Profile tools ─────────────────────────────────────────────────
            item {
                SettingsSectionHeader(AppLocale.localized("프로필 도구", "Profile tools", "Profilwerkzeuge"))
            }
            item {
                SettingsRow(
                    icon = Icons.Outlined.AccountCircle,
                    iconColor = Color(0xFF5C6BC0),
                    title = AppLocale.localized("CV / 이력서", "CV / Résumé", "Lebenslauf"),
                    subtitle = AppLocale.localized("영어 CV 편집·PDF 내보내기", "Edit your English CV, export PDF", "Englischen CV bearbeiten, PDF"),
                    onClick = onEditCv,
                )
            }
            item {
                SettingsRow(
                    icon = Icons.Outlined.Language,
                    iconColor = Color(0xFFEC407A),
                    title = AppLocale.localized("사용 언어", "Languages", "Sprachen"),
                    subtitle = AppLocale.localized("프로필에 표시할 언어 관리", "Manage languages on your profile", "Sprachen im Profil verwalten"),
                    onClick = onEditLanguages,
                )
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // ── App settings ──────────────────────────────────────────────────
            item { SettingsSectionHeader(AppLocale.localized("앱 설정", "App settings", "App-Einstellungen")) }
            item {
                SettingsRow(
                    icon = Icons.Outlined.Language,
                    iconColor = Color(0xFF1E88E5),
                    title = AppLocale.localized("앱 언어", "App Language", "App-Sprache"),
                    subtitle = langName,
                    onClick = { showLangPicker = true },
                )
            }
            item {
                SettingsRow(
                    icon = Icons.Outlined.Lock,
                    iconColor = Color(0xFF43A047),
                    title = AppLocale.localized("로그인과 보안", "Login and security", "Login und Sicherheit"),
                    subtitle = AppLocale.localized("이메일 로그인, 세션, 계정 보호", "Email sign-in, sessions, account protection", "E-Mail-Login, Sitzungen, Kontoschutz"),
                    onClick = {},
                )
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // ── Privacy ───────────────────────────────────────────────────────
            item { SettingsSectionHeader(AppLocale.localized("개인정보", "Privacy", "Datenschutz")) }
            item {
                SettingsRow(
                    icon = Icons.Outlined.PrivacyTip,
                    iconColor = Color(0xFF7B1FA2),
                    title = AppLocale.localized("데이터 및 개인정보 설정", "Data and privacy settings", "Daten- und Privatsphäre"),
                    subtitle = AppLocale.localized("프로필, 활동 기록, 공개 범위 관리", "Profile, activity records, visibility controls", "Profil, Aktivitäten, Sichtbarkeit"),
                    onClick = { showDataPrivacy = true },
                )
            }
            item {
                SettingsRow(
                    icon = Icons.Outlined.Notifications,
                    iconColor = Color(0xFFEF6C00),
                    title = AppLocale.localized("알림", "Notifications", "Mitteilungen"),
                    subtitle = AppLocale.localized("확인 요청, 댓글, 팔로우 알림", "Confirm requests, comments, follows", "Bestätigungen, Kommentare, Follows"),
                    onClick = {},
                )
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // ── Help & Legal ──────────────────────────────────────────────────
            item { SettingsSectionHeader(AppLocale.localized("도움말 및 법적 정보", "Help & Legal", "Hilfe & Rechtliches")) }
            item {
                SettingsRow(
                    icon = Icons.Outlined.Email,
                    iconColor = Color(0xFF00897B),
                    title = AppLocale.localized("고객센터", "Help center", "Hilfe"),
                    subtitle = AppLocale.localized("team@je-jal.com", "team@je-jal.com", "team@je-jal.com"),
                    onClick = {
                        val subject = AppLocale.localized("문의합니다", "Support request", "Supportanfrage")
                        val uri = Uri.parse("mailto:team@je-jal.com?subject=${Uri.encode(subject)}")
                        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                    },
                )
            }
            item {
                SettingsRow(
                    icon = Icons.Outlined.Gavel,
                    iconColor = Color(0xFF546E7A),
                    title = AppLocale.localized("프로페셔널 커뮤니티 정책", "Professional community policy", "Community-Richtlinie"),
                    subtitle = AppLocale.localized("음악가 네트워크에서 지켜야 할 기준", "Standards for a musician network", "Standards für ein Musiknetzwerk"),
                    onClick = {},
                )
            }
            item {
                SettingsRow(
                    icon = Icons.Outlined.Policy,
                    iconColor = Color(0xFF546E7A),
                    title = AppLocale.localized("개인정보 처리방침", "Privacy policy", "Datenschutzerklärung"),
                    subtitle = AppLocale.localized("수집 데이터와 처리 목적", "Collected data and purposes", "Datenarten und Zwecke"),
                    onClick = {
                        val uri = Uri.parse("https://fermata.app/privacy")
                        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                    },
                )
            }
            item {
                SettingsRow(
                    icon = Icons.Outlined.QuestionMark,
                    iconColor = Color(0xFF546E7A),
                    title = AppLocale.localized("사용자약관", "Terms of service", "Nutzungsbedingungen"),
                    subtitle = AppLocale.localized("서비스 이용 조건", "Service rules and conditions", "Regeln und Bedingungen"),
                    onClick = {
                        val uri = Uri.parse("https://fermata.app/terms")
                        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                    },
                )
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // ── Account ───────────────────────────────────────────────────────
            item { SettingsSectionHeader(AppLocale.localized("계정", "Account", "Konto")) }
            item {
                SettingsRow(
                    icon = Icons.Outlined.ExitToApp,
                    iconColor = MaterialTheme.colorScheme.error,
                    title = AppLocale.localized("로그아웃", "Sign out", "Abmelden"),
                    subtitle = "",
                    onClick = { showSignOutConfirm = true },
                    textColor = MaterialTheme.colorScheme.error,
                )
            }
            item {
                if (deleting) {
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp))
                        Text(AppLocale.localized("계정 삭제 중...", "Deleting account...", "Konto wird gelöscht..."), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                } else {
                    SettingsRow(
                        icon = Icons.Outlined.Delete,
                        iconColor = MaterialTheme.colorScheme.error,
                        title = AppLocale.localized("계정 삭제", "Delete account", "Konto löschen"),
                        subtitle = "",
                        onClick = { showDeleteConfirm = true },
                        textColor = MaterialTheme.colorScheme.error,
                    )
                }
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }

    // ── App language picker ─────────────────────────────────────────────────
    if (showLangPicker) {
        AlertDialog(
            onDismissRequest = { showLangPicker = false },
            title = { Text(AppLocale.localized("앱 언어 선택", "Select App Language", "App-Sprache wählen")) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    listOf("ko" to "한국어", "en" to "English", "de" to "Deutsch").forEach { (code, name) ->
                        TextButton(
                            onClick = {
                                scope.launch {
                                    appPreferences.setLanguage(code)
                                    showLangPicker = false
                                }
                            },
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text(name, style = MaterialTheme.typography.bodyLarge, fontWeight = if (currentLang == code) FontWeight.Bold else FontWeight.Normal) }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showLangPicker = false }) {
                    Text(AppLocale.localized("취소", "Cancel", "Abbrechen"), style = MaterialTheme.typography.bodyLarge)
                }
            },
        )
    }

    // ── Sign out confirm ───────────────────────────────────────────────────
    if (showSignOutConfirm) {
        AlertDialog(
            onDismissRequest = { showSignOutConfirm = false },
            title = { Text(AppLocale.localized("로그아웃할까요?", "Sign out?", "Abmelden?")) },
            confirmButton = {
                TextButton(onClick = onSignOut) { Text(AppLocale.localized("로그아웃", "Sign out", "Abmelden"), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showSignOutConfirm = false }) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen"), style = MaterialTheme.typography.bodyLarge) }
            },
        )
    }

    // ── Delete confirm ────────────────────────────────────────────────────
    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text(AppLocale.localized("계정을 삭제하시겠어요?", "Delete your account?", "Konto löschen?")) },
            text = { Text(AppLocale.localized("모든 활동 기록, 프로필, 연결 정보가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.", "All activity records, profile, and connection data will be permanently deleted. This cannot be undone.", "Alle Aktivitäten, Profile und Verbindungen werden dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.")) },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirm = false
                        scope.launch {
                            deleting = true
                            try {
                                repository.deleteAccount()
                                onSignOut()
                            } catch (e: Exception) {
                                deleteError = e.message
                                deleting = false
                            }
                        }
                    },
                ) { Text(AppLocale.localized("영구 삭제", "Delete permanently", "Endgültig löschen"), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) { Text(AppLocale.localized("취소", "Cancel", "Abbrechen"), style = MaterialTheme.typography.bodyLarge) }
            },
        )
    }

    // ── Delete error ──────────────────────────────────────────────────────
    if (deleteError != null) {
        AlertDialog(
            onDismissRequest = { deleteError = null },
            title = { Text(AppLocale.localized("오류", "Error", "Fehler")) },
            text = { Text(deleteError!!) },
            confirmButton = { TextButton(onClick = { deleteError = null }) { Text("OK") } },
        )
    }

    // ── Data privacy sheet ────────────────────────────────────────────────
    if (showDataPrivacy) {
        DataPrivacySheet(
            userId = userId,
            appPreferences = appPreferences,
            onDismiss = { showDataPrivacy = false },
        )
    }
}

// ─── Data privacy sheet ───────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DataPrivacySheet(
    userId: String?,
    appPreferences: AppPreferences,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    var activityPublic by remember { mutableStateOf(true) }
    var showInSearch by remember { mutableStateOf(true) }
    var profileIndexable by remember { mutableStateOf(true) }
    var marketingConsent by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .windowInsetsPadding(WindowInsets.navigationBars),
        ) {
            item {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(AppLocale.localized("데이터 및 개인정보 설정", "Data and Privacy", "Daten & Datenschutz"), style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    TextButton(onClick = onDismiss) { Text(AppLocale.localized("닫기", "Done", "Fertig"), style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold)) }
                }
                HorizontalDivider()
            }

            // Data overview
            item { SettingsSectionHeader(AppLocale.localized("Cadenza가 사용하는 데이터", "Data Cadenza uses", "Von Cadenza genutzte Daten")) }
            item {
                Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(0.dp)) {
                    DataOverviewRow(AppLocale.localized("프로필 정보", "Profile information", "Profilinformationen"), AppLocale.localized("이름, 악기, 학교, 소개, 프로필 사진", "Name, instrument, school, bio, photo", "Name, Instrument, Hochschule, Bio, Foto"))
                    HorizontalDivider(modifier = Modifier.padding(start = 36.dp))
                    DataOverviewRow(AppLocale.localized("활동 기록", "Activity records", "Aktivitätsaufzeichnungen"), AppLocale.localized("공연, 콩쿠르, 교육, 날짜·장소·확인 상태", "Performances, competitions, education, dates, locations, verification", "Auftritte, Wettbewerbe, Unterricht, Bestätigung"))
                    HorizontalDivider(modifier = Modifier.padding(start = 36.dp))
                    DataOverviewRow(AppLocale.localized("연결 정보", "Connection data", "Verbindungsdaten"), AppLocale.localized("팔로우·연결 관계, 협업자 태그", "Follows, connections, collaborator tags", "Follows, Verbindungen, Mitwirkenden-Tags"))
                    HorizontalDivider(modifier = Modifier.padding(start = 36.dp))
                    DataOverviewRow(AppLocale.localized("인증 정보", "Authentication data", "Authentifizierungsdaten"), AppLocale.localized("이메일, 암호화된 비밀번호 (원문 저장 안 함)", "Email, encrypted password (plaintext never stored)", "E-Mail, verschlüsseltes Passwort (Klartext nie gespeichert)"))
                }
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // Visibility controls
            item { SettingsSectionHeader(AppLocale.localized("공개 범위 제어", "Visibility controls", "Sichtbarkeitssteuerung")) }
            item {
                PrivacyToggleRow(
                    title = AppLocale.localized("활동 기록 공개", "Show activity records", "Aktivitäten anzeigen"),
                    subtitle = AppLocale.localized("설정한 공개 범위에 따라 활동이 다른 사용자에게 노출됩니다.", "Activities are shown to others based on your visibility setting.", "Aktivitäten werden je nach Sichtbarkeit für andere angezeigt."),
                    checked = activityPublic,
                    onChecked = { activityPublic = it },
                )
            }
            item {
                PrivacyToggleRow(
                    title = AppLocale.localized("검색 결과에 표시", "Appear in search results", "In Suchergebnissen erscheinen"),
                    subtitle = AppLocale.localized("다른 음악가가 이름이나 악기로 나를 찾을 수 있습니다.", "Other musicians can find you by name or instrument.", "Andere Musiker können dich nach Name oder Instrument finden."),
                    checked = showInSearch,
                    onChecked = { showInSearch = it },
                )
            }
            item {
                PrivacyToggleRow(
                    title = AppLocale.localized("공개 웹 프로필 노출", "Public web profile (fermata.app)", "Öffentliches Webprofil (fermata.app)"),
                    subtitle = AppLocale.localized("fermata.app/p/[슬러그] 주소로 프로필이 공개됩니다.", "Your profile is accessible at fermata.app/p/[slug].", "Dein Profil ist unter fermata.app/p/[slug] abrufbar."),
                    checked = profileIndexable,
                    onChecked = { profileIndexable = it },
                )
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // Communication
            item { SettingsSectionHeader(AppLocale.localized("커뮤니케이션", "Communication", "Kommunikation")) }
            item {
                PrivacyToggleRow(
                    title = AppLocale.localized("마케팅 및 업데이트 수신", "Marketing and updates", "Marketing und Updates"),
                    subtitle = AppLocale.localized("신기능 소식, 음악 커뮤니티 이벤트 알림을 받습니다. (선택)", "Receive new feature and community event notifications. (optional)", "Neuigkeiten zu Funktionen und Community-Events erhalten. (optional)"),
                    checked = marketingConsent,
                    onChecked = { marketingConsent = it },
                )
            }
            item { HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp)) }

            // Manage my data
            item { SettingsSectionHeader(AppLocale.localized("내 데이터 관리", "Manage my data", "Meine Daten verwalten")) }
            item {
                SettingsRow(
                    icon = Icons.Outlined.Email,
                    iconColor = MaterialTheme.colorScheme.primary,
                    title = AppLocale.localized("내 데이터 내보내기", "Download my data", "Meine Daten exportieren"),
                    subtitle = AppLocale.localized("이메일로 요청 (영업일 5일)", "Request via email (5 business days)", "Per E-Mail anfordern (5 Werktage)"),
                    onClick = {
                        val subject = AppLocale.localized("데이터 내보내기 요청", "Data export request", "Datenexport-Anfrage")
                        val body = "ID: ${userId ?: ""}"
                        val uri = Uri.parse("mailto:team@je-jal.com?subject=${Uri.encode(subject)}&body=${Uri.encode(body)}")
                        context.startActivity(Intent(Intent.ACTION_VIEW, uri))
                    },
                )
            }

            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

@Composable
private fun SettingsSectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
            .padding(horizontal = 16.dp, vertical = 10.dp),
    )
}

@Composable
fun SettingsRow(
    icon: ImageVector,
    iconColor: Color,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
    textColor: Color = MaterialTheme.colorScheme.onSurface,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier.size(38.dp).clip(RoundedCornerShape(8.dp)).background(iconColor.copy(alpha = 0.12f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(21.dp), tint = iconColor)
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium, color = textColor)
            if (subtitle.isNotEmpty()) {
                Text(subtitle, style = MaterialTheme.typography.bodySmall.copy(fontSize = 14.sp), color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 2)
            }
        }
    }
}

@Composable
private fun DataOverviewRow(title: String, detail: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier.size(28.dp).clip(RoundedCornerShape(7.dp)).background(MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Outlined.AccountCircle, contentDescription = null, modifier = Modifier.size(15.dp), tint = MaterialTheme.colorScheme.primary)
        }
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
            Text(detail, style = MaterialTheme.typography.bodySmall.copy(fontSize = 14.sp), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun PrivacyToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onChecked: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
            Text(subtitle, style = MaterialTheme.typography.bodySmall.copy(fontSize = 14.sp), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Switch(checked = checked, onCheckedChange = onChecked)
    }
}
