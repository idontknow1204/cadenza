import SwiftUI

struct TermsOfServiceView: View {
    var isModal: Bool = false
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: String = "ko"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    termsContent
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle(localized("사용자약관", "Terms of Service", "Nutzungsbedingungen"))
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
    private var termsContent: some View {
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
            title: "서비스 개요 및 적용 범위",
            body: """
본 약관은 Cadenza(이하 "서비스")와 이용자 간의 권리·의무 관계를 규정합니다.

서비스는 음악가의 활동 이력 기록, 협업자 확인, 프로필·CV 공유, 커뮤니티 연결을 위한 플랫폼입니다. 서비스에 가입하거나 접근함으로써 본 약관에 동의하는 것으로 간주합니다.

• 서비스 제공자: Cadenza (개인 개발자, kimgeonho0327@gmail.com)
• 적용 범위: iOS 앱, 공개 웹 프로필(fermata.app), API 서비스 전체
• 최소 이용 연령: 만 14세 이상
"""
        ),
        PolicySection(
            number: "2",
            title: "이용 계약의 성립",
            body: """
1. 이용자가 약관 동의 후 회원가입을 완료하면 이용 계약이 성립합니다.
2. 만 14세 미만은 법정 대리인의 동의 없이 가입할 수 없습니다.
3. 서비스는 다음의 경우 가입을 거부하거나 계약을 해지할 수 있습니다.
   - 타인의 정보를 도용한 경우
   - 이전 이용 정지·강제 탈퇴 이력이 있는 경우
   - 기타 법령 위반 또는 약관 위배가 명확한 경우
4. 하나의 실명으로 하나의 계정만 운영할 수 있습니다.
"""
        ),
        PolicySection(
            number: "3",
            title: "서비스 이용",
            body: """
**제공 서비스**
• 공연·콩쿠르·교육 활동의 기록 및 관리
• 협업자 태그 및 확인(verification) 요청
• 공개 프로필 및 CV 생성·내보내기
• 음악가 네트워크 탐색·연결

**이용자의 의무**
• 이용자는 본인의 계정 보안(비밀번호 관리 등)에 책임이 있습니다.
• 본인이 실제 참여하거나 사실에 기반한 활동만 기록해야 합니다.
• 타인의 이미지, 음원, 저작물은 권리자의 허락 없이 게시할 수 없습니다.
• 계정 공유·양도는 허용되지 않습니다.
"""
        ),
        PolicySection(
            number: "4",
            title: "금지 행위",
            body: """
이용자는 다음 행위를 해서는 안 됩니다.

**정보의 진실성 위반**
• 허위 활동 기록, 과장된 이력, 타인의 성과 도용
• 학교·기관·연주자 사칭 또는 허위 소속 표기

**타인 피해 행위**
• 타인에 대한 괴롭힘, 차별, 혐오 표현
• 협업자 태그 기능을 악용한 무단 정보 노출
• 허위 확인(verification) 요청 또는 허위 거부

**시스템 침해**
• 자동화 프로그램(봇)을 이용한 계정 생성·조작
• 서비스 크롤링, 역공학, 비인가 API 접근
• 다른 이용자의 계정 정보 탈취 시도

위반 시 경고, 이용 제한, 계정 삭제 등의 조치가 취해질 수 있습니다.
"""
        ),
        PolicySection(
            number: "5",
            title: "콘텐츠와 지식재산권",
            body: """
**이용자 콘텐츠**
이용자가 업로드한 텍스트, 이미지, 활동 데이터의 저작권은 이용자에게 있습니다.

다만 이용자는 서비스 운영에 필요한 범위(프로필 표시, 검색 색인, PDF 생성 등)에서 비독점적·무상 사용 권한을 서비스에 부여합니다.

**서비스 콘텐츠**
Cadenza의 로고, 디자인, 코드, 기능, UI 요소는 서비스 또는 제3자 권리자의 소유이며 무단 복제·배포를 금합니다.

**확인(Verification) 데이터**
협업자의 확인을 완료한 데이터는 해당 협업자의 동의 하에 공개 프로필에 표시될 수 있으며, 기록의 무결성 보호를 위해 일정 기간 유지될 수 있습니다.
"""
        ),
        PolicySection(
            number: "6",
            title: "면책 및 책임 한계",
            body: """
• 서비스는 이용자가 등록한 활동 정보의 정확성을 보증하지 않으며, 협업자 확인은 공식 기관 증명서를 대체하지 않습니다.
• 서비스는 이용자 간 분쟁, 저작권 침해 주장, 허위 정보에 대해 직접적인 법적 책임을 부담하지 않습니다.
• 서비스는 천재지변, 해킹, 제3자 서비스(Supabase, Fly.io 등) 장애로 인한 데이터 손실에 대해 과실 없는 한 책임을 지지 않습니다.
• 이용자가 본 약관을 위반하여 발생한 손해에 대해서는 이용자가 책임집니다.
"""
        ),
        PolicySection(
            number: "7",
            title: "서비스 변경 및 중단",
            body: """
• 서비스는 기능 추가·변경·삭제를 예고 없이 할 수 있습니다. 단, 중요한 변경(유료화, 데이터 삭제 등)은 30일 전 이상 사전 공지합니다.
• 점검, 긴급 장애 대응, 운영 정책상 이유로 서비스가 일시 중단될 수 있습니다.
• 서비스 종료 시 30일 이상의 사전 공지 후 데이터 내보내기 기간을 제공합니다.
"""
        ),
        PolicySection(
            number: "8",
            title: "계정 정지 및 해지",
            body: """
**이용자 자발적 탈퇴**
설정 > 계정 삭제를 통해 언제든지 탈퇴할 수 있습니다. 탈퇴 후 30일 이내 개인정보가 삭제됩니다.

**서비스 측 조치**
다음의 경우 사전 통보 없이 이용 제한 또는 계정 삭제 조치가 취해질 수 있습니다.
• 약관 4조(금지 행위)에 해당하는 경우
• 법원·수사기관의 요청이 있는 경우
• 장기 미사용(2년 이상) 계정의 경우 (30일 전 사전 공지)

조치에 이의가 있는 경우 team@je-jal.com으로 이의 신청할 수 있습니다.
"""
        ),
        PolicySection(
            number: "9",
            title: "분쟁 해결 및 준거법",
            body: """
• 본 약관은 독일 연방법(BGB, DSGVO 등 EU 법령 포함)에 따라 해석·적용됩니다.
• 분쟁이 발생한 경우 먼저 이메일(team@je-jal.com)을 통한 협의를 시도합니다.
• 협의가 이루어지지 않을 경우 독일 함부르크 관할 법원을 1심 전속 관할 법원으로 합니다.
• EU 소비자 이용자의 경우 거주 국가의 강행적 소비자 보호 규정이 우선 적용될 수 있습니다.
• 개인정보 관련 이의는 연방 개인정보보호청(BfDI) 또는 함부르크 개인정보보호청(HmbBfDI)에 제기할 수 있습니다.

시행일: **2026년 10월 1일**
"""
        ),
    ]}

    // MARK: - English

    private var englishSections: [PolicySection] {[
        PolicySection(
            number: "1",
            title: "Service Overview and Scope",
            body: """
These Terms govern the relationship between Cadenza (the "Service") and you as a user.

The Service is a platform for musicians to record activity history, confirm collaborations, share profiles and CVs, and build professional networks. By registering or accessing the Service, you agree to these Terms.

• **Provider**: Cadenza (independent developer, kimgeonho0327@gmail.com)
• **Scope**: iOS app, public web profiles (fermata.app), and all API services
• **Minimum age**: 14 years old
"""
        ),
        PolicySection(
            number: "2",
            title: "Account Creation",
            body: """
1. An agreement is formed when you complete registration after accepting these Terms.
2. Users under 14 may not register without parental or guardian consent.
3. The Service may refuse registration or terminate accounts if:
   - You used another person's information
   - You have a prior suspension or forced deletion history
   - Clear violations of law or these Terms are apparent
4. Each real person may operate only one account.
"""
        ),
        PolicySection(
            number: "3",
            title: "Using the Service",
            body: """
**Available features**
• Recording and managing performances, competitions, and education activities
• Collaborator tags and verification requests
• Public profile and CV generation and export
• Discovering and connecting with musicians

**Your responsibilities**
• You are responsible for your account security (password management, etc.)
• You may only record activities you personally participated in or can substantiate
• You may not post others' images, recordings, or works without the rights holder's permission
• Account sharing or transfer is not permitted
"""
        ),
        PolicySection(
            number: "4",
            title: "Prohibited Conduct",
            body: """
The following are prohibited:

**Accuracy violations**
• False activity records, inflated credentials, misappropriating others' achievements
• Impersonating schools, institutions, or artists; false affiliation claims

**Harm to others**
• Harassment, discrimination, or hate speech toward other users
• Misusing the collaborator tag feature to expose others' information without consent
• Submitting false verification requests or falsely denying legitimate ones

**System integrity**
• Creating or manipulating accounts with automated tools (bots)
• Scraping, reverse engineering, or unauthorized API access
• Attempting to obtain other users' account credentials

Violations may result in warnings, service restrictions, or account deletion.
"""
        ),
        PolicySection(
            number: "5",
            title: "Content and Intellectual Property",
            body: """
**User content**
You retain copyright over text, images, and activity data you upload.

You grant the Service a non-exclusive, royalty-free license to use your content as necessary to operate the service (displaying profiles, search indexing, PDF generation, etc.).

**Service content**
Cadenza's logo, design, code, features, and UI elements are owned by the Service or third-party rights holders. Unauthorized reproduction or distribution is prohibited.

**Verification data**
Data confirmed by collaborators may appear on public profiles with their consent and may be retained for a period to protect record integrity.
"""
        ),
        PolicySection(
            number: "6",
            title: "Disclaimers and Liability Limits",
            body: """
• The Service does not guarantee the accuracy of user-submitted activity data; collaborator verification does not replace official institutional certification.
• The Service is not directly liable for disputes between users, copyright claims, or false information.
• The Service is not liable (absent negligence) for data loss caused by force majeure, hacking, or third-party service failures (Supabase, Fly.io, etc.).
• Users are responsible for damages arising from their own violations of these Terms.
"""
        ),
        PolicySection(
            number: "7",
            title: "Service Changes and Interruptions",
            body: """
• Features may be added, changed, or removed without notice. Material changes (monetization, data deletion, etc.) will be announced at least 30 days in advance.
• The Service may be temporarily suspended for maintenance, emergency fixes, or operational reasons.
• If the Service is discontinued, at least 30 days' advance notice will be given with a data export period.
"""
        ),
        PolicySection(
            number: "8",
            title: "Account Suspension and Termination",
            body: """
**Voluntary termination**
You may delete your account at any time via Settings > Delete account. Personal data is deleted within 30 days.

**Service-initiated action**
Restrictions or account deletion may occur without prior notice if:
• Prohibited conduct under Section 4 occurs
• Requested by courts or law enforcement
• Account has been inactive for 2+ years (30 days' notice given)

You may appeal account actions by contacting team@je-jal.com.
"""
        ),
        PolicySection(
            number: "9",
            title: "Dispute Resolution and Governing Law",
            body: """
• These Terms are governed by the laws of Germany and applicable EU regulations (including BGB and GDPR).
• We will first attempt to resolve disputes by email at team@je-jal.com.
• Unresolved disputes are subject to the exclusive jurisdiction of the courts of Hamburg, Germany.
• EU consumers retain the benefit of any mandatory consumer protection provisions of their country of residence.
• Data protection complaints may be filed with the BfDI (www.bfdi.bund.de) or the HmbBfDI (www.datenschutz.hamburg.de).

Effective date: **October 1, 2026**
"""
        ),
    ]}

    // MARK: - German

    private var germanSections: [PolicySection] {[
        PolicySection(
            number: "1",
            title: "Dienstbeschreibung und Geltungsbereich",
            body: """
Diese Nutzungsbedingungen regeln das Verhältnis zwischen Cadenza (dem „Dienst") und dir als Nutzer.

Der Dienst ist eine Plattform für Musiker, um Aktivitäten zu dokumentieren, Mitwirkende zu bestätigen, Profile und Lebensläufe zu teilen und professionelle Netzwerke aufzubauen. Mit der Registrierung oder Nutzung des Dienstes stimmst du diesen Bedingungen zu.

• **Anbieter**: Cadenza (unabhängiger Entwickler, kimgeonho0327@gmail.com)
• **Geltungsbereich**: iOS-App, öffentliche Webprofile (fermata.app) und alle API-Dienste
• **Mindestalter**: 14 Jahre
"""
        ),
        PolicySection(
            number: "2",
            title: "Vertragsschluss",
            body: """
1. Ein Vertrag kommt zustande, wenn du nach Zustimmung zu diesen Bedingungen die Registrierung abschließt.
2. Nutzer unter 14 Jahren dürfen sich nicht ohne Einwilligung eines Erziehungsberechtigten registrieren.
3. Der Dienst kann die Registrierung ablehnen oder Verträge kündigen bei:
   - Verwendung fremder Daten
   - Vorheriger Sperrung oder erzwungener Löschung
   - Klaren Verstößen gegen Recht oder diese Bedingungen
4. Jede reale Person darf nur ein Konto führen.
"""
        ),
        PolicySection(
            number: "3",
            title: "Nutzung des Dienstes",
            body: """
**Verfügbare Funktionen**
• Aufzeichnung und Verwaltung von Auftritten, Wettbewerben und Ausbildungsaktivitäten
• Mitwirkenden-Tags und Bestätigungsanfragen
• Öffentliches Profil und Lebenslauferstellung sowie PDF-Export
• Entdeckung von und Vernetzung mit Musikern

**Deine Pflichten**
• Du trägst die Verantwortung für die Sicherheit deines Kontos
• Du darfst nur Aktivitäten eintragen, an denen du tatsächlich teilgenommen hast
• Du darfst keine Bilder, Aufnahmen oder Werke Dritter ohne Erlaubnis veröffentlichen
• Kontoteilung oder -übertragung ist nicht gestattet
"""
        ),
        PolicySection(
            number: "4",
            title: "Verbotene Handlungen",
            body: """
Folgende Handlungen sind untersagt:

**Verstöße gegen die Richtigkeit**
• Falsche Aktivitätsaufzeichnungen, aufgeblähte Referenzen, Aneignung fremder Leistungen
• Vortäuschung einer anderen Identität als Hochschule, Institution oder Künstler

**Schädigung anderer**
• Belästigung, Diskriminierung oder Hassreden gegenüber anderen Nutzern
• Missbrauch der Tag-Funktion zur unerlaubten Offenlegung fremder Informationen
• Falsche Bestätigungsanfragen oder unberechtigte Ablehnungen

**Systemintegrität**
• Kontoerstellung oder -manipulation durch automatisierte Tools (Bots)
• Scraping, Reverse Engineering oder unautorisierter API-Zugriff
• Versuche, Kontodaten anderer Nutzer zu erlangen

Verstöße können zu Verwarnungen, Einschränkungen oder Kontolöschung führen.
"""
        ),
        PolicySection(
            number: "5",
            title: "Inhalte und geistiges Eigentum",
            body: """
**Nutzerinhalte**
Du behältst das Urheberrecht an von dir hochgeladenem Text, Bildern und Aktivitätsdaten.

Du räumst dem Dienst eine nicht-exklusive, kostenlose Lizenz ein, soweit dies für den Betrieb erforderlich ist (Profilanzeige, Suchindexierung, PDF-Erstellung usw.).

**Dienst-Inhalte**
Logo, Design, Code, Funktionen und UI-Elemente von Cadenza sind Eigentum des Dienstes oder Dritter. Unbefugte Vervielfältigung oder Verbreitung ist untersagt.

**Bestätigungsdaten**
Von Mitwirkenden bestätigte Daten können mit deren Einwilligung im öffentlichen Profil angezeigt und zum Schutz der Aufzeichnungsintegrität für eine gewisse Zeit aufbewahrt werden.
"""
        ),
        PolicySection(
            number: "6",
            title: "Haftungsausschluss und Haftungsbeschränkung",
            body: """
• Der Dienst übernimmt keine Garantie für die Richtigkeit nutzereigener Aktivitätsdaten; Bestätigungen ersetzen keine offiziellen Nachweise.
• Der Dienst haftet nicht direkt für Nutzerstreitigkeiten, Urheberrechtsverletzungen oder falsche Informationen.
• Der Dienst haftet nicht (ohne Verschulden) für Datenverluste durch höhere Gewalt, Hacking oder Ausfälle von Drittanbietern (Supabase, Fly.io usw.).
• Nutzer haften für Schäden, die durch eigene Verstöße gegen diese Bedingungen entstehen.
"""
        ),
        PolicySection(
            number: "7",
            title: "Änderungen und Unterbrechungen",
            body: """
• Funktionen können ohne Vorankündigung hinzugefügt, geändert oder entfernt werden. Wesentliche Änderungen (Monetarisierung, Datenlöschung usw.) werden mindestens 30 Tage im Voraus angekündigt.
• Der Dienst kann vorübergehend für Wartung, Notfallbehebungen oder betriebliche Gründe unterbrochen werden.
• Bei Einstellung des Dienstes wird mindestens 30 Tage vorher informiert und eine Datenexportperiode angeboten.
"""
        ),
        PolicySection(
            number: "8",
            title: "Kontosperrung und Kündigung",
            body: """
**Freiwillige Kündigung**
Du kannst dein Konto jederzeit über Einstellungen > Konto löschen löschen. Personenbezogene Daten werden innerhalb von 30 Tagen gelöscht.

**Maßnahmen durch den Dienst**
Einschränkungen oder Löschungen können ohne vorherige Ankündigung erfolgen bei:
• Verstößen gemäß Abschnitt 4
• Anfragen von Behörden oder Strafverfolgungsbehörden
• Inaktivität von 2+ Jahren (mit 30 Tagen Vorankündigung)

Gegen Maßnahmen kannst du Widerspruch per team@je-jal.com einlegen.
"""
        ),
        PolicySection(
            number: "9",
            title: "Streitbeilegung und anwendbares Recht",
            body: """
• Diese Bedingungen unterliegen deutschem Recht sowie dem anwendbaren EU-Recht (einschließlich BGB und DSGVO).
• Streitigkeiten werden zunächst per E-Mail unter team@je-jal.com zu lösen versucht.
• Nicht gelöste Streitigkeiten unterliegen der ausschließlichen Zuständigkeit der Gerichte in Hamburg, Deutschland.
• Verbraucher in der EU behalten den Schutz zwingender Verbraucherschutzvorschriften ihres Wohnsitzlandes.
• Datenschutzbeschwerden können beim BfDI (www.bfdi.bund.de) oder beim HmbBfDI (www.datenschutz.hamburg.de) eingereicht werden.

Gültig ab: **1. Oktober 2026**
"""
        ),
    ]}
}
