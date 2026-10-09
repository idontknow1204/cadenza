import SwiftUI

struct ProfileSettingsView: View {
    let languages: [ProfileLanguage]
    let defaultVisibility: Visibility
    let onEditLanguages: () -> Void
    let onSignOut: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    @AppStorage("appLanguage") private var appLanguage: String = "ko"
    @State private var selectedPage: SettingsPage?
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    @State private var deleting = false
    @State private var showAppLangPicker = false
    @State private var showCVEditor = false
    @State private var showMultilingual = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showCVEditor = true } label: {
                        SettingsRow(
                            icon: "doc.richtext",
                            title: localized("CV / 이력서", "CV / Résumé", "Lebenslauf"),
                            subtitle: localized("영어 CV 편집·PDF 내보내기", "Edit your English CV, export PDF", "Englischen CV bearbeiten, PDF"),
                            tint: .indigo
                        )
                    }
                    Button { showMultilingual = true } label: {
                        SettingsRow(
                            icon: "globe",
                            title: localized("다국어 프로필", "Multilingual profile", "Mehrsprachiges Profil"),
                            subtitle: localized("언어별 프로필 작성 (방문자 언어로 표시)", "Write per-language versions shown in visitor's language", "Sprachversionen je nach Besuchersprache"),
                            tint: .pink
                        )
                    }
                }

                Section {
                    Button { showAppLangPicker = true } label: {
                        SettingsRow(
                            icon: "translate",
                            title: localized("앱 언어", "App Language", "App-Sprache"),
                            subtitle: appLangName,
                            tint: .blue
                        )
                    }
                    Button { selectedPage = .language } label: {
                        SettingsRow(icon: "globe", title: localized("언어", "Language", "Sprache"), subtitle: languageSummary, tint: .teal)
                    }
                    Button { selectedPage = .security } label: {
                        SettingsRow(icon: "lock.shield", title: localized("로그인과 보안", "Login and security", "Login und Sicherheit"), subtitle: localized("이메일 로그인, 세션, 계정 보호", "Email sign-in, sessions, account protection", "E-Mail-Login, Sitzungen, Kontoschutz"), tint: .green)
                    }
                }

                Section {
                    Button { selectedPage = .dataPrivacy } label: {
                        SettingsRow(icon: "hand.raised", title: localized("데이터 및 개인정보 설정", "Data and privacy settings", "Daten- und Privatsphaere"), subtitle: localized("프로필, 활동 기록, 공개 범위 관리", "Profile, activity records, visibility controls", "Profil, Aktivitaeten, Sichtbarkeit"), tint: .purple)
                    }
                    Button { selectedPage = .notifications } label: {
                        SettingsRow(icon: "bell.badge", title: localized("알림", "Notifications", "Mitteilungen"), subtitle: localized("확인 요청, 댓글, 팔로우 알림", "Confirm requests, comments, follows", "Bestaetigungen, Kommentare, Follows"), tint: .orange)
                    }
                }

                Section {
                    Button { selectedPage = .help } label: {
                        SettingsRow(icon: "questionmark.circle", title: localized("고객센터", "Help center", "Hilfe"), subtitle: localized("계정, 학교 인증, 활동 기록 도움말", "Account, school verification, activity record help", "Konto, Hochschulnachweis, Aktivitaeten"), tint: .teal)
                    }
                    Button { selectedPage = .communityPolicy } label: {
                        SettingsRow(icon: "person.2.badge.gearshape", title: localized("프로페셔널 커뮤니티 정책", "Professional community policy", "Richtlinie fuer die Community"), subtitle: localized("음악가 네트워크에서 지켜야 할 기준", "Standards for a musician network", "Standards fuer ein Musiknetzwerk"), tint: .indigo)
                    }
                }

                Section {
                    Button { selectedPage = .privacyPolicy } label: {
                        SettingsRow(icon: "doc.text.magnifyingglass", title: localized("개인정보 처리방침", "Privacy policy", "Datenschutzerklaerung"), subtitle: localized("수집 데이터와 처리 목적", "Collected data and purposes", "Datenarten und Zwecke"), tint: .gray)
                    }
                    Button { selectedPage = .terms } label: {
                        SettingsRow(icon: "doc.plaintext", title: localized("사용자약관", "Terms of service", "Nutzungsbedingungen"), subtitle: localized("서비스 이용 조건", "Service rules and conditions", "Regeln und Bedingungen"), tint: .gray)
                    }
                }

                Section {
                    Button(role: .destructive) { showSignOutConfirm = true } label: {
                        Label(localized("로그아웃", "Sign out", "Abmelden"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                Section {
                    if deleting {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text(localized("계정 삭제 중...", "Deleting account...", "Konto wird geloescht..."))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } else {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label(localized("계정 삭제", "Delete account", "Konto loeschen"), systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(localized("설정 및 개인정보", "Settings and privacy", "Einstellungen"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCVEditor) { CVEditorView() }
            .sheet(isPresented: $showMultilingual) { MultilingualProfileEditorView() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("닫기", "Done", "Fertig")) { dismiss() }
                }
            }
            .navigationDestination(item: $selectedPage) { page in
                if page == .language {
                    SettingsDetailView(page: page, defaultVisibility: defaultVisibility, languages: languages) {
                        Button(localized("언어 편집", "Edit languages", "Sprachen bearbeiten"), action: onEditLanguages)
                    }
                } else {
                    SettingsDetailView(page: page, defaultVisibility: defaultVisibility, languages: languages)
                }
            }
            .confirmationDialog(localized("로그아웃할까요?", "Sign out?", "Abmelden?"), isPresented: $showSignOutConfirm, titleVisibility: .visible) {
                Button(localized("로그아웃", "Sign out", "Abmelden"), role: .destructive, action: onSignOut)
                Button(localized("취소", "Cancel", "Abbrechen"), role: .cancel) {}
            }
            .alert(
                localized("계정을 삭제하시겠어요?", "Delete your account?", "Konto loeschen?"),
                isPresented: $showDeleteConfirm
            ) {
                Button(localized("영구 삭제", "Delete permanently", "Endgueltig loeschen"), role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button(localized("취소", "Cancel", "Abbrechen"), role: .cancel) {}
            } message: {
                Text(localized(
                    "모든 활동 기록, 프로필, 연결 정보가 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.",
                    "All activity records, profile, and connection data will be permanently deleted. This cannot be undone.",
                    "Alle Aktivitaeten, Profile und Verbindungen werden dauerhaft geloescht. Dies kann nicht rueckgaengig gemacht werden."
                ))
            }
            .alert(localized("오류", "Error", "Fehler"), isPresented: .constant(deleteError != nil)) {
                Button(localized("확인", "OK", "OK")) { deleteError = nil }
            } message: { Text(deleteError ?? "") }
            .confirmationDialog(
                localized("앱 언어 선택", "Select App Language", "App-Sprache wählen"),
                isPresented: $showAppLangPicker,
                titleVisibility: .visible
            ) {
                Button("한국어") {
                    UserDefaults.standard.set(["ko"], forKey: "AppleLanguages")
                    appLanguage = "ko"
                }
                Button("English") {
                    UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
                    appLanguage = "en"
                }
                Button("Deutsch") {
                    UserDefaults.standard.set(["de"], forKey: "AppleLanguages")
                    appLanguage = "de"
                }
                Button(localized("취소", "Cancel", "Abbrechen"), role: .cancel) {}
            }
        }
    }

    private var appLangName: String {
        switch appLanguage {
        case "en": return localized("영어", "English", "Englisch")
        case "de": return localized("독일어", "German", "Deutsch")
        default:   return localized("한국어", "Korean", "Koreanisch")
        }
    }

    private func deleteAccount() async {
        deleting = true
        defer { deleting = false }
        do {
            try await session.repo.deleteAccount()
            await session.signOut()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private var languageSummary: String {
        guard !languages.isEmpty else {
            return localized("사용 언어를 추가하세요", "Add your languages", "Sprachen hinzufuegen")
        }
        return languages.prefix(3).map(\.language).joined(separator: ", ")
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsDetailView<Action: View>: View {
    let page: SettingsPage
    let defaultVisibility: Visibility
    let languages: [ProfileLanguage]
    @ViewBuilder var action: Action

    init(page: SettingsPage, defaultVisibility: Visibility, languages: [ProfileLanguage], @ViewBuilder action: () -> Action = { EmptyView() }) {
        self.page = page
        self.defaultVisibility = defaultVisibility
        self.languages = languages
        self.action = action()
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(page.title, systemImage: page.icon).font(.headline)
                    Text(page.summary(defaultVisibility: defaultVisibility, languages: languages))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
            }

            Section(page.sectionTitle) {
                ForEach(page.items(defaultVisibility: defaultVisibility, languages: languages), id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.caption)
                            .padding(.top, 2)
                        Text(item).font(.subheadline)
                    }
                }
            }

            if page == .language {
                Section { action }
            }
        }
        .navigationTitle(page.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum SettingsPage: String, Identifiable {
    case language
    case security
    case dataPrivacy
    case notifications
    case help
    case communityPolicy
    case privacyPolicy
    case terms

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .language: return "globe"
        case .security: return "lock.shield"
        case .dataPrivacy: return "hand.raised"
        case .notifications: return "bell.badge"
        case .help: return "questionmark.circle"
        case .communityPolicy: return "person.2.badge.gearshape"
        case .privacyPolicy: return "doc.text.magnifyingglass"
        case .terms: return "doc.plaintext"
        }
    }

    var title: String {
        switch self {
        case .language: return localized("언어", "Language", "Sprache")
        case .security: return localized("로그인과 보안", "Login and security", "Login und Sicherheit")
        case .dataPrivacy: return localized("데이터 및 개인정보 설정", "Data and privacy settings", "Daten- und Privatsphaere")
        case .notifications: return localized("알림", "Notifications", "Mitteilungen")
        case .help: return localized("고객센터", "Help center", "Hilfe")
        case .communityPolicy: return localized("프로페셔널 커뮤니티 정책", "Professional community policy", "Richtlinie fuer die Community")
        case .privacyPolicy: return localized("개인정보 처리방침", "Privacy policy", "Datenschutzerklaerung")
        case .terms: return localized("사용자약관", "Terms of service", "Nutzungsbedingungen")
        }
    }

    var sectionTitle: String {
        switch self {
        case .privacyPolicy, .terms, .communityPolicy:
            return localized("주요 내용", "Key points", "Kernpunkte")
        default:
            return localized("현재 설정", "Current settings", "Aktuelle Einstellungen")
        }
    }

    func summary(defaultVisibility: Visibility, languages: [ProfileLanguage]) -> String {
        switch self {
        case .language:
            return localized("프로필에 표시되는 사용 언어를 관리합니다. 국제 학생, 연주자, 교육자와 협업할 때 바로 확인되는 정보입니다.", "Manage languages shown on your profile so collaborators can understand how to contact you.", "Verwalte die Sprachen in deinem Profil fuer internationale Zusammenarbeit.")
        case .security:
            return localized("Cadenza는 Supabase 인증 기반의 이메일 로그인 세션을 사용합니다. 계정 접근과 세션 상태는 로그인 제공자의 보안 정책을 따릅니다.", "Cadenza uses email authentication sessions through Supabase. Account access follows the provider's security controls.", "Cadenza nutzt E-Mail-Sitzungen ueber Supabase und dessen Sicherheitsregeln.")
        case .dataPrivacy:
            return localized("프로필, 학교/커리어, 활동 기록, 함께한 사람 태그, 공개 범위를 한곳에서 이해할 수 있도록 정리했습니다.", "Review the profile, education, career, activity, collaborator, and visibility data Cadenza uses.", "Uebersicht ueber Profil-, Studien-, Karriere-, Aktivitaets- und Sichtbarkeitsdaten.")
        case .notifications:
            return localized("활동 확인 요청과 커뮤니티 상호작용을 놓치지 않도록 알림 범위를 준비 중입니다.", "Notification controls are prepared for confirm requests and community activity.", "Benachrichtigungen fuer Bestaetigungen und Community-Aktivitaeten sind vorbereitet.")
        case .help:
            return localized("계정 설정, 학교/커리어 정보, 활동 검증 흐름에 대한 도움말입니다.", "Help for account setup, education/career data, and activity verification.", "Hilfe zu Konto, Ausbildung/Karriere und Aktivitaetsbestaetigung.")
        case .communityPolicy:
            return localized("Cadenza는 음악가의 실제 활동 이력과 협업 신뢰를 쌓는 프로페셔널 네트워크입니다.", "Cadenza is a professional network for verified music activity and collaborator trust.", "Cadenza ist ein berufliches Netzwerk fuer nachvollziehbare Musikaktivitaeten.")
        case .privacyPolicy:
            return localized("제품 컨셉 기준의 개인정보 처리 안내입니다. 정식 법무 문서로 게시 전 검토가 필요합니다.", "A product-level privacy notice. Review with counsel before publishing as a formal legal document.", "Produktbezogene Datenschutzhinweise, vor Veroeffentlichung rechtlich pruefen.")
        case .terms:
            return localized("서비스 이용 기준과 사용자의 책임을 제품 흐름에 맞춰 정리했습니다.", "Service rules and user responsibilities tailored to Cadenza's product flow.", "Regeln und Verantwortlichkeiten fuer Cadenza.")
        }
    }

    func items(defaultVisibility: Visibility, languages: [ProfileLanguage]) -> [String] {
        switch self {
        case .language:
            let current = languages.isEmpty ? localized("아직 등록된 언어가 없습니다.", "No languages added yet.", "Noch keine Sprachen hinzugefuegt.") : languages.map { "\($0.language) · \($0.level)" }.joined(separator: "\n")
            return [current, localized("언어 정보는 프로필 카드와 협업 판단 맥락에 표시됩니다.", "Language data appears on your profile and collaboration context.", "Sprachen erscheinen im Profil und Kontext fuer Zusammenarbeit.")]
        case .security:
            return [
                localized("로그인은 이메일과 비밀번호 기반입니다.", "Sign-in uses email and password.", "Login erfolgt per E-Mail und Passwort."),
                localized("세션은 로그아웃 시 기기에서 해제됩니다.", "Signing out clears the active session on this device.", "Abmelden beendet die aktive Sitzung auf diesem Geraet."),
                localized("비밀번호 변경과 2단계 인증 UI는 이후 계정 보안 화면에 연결할 수 있습니다.", "Password reset and two-factor UI can be connected here later.", "Passwort-Reset und Zwei-Faktor-UI koennen spaeter verbunden werden.")
            ]
        case .dataPrivacy:
            return [
                localized("기본 프로필: 실명, 전공, 악기, 소개, 프로필 이미지", "Profile: real name, major, instrument, bio, avatar", "Profil: Name, Fach, Instrument, Bio, Avatar"),
                localized("전문 이력: 학교, 과정, 입학/졸업 연도, 커리어, 사용 언어", "Professional history: schools, programs, years, career, languages", "Werdegang: Hochschulen, Programme, Jahre, Karriere, Sprachen"),
                localized("활동 데이터: 공연, 콩쿠르, 교육, 녹음, 협업자 태그와 확인 상태", "Activity data: performances, competitions, teaching, recordings, collaborator tags, verification", "Aktivitaeten: Auftritte, Wettbewerbe, Unterricht, Aufnahmen, Mitwirkende, Bestaetigung"),
                localized("현재 기본 공개 범위: \(visibilityLabel(defaultVisibility))", "Default visibility: \(visibilityLabel(defaultVisibility))", "Standardsichtbarkeit: \(visibilityLabel(defaultVisibility))")
            ]
        case .notifications:
            return [
                localized("함께한 활동에 태그되면 확인 요청 알림이 필요합니다.", "Confirm requests should notify you when someone tags you.", "Bestaetigungsanfragen informieren dich bei Tags."),
                localized("댓글과 팔로우 같은 커뮤니티 반응 알림을 분리할 수 있게 설계했습니다.", "Community signals such as comments and follows can be separated.", "Kommentare und Follows koennen getrennt gesteuert werden."),
                localized("푸시 알림 권한 연결 전까지 앱 내 알림함이 기본 채널입니다.", "The in-app inbox remains the default channel until push permissions are connected.", "Bis Push verbunden ist, bleibt die Inbox der Standardkanal.")
            ]
        case .help:
            return [
                localized("활동 기록은 함께한 사람의 확인을 받아 신뢰도를 높입니다.", "Activity records gain trust through collaborator confirmation.", "Aktivitaeten gewinnen Vertrauen durch Mitwirkenden-Bestaetigung."),
                localized("학교와 커리어 정보는 프로필의 전문 맥락을 만듭니다.", "Education and career data create professional context on profiles.", "Ausbildung und Karriere schaffen beruflichen Kontext."),
                localized("문의 채널은 support@cadenza.app 기준으로 연결하면 됩니다.", "Use support@cadenza.app as the support contact.", "support@cadenza.app kann als Kontakt genutzt werden.")
            ]
        case .communityPolicy:
            return [
                localized("본인이 참여했거나 신뢰할 수 있는 근거가 있는 활동만 기록합니다.", "Only record activity you participated in or can substantiate.", "Nur belegbare eigene Aktivitaeten eintragen."),
                localized("협업자 태그는 상대의 확인 경험을 존중하는 방식으로 사용합니다.", "Use collaborator tags in a way that respects the other person's confirmation flow.", "Tags sollen den Bestaetigungsprozess anderer respektieren."),
                localized("학교, 기관, 동료를 사칭하거나 이력을 과장하지 않습니다.", "Do not impersonate schools, institutions, or peers, or inflate credentials.", "Keine Taeuschung ueber Hochschulen, Institutionen oder Referenzen."),
                localized("비평보다 검증 가능한 전문 이력과 협업 맥락을 우선합니다.", "Prioritize verifiable professional history and collaboration context over criticism.", "Nachvollziehbarer Werdegang und Zusammenarbeit stehen im Vordergrund.")
            ]
        case .privacyPolicy:
            return [
                localized("수집 목적: 계정 운영, 프로필 표시, 활동 기록, 확인 요청, 추천 및 검색", "Purpose: account operation, profile display, activity records, confirm requests, discovery and search", "Zweck: Konto, Profil, Aktivitaeten, Bestaetigungen, Suche"),
                localized("저장 데이터: 인증 정보, 프로필, 학교/커리어, 언어, 활동, 댓글, 팔로우 관계", "Stored data: auth data, profile, education/career, languages, activities, comments, follow graph", "Gespeicherte Daten: Auth, Profil, Ausbildung/Karriere, Sprachen, Aktivitaeten, Kommentare, Follows"),
                localized("공개 범위 설정에 따라 활동과 프로필 일부가 다른 사용자에게 보일 수 있습니다.", "Depending on visibility settings, parts of your profile and activity may be visible to other users.", "Je nach Sichtbarkeit koennen Profilteile und Aktivitaeten sichtbar sein."),
                localized("정식 출시 전 보존 기간, 삭제 요청, 제3자 처리자 항목을 법무 검토해야 합니다.", "Before launch, retention, deletion requests, and processors should be legally reviewed.", "Vor Launch Aufbewahrung, Loeschung und Anbieter rechtlich pruefen.")
            ]
        case .terms:
            return [
                localized("사용자는 본인의 계정과 등록한 전문 이력의 정확성에 책임이 있습니다.", "Users are responsible for the accuracy of their account and professional history.", "Nutzer sind fuer Konto und Angaben verantwortlich."),
                localized("허위 활동, 무단 이미지, 타인 사칭, 괴롭힘성 사용은 제한됩니다.", "False activity, unauthorized images, impersonation, and harassment are restricted.", "Falsche Aktivitaeten, unerlaubte Bilder, Taeuschung und Belaestigung sind untersagt."),
                localized("확인 요청은 신뢰 보조 수단이며 기관의 공식 증명서를 대체하지 않습니다.", "Confirm requests support trust but do not replace official institutional certification.", "Bestaetigungen ersetzen keine offiziellen Nachweise."),
                localized("서비스 안정성과 커뮤니티 보호를 위해 일부 콘텐츠나 계정 조치가 가능해야 합니다.", "Content or account actions may be needed for service integrity and community protection.", "Massnahmen an Inhalten oder Konten koennen zum Schutz noetig sein.")
            ]
        }
    }
}

private func visibilityLabel(_ visibility: Visibility) -> String {
    switch visibility {
    case .public:            return localized("전체 공개",  "Public",              "Öffentlich")
    case .industryFollowers: return localized("업계+팔로워", "Industry + followers", "Branche + Follower")
    case .followers:         return localized("팔로워만",   "Followers only",       "Nur Follower")
    case .private:           return localized("비공개",     "Private",              "Privat")
    }
}
