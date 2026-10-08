import SwiftUI

struct Step1ConsentView: View {
    let coordinator: OnboardingCoordinator

    @AppStorage("appLanguage") private var appLanguage: String = "ko"
    @State private var agreedPrivacy  = false
    @State private var agreedTerms    = false
    @State private var agreedMarketing = false
    @State private var showPrivacy    = false
    @State private var showTerms      = false

    private var allRequired: Bool { agreedPrivacy && agreedTerms }
    private var allChecked:  Bool { agreedPrivacy && agreedTerms && agreedMarketing }

    // MARK: - Localization

    private var heading: String   { localized("서비스를 시작하기 전에\n약관에 동의해 주세요", "Before you begin,\nplease agree to our terms", "Bevor du loslegst,\nbitte stimme zu") }
    private var subTitle: String  { localized("Cadenza를 안전하게 사용하기 위한 필수 동의 사항입니다.", "Required agreements to use Cadenza safely.", "Pflichtangaben zur sicheren Nutzung von Cadenza.") }
    private var allAgree: String  { localized("모두 동의", "Agree to all", "Allem zustimmen") }
    private var ctaLabel: String  { localized("동의하고 시작하기", "Agree and continue", "Zustimmen und weiter") }
    private var reqLabel: String  { localized("필수", "Required", "Pflicht") }
    private var optLabel: String  { localized("선택", "Optional", "Optional") }
    private var privacyTitle: String { localized("개인정보 처리방침 동의", "Privacy policy", "Datenschutzerklärung") }
    private var termsTitle: String   { localized("서비스 이용약관 동의", "Terms of service", "Nutzungsbedingungen") }
    private var marketingTitle: String { localized("마케팅 정보 수신 동의", "Receive marketing updates", "Marketingnachrichten erhalten") }
    private var marketingSub: String   { localized("신기능 소식과 음악 커뮤니티 업데이트를 받습니다.", "Get new feature updates and music community news.", "Neuigkeiten zu Funktionen und der Musikgemeinschaft.") }
    private var viewLabel: String { localized("보기", "View", "Ansehen") }
    private var ageNote: String { localized("계속하면 만 14세 이상임을 확인하는 것입니다.", "By continuing you confirm you are at least 14 years old.", "Mit Fortfahren bestätigst du, mindestens 14 Jahre alt zu sein.") }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Icon + Heading ─────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: 56, height: 56)
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 26, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(.bottom, 4)

                        Text(heading)
                            .font(.system(size: 26, weight: .bold))
                            .lineSpacing(3)

                        Text(subTitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 32)

                    // ── All-agree ──────────────────────────────────
                    Button {
                        let next = !allChecked
                        withAnimation(.easeInOut(duration: 0.15)) {
                            agreedPrivacy   = next
                            agreedTerms     = next
                            agreedMarketing = next
                        }
                    } label: {
                        HStack(spacing: 14) {
                            allAgreeBadge
                            Text(allAgree)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    // ── Divider ────────────────────────────────────
                    Divider()
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)

                    // ── Consent items ──────────────────────────────
                    VStack(spacing: 12) {
                        consentRow(
                            checked: $agreedPrivacy,
                            title: privacyTitle,
                            badge: reqLabel,
                            badgeColor: .red,
                            showDetail: { showPrivacy = true }
                        )
                        consentRow(
                            checked: $agreedTerms,
                            title: termsTitle,
                            badge: reqLabel,
                            badgeColor: .red,
                            showDetail: { showTerms = true }
                        )
                        consentRow(
                            checked: $agreedMarketing,
                            title: marketingTitle,
                            subtitle: marketingSub,
                            badge: optLabel,
                            badgeColor: .secondary,
                            showDetail: nil
                        )
                    }
                    .padding(.horizontal, 20)

                    // ── Age note ───────────────────────────────────
                    Text(ageNote)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                        .padding(.bottom, 8)
                }
                .adaptiveContentWidth()
            }

            // ── Bottom CTA ─────────────────────────────────────
            VStack(spacing: 0) {
                Divider()
                Button {
                    Task { await coordinator.advanceFromConsent() }
                } label: {
                    Group {
                        if coordinator.isBusy { ProgressView().tint(.white) }
                        else { Text(ctaLabel).fontWeight(.semibold).frame(maxWidth: .infinity) }
                    }
                    .frame(height: 52)
                    .frame(maxWidth: .infinity)
                }
                .background(
                    (!allRequired || coordinator.isBusy) ? Color.accentColor.opacity(0.3) : Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
                .disabled(!allRequired || coordinator.isBusy)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .adaptiveContentWidth()
        }
        .sheet(isPresented: $showPrivacy) { PrivacyPolicyView(isModal: true) }
        .sheet(isPresented: $showTerms)   { TermsOfServiceView(isModal: true) }
        .background(Color(.systemBackground))
    }

    // MARK: - Subviews

    private var allAgreeBadge: some View {
        ZStack {
            Circle()
                .strokeBorder(allChecked ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1.5)
                .background(Circle().fill(allChecked ? Color.accentColor : Color.clear))
                .frame(width: 24, height: 24)
            if allChecked {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private func consentRow(
        checked: Binding<Bool>,
        title: String,
        subtitle: String? = nil,
        badge: String,
        badgeColor: Color,
        showDetail: (() -> Void)?
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Button { withAnimation(.easeInOut(duration: 0.15)) { checked.wrappedValue.toggle() } } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(checked.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(checked.wrappedValue ? Color.accentColor : Color.clear))
                        .frame(width: 22, height: 22)
                    if checked.wrappedValue {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(badge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(badgeColor == .secondary ? Color.secondary : .white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(badgeColor == .secondary ? Color.secondary.opacity(0.15) : badgeColor, in: Capsule())
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 4)

            if let showDetail {
                Button(action: showDetail) {
                    Text(viewLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
