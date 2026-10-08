import SwiftUI

struct DataPrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @AppStorage("appLanguage") private var appLanguage: String = "ko"

    // Stored user preferences
    @AppStorage("privacy.marketingConsent")  private var marketingConsent = false
    @AppStorage("privacy.activityPublic")    private var activityPublic = true
    @AppStorage("privacy.profileIndexable")  private var profileIndexable = true
    @AppStorage("privacy.showInSearch")      private var showInSearch = true

    @State private var showPrivacyPolicy  = false
    @State private var showTerms          = false
    @State private var showDeleteConfirm  = false
    @State private var deleting           = false
    @State private var deleteError: String?

    // MARK: - Localization

    private var navTitle: String { localized("데이터 및 개인정보 설정", "Data and Privacy", "Daten & Datenschutz") }

    var body: some View {
        List {
            // ── 1. 내 데이터 개요 ─────────────────────────────────
            Section {
                dataOverviewCard
            } header: {
                Text(localized("Cadenza가 사용하는 데이터", "Data Cadenza uses", "Von Cadenza genutzte Daten"))
            } footer: {
                Text(localized(
                    "활동 기록과 프로필은 네트워크 협업, CV, 확인 기능에 활용됩니다.",
                    "Activity records and profile data are used for networking, CV, and verification features.",
                    "Aktivitäten und Profildaten dienen Vernetzung, Lebenslauf und Bestätigung."
                ))
            }

            // ── 2. 공개 범위 제어 ─────────────────────────────────
            Section {
                Toggle(isOn: $activityPublic) {
                    privacyToggleLabel(
                        icon: "waveform",
                        title: localized("활동 기록 공개", "Show activity records", "Aktivitäten anzeigen"),
                        subtitle: localized("설정한 공개 범위에 따라 활동이 다른 사용자에게 노출됩니다.", "Activities are shown to others based on your visibility setting.", "Aktivitäten werden je nach Sichtbarkeit für andere angezeigt.")
                    )
                }
                .tint(Color.accentColor)

                Toggle(isOn: $showInSearch) {
                    privacyToggleLabel(
                        icon: "magnifyingglass",
                        title: localized("검색 결과에 표시", "Appear in search results", "In Suchergebnissen erscheinen"),
                        subtitle: localized("다른 음악가가 이름이나 악기로 나를 찾을 수 있습니다.", "Other musicians can find you by name or instrument.", "Andere Musiker können dich nach Name oder Instrument finden.")
                    )
                }
                .tint(Color.accentColor)

                Toggle(isOn: $profileIndexable) {
                    privacyToggleLabel(
                        icon: "globe",
                        title: localized("공개 웹 프로필 노출", "Public web profile (fermata.app)", "Öffentliches Webprofil (fermata.app)"),
                        subtitle: localized("fermata.app/p/[슬러그] 주소로 프로필이 공개됩니다.", "Your profile is accessible at fermata.app/p/[slug].", "Dein Profil ist unter fermata.app/p/[slug] abrufbar.")
                    )
                }
                .tint(Color.accentColor)
            } header: {
                Text(localized("공개 범위 제어", "Visibility controls", "Sichtbarkeitssteuerung"))
            }

            // ── 3. 커뮤니케이션 ───────────────────────────────────
            Section {
                Toggle(isOn: $marketingConsent) {
                    privacyToggleLabel(
                        icon: "bell.badge",
                        title: localized("마케팅 및 업데이트 수신", "Marketing and updates", "Marketing und Updates"),
                        subtitle: localized("신기능 소식, 음악 커뮤니티 이벤트 알림을 받습니다. (선택)", "Receive new feature and community event notifications. (optional)", "Neuigkeiten zu Funktionen und Community-Events erhalten. (optional)")
                    )
                }
                .tint(Color.accentColor)
            } header: {
                Text(localized("커뮤니케이션", "Communication", "Kommunikation"))
            }

            // ── 4. 내 데이터 관리 ─────────────────────────────────
            Section {
                Button {
                    let email = "team@je-jal.com"
                    let subject = localized("데이터 내보내기 요청", "Data export request", "Datenexport-Anfrage")
                    let body = localized(
                        "안녕하세요, 내 Cadenza 계정(\(session.currentUserID?.uuidString ?? ""))의 데이터 내보내기를 요청합니다.",
                        "Hello, I would like to request an export of my Cadenza account data (ID: \(session.currentUserID?.uuidString ?? "")).",
                        "Hallo, ich möchte einen Export meiner Cadenza-Kontodaten (ID: \(session.currentUserID?.uuidString ?? "")) anfordern."
                    )
                    let urlStr = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    if let url = URL(string: urlStr) { UIApplication.shared.open(url) }
                } label: {
                    Label(localized("내 데이터 내보내기", "Download my data", "Meine Daten exportieren"), systemImage: "square.and.arrow.down")
                }

                Button {
                    let email = "team@je-jal.com"
                    let subject = localized("개인정보 삭제 요청", "Data deletion request", "Datenlöschanfrage")
                    let body = localized(
                        "안녕하세요, 내 Cadenza 계정(\(session.currentUserID?.uuidString ?? ""))의 개인정보 삭제를 요청합니다.",
                        "Hello, I would like to request deletion of my personal data for Cadenza account (ID: \(session.currentUserID?.uuidString ?? "")).",
                        "Hallo, ich möchte die Löschung meiner personenbezogenen Daten für das Cadenza-Konto (ID: \(session.currentUserID?.uuidString ?? "")) anfordern."
                    )
                    let urlStr = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                    if let url = URL(string: urlStr) { UIApplication.shared.open(url) }
                } label: {
                    Label(localized("개인정보 삭제 요청", "Request data deletion", "Datenlöschung beantragen"), systemImage: "trash.slash")
                        .foregroundStyle(.red)
                }
            } header: {
                Text(localized("내 데이터 관리", "Manage my data", "Meine Daten verwalten"))
            } footer: {
                Text(localized(
                    "내보내기 요청은 영업일 기준 5일 이내 처리됩니다. 계정 삭제는 설정 하단에서 직접 실행할 수 있습니다.",
                    "Export requests are processed within 5 business days. Account deletion is available at the bottom of Settings.",
                    "Exportanfragen werden innerhalb von 5 Werktagen bearbeitet. Die Kontolöschung ist in den Einstellungen möglich."
                ))
            }

            // ── 5. 법적 문서 ──────────────────────────────────────
            Section {
                Button { showPrivacyPolicy = true } label: {
                    Label(localized("개인정보 처리방침", "Privacy policy", "Datenschutzerklärung"), systemImage: "doc.text.magnifyingglass")
                }
                Button { showTerms = true } label: {
                    Label(localized("사용자약관", "Terms of service", "Nutzungsbedingungen"), systemImage: "doc.plaintext")
                }
            } header: {
                Text(localized("법적 문서", "Legal documents", "Rechtliche Dokumente"))
            }

            // ── 6. 연락처 ─────────────────────────────────────────
            Section {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("개인정보 관련 문의", "Privacy inquiries", "Datenschutzanfragen"))
                            .font(.subheadline)
                        Text("team@je-jal.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text(localized("문의", "Contact", "Kontakt"))
            } footer: {
                Text(localized(
                    "영업일 기준 3일 이내 답변해 드립니다.",
                    "We respond within 3 business days.",
                    "Wir antworten innerhalb von 3 Werktagen."
                ))
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView(isModal: true) }
        .sheet(isPresented: $showTerms)          { TermsOfServiceView(isModal: true) }
        .alert(localized("오류", "Error", "Fehler"), isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: { Text(deleteError ?? "") }
    }

    // MARK: - Data overview card

    private var dataOverviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            dataRow(
                icon: "person.fill",
                title: localized("프로필 정보", "Profile information", "Profilinformationen"),
                detail: localized("이름, 악기, 학교, 소개, 프로필 사진", "Name, instrument, school, bio, photo", "Name, Instrument, Hochschule, Bio, Foto")
            )
            Divider().padding(.leading, 36)
            dataRow(
                icon: "waveform",
                title: localized("활동 기록", "Activity records", "Aktivitätsaufzeichnungen"),
                detail: localized("공연, 콩쿠르, 교육, 날짜·장소·확인 상태", "Performances, competitions, education, dates, locations, verification", "Auftritte, Wettbewerbe, Unterricht, Bestätigung")
            )
            Divider().padding(.leading, 36)
            dataRow(
                icon: "network",
                title: localized("연결 정보", "Connection data", "Verbindungsdaten"),
                detail: localized("팔로우·연결 관계, 협업자 태그", "Follows, connections, collaborator tags", "Follows, Verbindungen, Mitwirkenden-Tags")
            )
            Divider().padding(.leading, 36)
            dataRow(
                icon: "lock.fill",
                title: localized("인증 정보", "Authentication data", "Authentifizierungsdaten"),
                detail: localized("이메일, 암호화된 비밀번호 (원문 저장 안 함)", "Email, encrypted password (plaintext never stored)", "E-Mail, verschlüsseltes Passwort (Klartext nie gespeichert)")
            )
        }
    }

    private func dataRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    // MARK: - Toggle label

    private func privacyToggleLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
