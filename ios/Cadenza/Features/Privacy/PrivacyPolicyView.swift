import SwiftUI

struct PrivacyPolicyView: View {
    var isModal: Bool = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "ko"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    policyContent
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle(localized("개인정보 처리방침", "Privacy Policy", "Datenschutzerklärung"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localized("닫기", "Done", "Fertig")) { dismiss() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var policyContent: some View {
        let lang = appLanguage.isEmpty ? "ko" : appLanguage
        if lang == "en" {
            PolicyDocument(sections: englishSections)
        } else if lang == "de" {
            PolicyDocument(sections: germanSections)
        } else {
            PolicyDocument(sections: koreanSections)
        }
    }

    // MARK: - Korean

    private var koreanSections: [PolicySection] {[
        PolicySection(
            number: "1",
            title: "수집하는 개인정보 항목",
            body: """
Cadenza는 서비스 제공을 위해 다음과 같은 개인정보를 수집합니다.

**[필수 항목]**
• 이름(실명), 이메일 주소, 비밀번호(암호화 저장)
• 전공, 악기, 학교·소속 기관, 입학/졸업 연도
• 활동 기록(공연, 콩쿠르, 교육, 레퍼토리), 활동 날짜·장소·역할
• 프로필 사진

**[선택 항목]**
• 소개글(Bio), 커리어 이력, 사용 언어
• 연락처(전화번호, 주소) — 비공개 프로필 전용
• 마케팅 수신 동의 여부

**[자동 수집]**
• 앱 사용 기록, 기기 정보, 오류 로그
• 협업자 태그 및 확인(verification) 상태
"""
        ),
        PolicySection(
            number: "2",
            title: "개인정보 수집 및 이용 목적",
            body: """
• **계정 운영**: 회원가입, 로그인, 인증 세션 관리
• **프로필 서비스**: 공개 프로필, CV/이력서 생성·내보내기
• **활동 기록**: 공연·콩쿠르·교육 이력의 기록, 검색, 확인 요청
• **네트워크 기능**: 팔로우·연결, 피드, 협업자 찾기
• **서비스 개선**: 오류 분석, 사용 패턴 파악, 신규 기능 개발
• **법적 의무 이행**: 관련 법령에 따른 기록 보존
"""
        ),
        PolicySection(
            number: "3",
            title: "개인정보 보유 및 이용 기간",
            body: """
• **서비스 이용 기간**: 회원 탈퇴 시까지 보유
• **탈퇴 후**: 요청일로부터 30일 이내 개인식별 정보 삭제
• **독일·EU 법령에 따른 의무 보존**:
  - 상거래 관련 기록: 6년 (독일 상법 § 257 HGB)
  - 세무 관련 기록: 10년 (독일 조세기본법 § 147 AO)
  - 서비스 로그: 최대 6개월 (DSGVO Art. 5 비례 원칙 적용)

단, 활동 기록 중 타인의 확인(verification)이 완료된 데이터는 해당 협업자의 기록 무결성 보호를 위해 익명화 후 보존될 수 있습니다.
"""
        ),
        PolicySection(
            number: "4",
            title: "개인정보의 제3자 제공",
            body: """
Cadenza는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다.

다만 다음의 경우는 예외입니다.
• 이용자가 사전에 동의한 경우
• 법령의 규정에 의거하거나 수사기관의 적법한 요청이 있는 경우
• 공개 프로필로 설정된 정보는 다른 사용자에게 노출될 수 있습니다.
"""
        ),
        PolicySection(
            number: "5",
            title: "개인정보 처리 위탁",
            body: """
Cadenza는 서비스 운영을 위해 아래 업체에 개인정보 처리를 위탁합니다.

| 수탁 업체 | 위탁 업무 |
| --- | --- |
| Supabase Inc. | 인증·데이터베이스 운영 |
| Fly.io Inc. | 서버 인프라 및 PDF 렌더링 |
| Apple Inc. | 앱 배포 및 알림 서비스(APN) |

수탁 업체는 위탁된 업무 범위 내에서만 개인정보를 처리하며, 제3국에 위치한 경우 적절한 보호 조치를 갖추고 있습니다.
"""
        ),
        PolicySection(
            number: "6",
            title: "이용자의 권리와 행사 방법",
            body: """
이용자는 언제든지 아래 권리를 행사할 수 있습니다.

• **열람 요청**: 본인의 개인정보 처리 현황 확인
• **정정·삭제 요청**: 앱 내 프로필 편집 또는 team@je-jal.com으로 요청
• **처리 정지 요청**: 마케팅 수신 동의 철회 (앱 내 설정)
• **계정 삭제**: 설정 > 계정 삭제 (30일 이내 완전 삭제)
• **데이터 이동성**: 본인 데이터 내보내기 요청 가능 (지원 이메일 통해)

미성년자(만 14세 미만)의 경우 법정 대리인이 권리를 대신 행사할 수 있습니다.
"""
        ),
        PolicySection(
            number: "7",
            title: "개인정보 자동 수집 장치",
            body: """
Cadenza 앱은 서비스 품질 개선을 위해 다음을 사용합니다.

• **오류 로그**: 앱 충돌 및 오류 분석 (기기 식별 불가 익명 데이터)
• **사용 분석**: 화면 이동, 기능 사용 빈도 (집계 통계)

현재 별도의 서드파티 광고 트래킹(IDFA)을 사용하지 않습니다.
"""
        ),
        PolicySection(
            number: "8",
            title: "개인정보 보호책임자",
            body: """
개인정보 처리에 관한 문의, 불만, 피해 구제 신청은 아래로 연락하세요.

**개인정보 보호책임자**
• 성명: Geonho Kim
• 이메일: team@je-jal.com
• 처리 기간: 영업일 기준 3일 이내 회신

**감독기관 신고**
• 연방 개인정보보호·정보자유위원회 (BfDI): www.bfdi.bund.de
• 함부르크 개인정보보호청 (HmbBfDI): www.datenschutz.hamburg.de
"""
        ),
        PolicySection(
            number: "9",
            title: "개인정보처리방침 변경",
            body: """
본 방침은 2026년 10월 1일부터 시행됩니다.

내용이 변경되는 경우 앱 내 알림 또는 이메일로 사전 고지하며, 중요한 변경(수집 항목·목적 변경 등)은 7일 전, 일반 변경은 공지일 즉시 적용됩니다.

이전 버전은 요청 시 제공합니다.

시행일: **2026년 10월 1일**
"""
        ),
    ]}

    // MARK: - English

    private var englishSections: [PolicySection] {[
        PolicySection(
            number: "1",
            title: "Information We Collect",
            body: """
Cadenza collects the following information to provide and improve our service.

**[Required]**
• Name (real name), email address, password (encrypted)
• Major, instrument, school/institution, enrollment/graduation year
• Activity records (performances, competitions, education, repertoire), dates, locations, roles
• Profile photo

**[Optional]**
• Bio, career history, spoken languages
• Contact details (phone, address) — private profile only
• Marketing consent preference

**[Automatically collected]**
• App usage logs, device information, crash logs
• Collaborator tags and verification status
"""
        ),
        PolicySection(
            number: "2",
            title: "How We Use Your Information",
            body: """
• **Account operation**: Sign-up, login, session management
• **Profile services**: Public profile, CV/résumé generation and PDF export
• **Activity records**: Logging, searching, and confirming performance/competition/education history
• **Network features**: Follows, connections, feed, finding collaborators
• **Service improvement**: Error analysis, usage patterns, new feature development
• **Legal compliance**: Record retention as required by applicable law
"""
        ),
        PolicySection(
            number: "3",
            title: "Data Retention",
            body: """
• **During service use**: Data is retained until account deletion.
• **After deletion**: Personally identifiable information is deleted within 30 days of the request.
• **Legally required retention (German/EU law)**:
  - Commercial records: 6 years (German Commercial Code § 257 HGB)
  - Tax-relevant records: 10 years (German Tax Code § 147 AO)
  - Service logs: up to 6 months (GDPR Art. 5 proportionality principle)

Activity records confirmed by collaborators may be anonymized and retained to protect the integrity of other users' records.
"""
        ),
        PolicySection(
            number: "4",
            title: "Third-Party Disclosure",
            body: """
Cadenza does not share your personal information with third parties, except:

• When you have provided prior consent
• When required by law or a lawful request from authorities
• Public profile information you set as visible may be seen by other users
"""
        ),
        PolicySection(
            number: "5",
            title: "Data Processors",
            body: """
We engage the following processors to operate our service:

| Processor | Purpose |
| --- | --- |
| Supabase Inc. | Authentication and database |
| Fly.io Inc. | Server infrastructure and PDF rendering |
| Apple Inc. | App distribution and push notifications (APNs) |

Processors operate only within the scope of their assigned tasks and maintain appropriate safeguards for cross-border transfers.
"""
        ),
        PolicySection(
            number: "6",
            title: "Your Rights",
            body: """
You may exercise the following rights at any time:

• **Access**: View your personal data and how it is processed
• **Correction / Deletion**: Edit your profile in-app, or contact team@je-jal.com
• **Opt-out**: Withdraw marketing consent in app Settings
• **Account deletion**: Settings > Delete account (completed within 30 days)
• **Data portability**: Request an export of your data via support email

Parents or legal guardians may exercise rights on behalf of users under 14 years of age.
"""
        ),
        PolicySection(
            number: "7",
            title: "Automated Data Collection",
            body: """
Cadenza uses the following for service quality:

• **Crash logs**: Anonymous error data to diagnose issues (non-identifiable)
• **Usage analytics**: Screen navigation and feature frequency (aggregated statistics)

We do not use third-party advertising trackers (IDFA) at this time.
"""
        ),
        PolicySection(
            number: "8",
            title: "Contact & Data Protection Officer",
            body: """
For questions, complaints, or data requests, please contact:

**Data Protection Contact**
• Name: Geonho Kim
• Email: team@je-jal.com
• Response time: Within 3 business days

**Supervisory Authorities (GDPR Art. 77)**
• Federal Commissioner for Data Protection (BfDI): www.bfdi.bund.de
• Hamburg Data Protection Authority (HmbBfDI): www.datenschutz.hamburg.de
"""
        ),
        PolicySection(
            number: "9",
            title: "Changes to This Policy",
            body: """
This policy is effective from October 1, 2026.

We will notify you via in-app notice or email before making material changes (collection scope, purpose, etc.) with at least 7 days' notice. Minor changes take effect on the date posted.

Previous versions are available upon request.

Effective date: **October 1, 2026**
"""
        ),
    ]}

    // MARK: - German

    private var germanSections: [PolicySection] {[
        PolicySection(
            number: "1",
            title: "Erhobene Daten",
            body: """
Cadenza erhebt folgende Daten zur Bereitstellung und Verbesserung des Dienstes.

**[Pflichtangaben]**
• Name (Klarname), E-Mail-Adresse, Passwort (verschlüsselt)
• Hauptfach, Instrument, Hochschule/Institution, Immatrikulations-/Abschlussjahr
• Aktivitäten (Auftritte, Wettbewerbe, Unterricht, Repertoire), Daten, Orte, Rollen
• Profilfoto

**[Optionale Angaben]**
• Bio, Berufserfahrung, Sprachen
• Kontaktdaten (Telefon, Adresse) — nur für private Profile
• Marketingeinwilligung

**[Automatisch erhoben]**
• App-Nutzungsprotokolle, Geräteinformationen, Absturzberichte
• Mitwirkenden-Tags und Bestätigungsstatus
"""
        ),
        PolicySection(
            number: "2",
            title: "Zwecke der Verarbeitung",
            body: """
• **Kontobetrieb**: Registrierung, Anmeldung, Sitzungsverwaltung
• **Profildienste**: Öffentliches Profil, CV-Erstellung und PDF-Export
• **Aktivitätsaufzeichnungen**: Erfassung, Suche und Bestätigung von Aufführungs-/Wettbewerbs-/Ausbildungshistorien
• **Netzwerkfunktionen**: Follows, Verbindungen, Feed, Suche nach Mitwirkenden
• **Dienstverbesserung**: Fehleranalyse, Nutzungsmuster, Entwicklung neuer Funktionen
• **Gesetzliche Pflichten**: Aufbewahrung gemäß anwendbarem Recht
"""
        ),
        PolicySection(
            number: "3",
            title: "Speicherdauer",
            body: """
• **Während der Nutzung**: Daten werden bis zur Kontolöschung gespeichert.
• **Nach der Löschung**: Personenbezogene Daten werden innerhalb von 30 Tagen nach Anfrage gelöscht.
• **Gesetzliche Aufbewahrungspflichten**:
  - Handelsrelevante Unterlagen: 6 Jahre (§ 257 HGB)
  - Steuerrelevante Unterlagen: 10 Jahre (§ 147 AO)
  - Servicelogs: maximal 6 Monate (DSGVO Art. 5 Verhältnismäßigkeitsprinzip)

Aktivitätsaufzeichnungen, die von Mitwirkenden bestätigt wurden, können anonymisiert aufbewahrt werden, um die Integrität der Aufzeichnungen anderer Nutzer zu schützen.
"""
        ),
        PolicySection(
            number: "4",
            title: "Weitergabe an Dritte",
            body: """
Cadenza gibt deine personenbezogenen Daten grundsätzlich nicht an Dritte weiter, außer:

• Du hast vorher zugestimmt.
• Es besteht eine gesetzliche Verpflichtung oder eine rechtmäßige Behördenanfrage.
• Öffentlich eingestellte Profilinformationen sind für andere Nutzer sichtbar.
"""
        ),
        PolicySection(
            number: "5",
            title: "Auftragsverarbeiter",
            body: """
Wir setzen folgende Dienstleister ein:

| Anbieter | Zweck |
| --- | --- |
| Supabase Inc. | Authentifizierung und Datenbank |
| Fly.io Inc. | Serverinfrastruktur und PDF-Rendering |
| Apple Inc. | App-Vertrieb und Push-Benachrichtigungen (APNs) |

Auftragsverarbeiter handeln ausschließlich im Rahmen der erteilten Aufgaben und stellen angemessene Schutzmaßnahmen für Drittlandübermittlungen sicher.
"""
        ),
        PolicySection(
            number: "6",
            title: "Deine Rechte",
            body: """
Du hast folgende Rechte (u. a. nach DSGVO):

• **Auskunft**: Einsicht in deine gespeicherten Daten
• **Berichtigung / Löschung**: Profil in der App bearbeiten oder team@je-jal.com kontaktieren
• **Widerspruch**: Marketingeinwilligung in den Einstellungen widerrufen
• **Kontolöschung**: Einstellungen > Konto löschen (innerhalb von 30 Tagen abgeschlossen)
• **Datenübertragbarkeit**: Datenexport auf Anfrage per Support-E-Mail

Erziehungsberechtigte können Rechte für Nutzer unter 14 Jahren wahrnehmen.
"""
        ),
        PolicySection(
            number: "7",
            title: "Automatisierte Datenerhebung",
            body: """
Cadenza verwendet Folgendes zur Qualitätssicherung:

• **Absturzberichte**: Anonyme Fehlerdaten (nicht identifizierbar)
• **Nutzungsanalyse**: Bildschirmnavigation und Funktionshäufigkeit (aggregierte Statistiken)

Wir verwenden derzeit keine Drittanbieter-Werbetracker (IDFA).
"""
        ),
        PolicySection(
            number: "8",
            title: "Datenschutzbeauftragter & Kontakt",
            body: """
Bei Fragen, Beschwerden oder Datenwünschen:

**Datenschutzkontakt**
• Name: Geonho Kim
• E-Mail: team@je-jal.com
• Antwortzeit: Innerhalb von 3 Werktagen

**Zuständige Aufsichtsbehörden (Art. 77 DSGVO)**
• Bundesbeauftragter für den Datenschutz und die Informationsfreiheit (BfDI): www.bfdi.bund.de
• Hamburgischer Beauftragter für Datenschutz und Informationsfreiheit (HmbBfDI): www.datenschutz.hamburg.de
"""
        ),
        PolicySection(
            number: "9",
            title: "Änderungen dieser Erklärung",
            body: """
Diese Erklärung gilt ab dem 1. Oktober 2026.

Wesentliche Änderungen (Umfang der Erhebung, Zweck usw.) werden mindestens 7 Tage im Voraus über eine In-App-Benachrichtigung oder E-Mail angekündigt. Kleinere Änderungen gelten ab Veröffentlichungsdatum.

Ältere Versionen sind auf Anfrage erhältlich.

Gültig ab: **1. Oktober 2026**
"""
        ),
    ]}
}

// MARK: - Shared document renderer

struct PolicySection: Identifiable {
    let number: String
    let title: String
    let body: String
    var id: String { number }
}

struct PolicyDocument: View {
    let sections: [PolicySection]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(section.number)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6))
                        Text(section.title)
                            .font(.headline)
                    }

                    PolicyBodyText(markdown: section.body)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.85))
                        .lineSpacing(4)
                }
            }
        }
    }
}

// Renders simple **bold** markdown inline
struct PolicyBodyText: View {
    let markdown: String

    var body: some View {
        let attributed = try? AttributedString(markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        if let attributed {
            Text(attributed)
        } else {
            Text(markdown)
        }
    }
}
