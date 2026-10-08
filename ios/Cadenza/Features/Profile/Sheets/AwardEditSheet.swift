import SwiftUI

struct AwardEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    let existing: ProfileAward?
    var onSave: (ProfileAward) -> Void = { _ in }
    var onDelete: (UUID) -> Void = { _ in }

    @State private var title = ""
    @State private var prize = ""
    @State private var issuer = ""
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var details = ""
    @State private var linkUrl = ""
    @State private var busy = false
    @State private var showDelete = false
    @State private var errorText: String?

    private var years: [Int] {
        Array((1900...max(year, Calendar.current.component(.year, from: Date()))).reversed())
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !prize.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("수상 정보", "Award details", "Angaben zur Auszeichnung")) {
                    TextField(localized("대회명", "Competition name", "Wettbewerb"), text: $title)
                    TextField(localized("수상 내역 (예: 1위, 금상, 특별상)", "Prize (e.g. 1st place, Gold, Special award)", "Preis (z. B. 1. Platz, Gold, Sonderpreis)"), text: $prize)
                    TextField(localized("주최 / 수여 기관 (선택)", "Issuing organization (optional)", "Verleihende Institution (optional)"), text: $issuer)
                    Picker(localized("수상 연도", "Year awarded", "Jahr der Auszeichnung"), selection: $year) {
                        ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                    }
                }
                Section(localized("상세 내용 (선택)", "Description (optional)", "Beschreibung (optional)")) {
                    TextField(localized("부문, 연주곡, 주요 성과", "Category, repertoire, achievements", "Kategorie, Repertoire, Leistungen"), text: $details, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section(localized("증빙 링크 (선택)", "Supporting link (optional)", "Nachweislink (optional)")) {
                    TextField(localized("관련 링크 URL", "Related URL", "Zugehoerige URL"), text: $linkUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if existing != nil {
                    Section {
                        Button("common.delete", role: .destructive) { showDelete = true }
                    }
                }
            }
            .disabled(busy)
            .navigationTitle(existing == nil
                ? localized("수상 경력 추가", "Add award", "Auszeichnung hinzufuegen")
                : localized("수상 경력 수정", "Edit award", "Auszeichnung bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }.disabled(busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button("profile.edit.save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(busy)
            .onAppear(perform: load)
            .confirmationDialog("common.delete.confirm", isPresented: $showDelete, titleVisibility: .visible) {
                Button("common.delete", role: .destructive) { Task { await delete() } }
                Button("common.cancel", role: .cancel) {}
            }
            .alert("error.title", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("common.ok") { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func load() {
        guard let award = existing else { return }
        title = award.title
        prize = award.prize
        issuer = award.issuer
        year = award.year
        details = award.details
        linkUrl = award.linkUrl
    }

    private func save() async {
        guard canSave, !busy, let me = session.currentUserID else { return }
        guard let link = ProfileAward.normalizedLink(linkUrl) else {
            errorText = localized("올바른 웹 링크를 입력해 주세요.", "Enter a valid web link.", "Bitte einen gueltigen Weblink eingeben.")
            return
        }
        busy = true
        defer { busy = false }
        let award = ProfileAward(
            id: existing?.id ?? UUID(), userId: me,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            prize: prize.trimmingCharacters(in: .whitespacesAndNewlines),
            issuer: issuer.trimmingCharacters(in: .whitespacesAndNewlines),
            year: year, details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            linkUrl: link
        )
        do {
            let saved: ProfileAward
            if existing == nil { saved = try await session.repo.insertAward(award) }
            else { saved = try await session.repo.updateAward(award) }
            onSave(saved)
            dismiss()
        } catch {
            errorText = localized("수상 경력을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요.", "Unable to save this award. Please try again.", "Die Auszeichnung konnte nicht gespeichert werden. Bitte erneut versuchen.")
        }
    }

    private func delete() async {
        guard !busy, let award = existing, let me = session.currentUserID else { return }
        busy = true
        defer { busy = false }
        do {
            try await session.repo.deleteAward(id: award.id, userId: me)
            onDelete(award.id)
            dismiss()
        } catch {
            errorText = localized("수상 경력을 삭제하지 못했습니다. 잠시 후 다시 시도해 주세요.", "Unable to delete this award. Please try again.", "Die Auszeichnung konnte nicht geloescht werden. Bitte erneut versuchen.")
        }
    }
}

struct ProfileAwardRow: View {
    let award: ProfileAward
    var showsDisclosure = false
    var interactiveLinks = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color("BrandGold"))
                .frame(width: 40, height: 40)
                .background(Color("BrandGold").opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(award.title).font(.body.weight(.semibold))
                Text(award.prize).font(.subheadline.weight(.medium)).foregroundStyle(Color.accentColor)
                if !award.issuer.isEmpty {
                    Text(award.issuer).font(.footnote).foregroundStyle(.secondary)
                }
                Text(String(award.year)).font(.footnote).foregroundStyle(.secondary)
                if !award.details.isEmpty {
                    Text(award.details).font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !award.linkUrl.isEmpty {
                    CareerAttachmentRow(
                        title: localized("증빙 링크", "Supporting link", "Nachweislink"),
                        icon: "link", urlString: award.linkUrl, interactive: interactiveLinks
                    )
                    .padding(.top, 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsDisclosure {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}
