import SwiftUI

struct JobDetailView: View {
    let job: Job
    var onClosed: () -> Void = {}

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var showCloseConfirm = false
    @State private var closing = false
    @State private var copied = false
    @State private var closeError: String?

    private var isOwner: Bool { job.userId.map { $0 == session.currentUserID } ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        typeChip
                        Spacer()
                        JobDeadlineBadge(job: job)
                    }

                    Text(job.title)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    if let org = job.organization, !org.isEmpty {
                        Text(org).font(.headline).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if let loc = job.location, !loc.isEmpty {
                            Label(loc, systemImage: "mappin.circle")
                        }
                        if let deadline = job.deadline {
                            Label(localized("마감일 \(deadline)", "Deadline \(deadline)", "Bewerbungsfrist \(deadline)"),
                                  systemImage: "calendar")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    if !job.instruments.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(job.instruments, id: \.self) { inst in
                                Text(OnboardingData.instrumentDisplay(inst))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))

                PostSeparator()

                // ── Body sections ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 0) {
                    if !opportunityFacts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(localized("지원 정보", "Application information", "Bewerbungsinformationen"))
                                .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                            ForEach(opportunityFacts, id: \.self) { fact in
                                Text(fact).font(.subheadline)
                            }
                        }
                        .padding(16)
                        Divider().padding(.horizontal, 16)
                    }
                    detailSection(localized("상세 내용", "Details", "Details"), text: job.description)

                    if let req = job.requirements, !req.isEmpty {
                        Divider().padding(.horizontal, 16)
                        detailSection(localized("지원 자격", "Requirements", "Voraussetzungen"), text: req)
                    }

                    if let contact = job.contact, !contact.isEmpty {
                        Divider().padding(.horizontal, 16)
                        detailSection(localized("지원 방법 / 연락처", "How to apply / contact", "Bewerbung / Kontakt"), text: contact)
                    }

                    if job.isCurated, let sourceURL = job.sourceURL, let url = URL(string: sourceURL) {
                        Divider().padding(.horizontal, 16)
                        Link(destination: url) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(localized("공식 원문", "Official source", "Offizielle Quelle"))
                                        .font(.subheadline.weight(.semibold))
                                    Text(url.host ?? sourceURL)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                            }
                            .padding(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color(.systemBackground))

                PostSeparator()

                // ── Poster info ───────────────────────────────────────
                if !job.isCurated, let poster = job.poster {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.accentColor.opacity(0.12))
                            Text(poster.realName.prefix(2))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(poster.realName).font(.subheadline.weight(.medium))
                            if let inst = poster.instrument {
                                Text(OnboardingData.instrumentDisplay(inst)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(localized("게시자", "Posted by", "Veröffentlicht von")).font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                }

                // ── Owner close button ────────────────────────────────
                if isOwner && job.isActive {
                    Button {
                        showCloseConfirm = true
                    } label: {
                        Text(closing ? localized("처리 중…", "Closing…", "Wird geschlossen…") : localized("공고 마감 처리", "Close opportunity", "Ausschreibung schließen"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .disabled(closing)
                }
            }
            .adaptiveContentWidth()
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle(localized("공고 상세", "Opportunity", "Ausschreibung"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if let value = job.applicationURL ?? job.sourceURL, let url = URL(string: value) {
                officialApplyButton(url: url)
            } else if let contact = job.contact, !contact.isEmpty {
                applyButton(contact: contact)
            }
        }
        .alert(localized("공고를 마감 처리하시겠어요?", "Close this opportunity?", "Ausschreibung schließen?"), isPresented: $showCloseConfirm) {
            Button(localized("마감", "Close", "Schließen"), role: .destructive) { Task { await closeJob() } }
            Button(localized("취소", "Cancel", "Abbrechen"), role: .cancel) { }
        }
        .alert(localized("마감 처리 실패", "Couldn’t close opportunity", "Schließen fehlgeschlagen"), isPresented: Binding(get: { closeError != nil }, set: { _ in closeError = nil })) {
            Button(localized("확인", "OK", "OK")) { closeError = nil }
        } message: { Text(closeError ?? "") }
    }

    // MARK: - Subviews

    private var opportunityFacts: [String] {
        var facts: [String] = []
        if job.videoAudition == true {
            facts.append(localized("영상 예선 가능", "Video round available", "Video-Vorrunde möglich"))
        }
        if job.applicationFee == 0 {
            facts.append(localized("지원료 없음", "No application fee", "Keine Bewerbungsgebühr"))
        }
        if job.hasScholarship == true {
            facts.append(localized("장학금 있음", "Scholarship available", "Stipendium verfügbar"))
        }
        if let start = job.eventStart {
            let period = start + (job.eventEnd.map { " – " + $0 } ?? "")
            facts.append(localized("진행 일정: \(period)", "Event dates: \(period)", "Zeitraum: \(period)"))
        }
        if let min = job.ageMin, let max = job.ageMax {
            facts.append(localized("지원 연령: \(min)–\(max)세", "Age: \(min)–\(max)", "Alter: \(min)–\(max)"))
        } else if let min = job.ageMin {
            facts.append(localized("지원 연령: \(min)세 이상", "Minimum age: \(min)", "Mindestalter: \(min)"))
        } else if let max = job.ageMax {
            facts.append(localized("지원 연령: \(max)세 이하", "Maximum age: \(max)", "Höchstalter: \(max)"))
        }
        return facts
    }

    private var typeChip: some View {
        HStack(spacing: 4) {
            Image(systemName: job.type.symbol).font(.caption2)
            Text(job.type.label).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Color("BrandSurface"), in: RoundedRectangle(cornerRadius: 6))
        .foregroundStyle(Color.accentColor)
    }

    private func detailSection(_ heading: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .textSelection(.enabled)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }

    private func applyButton(contact: String) -> some View {
        Button {
            UIPasteboard.general.string = contact
            copied = true
        } label: {
            HStack {
                Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                Text(copied ? localized("연락처 복사 완료", "Contact copied", "Kontakt kopiert") : localized("연락처 복사", "Copy contact", "Kontakt kopieren"))
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: copied)
        .task(id: copied) {
            guard copied else { return }
            do { try await Task.sleep(for: .seconds(3)); copied = false } catch {}
        }
        .background(Color(.systemBackground))
    }

    private func officialApplyButton(url: URL) -> some View {
        Link(destination: url) {
            Text(localized("공식 페이지에서 지원", "Apply on official page", "Auf offizieller Seite bewerben"))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func closeJob() async {
        closing = true
        defer { closing = false }
        do {
            try await session.repo.closeJob(id: job.id)
            onClosed()
            dismiss()
        } catch {
            closeError = error.localizedDescription
        }
    }
}
