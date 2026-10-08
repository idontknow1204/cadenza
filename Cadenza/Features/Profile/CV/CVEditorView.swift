import SwiftUI

// Fermata CV 편집기 — DB의 한글 커리어 데이터를 영어 에디토리얼 CV(PDF/웹)로 내보내기 위한
// 편집 표면. 렌더/매핑은 서버(cv_data + render-service)가 하고, 여기선 CV 전용 값만 편집한다:
//   • name_en / eyebrow / birth_date / phone / address  (profiles)
//   • repertoire (profiles.repertoire, 큐레이션)
//   • 항목별 영어 오버레이 + 포함 여부 (cv_i18n)  → CVEntryOverrideView
struct CVEditorView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var nameEn = ""
    @State private var eyebrow = ""
    @State private var birthDate: Date? = nil
    @State private var phone = ""
    @State private var address = ""
    @State private var repertoire: [String] = []
    @State private var newRepItem = ""

    @State private var entries: [CVEntry] = []
    @State private var overrides: [String: CVOverride] = [:]   // key = "kind:id"
    @State private var cvEntries: [CVEntryRow] = []
    @State private var composer: ComposerTarget?

    @State private var loading = true
    @State private var busy = false
    @State private var exporting = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                introSection
                identitySection
                repertoireSection
                cvEntriesSection
                entriesSection
                exportSection
            }
            .sheet(item: $composer) { t in
                CVEntryComposerView(existing: t.existing, initialKind: t.kind) {
                    Task { await load() }
                }
            }
            .navigationTitle(localized("CV / 이력서", "CV", "Lebenslauf"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("닫기", "Done", "Fertig")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() }
                    else { Button(localized("저장", "Save", "Speichern")) { Task { await save() } }
                        .fontWeight(.semibold) }
                }
            }
            .alert(localized("오류", "Error", "Fehler"),
                   isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) {
                Button(localized("확인", "OK", "OK")) { errorText = nil }
            } message: { Text(errorText ?? "") }
            .task { await load() }
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        Section {
            Text(localized(
                "CV는 영어로 발행됩니다. 아래에서 영문 이름과 항목별 영어 표기를 확정하세요. 비워둔 항목은 원문이 그대로 쓰입니다.",
                "Your CV is published in English. Confirm your romanized name and English wording per entry below. Anything left blank falls back to the original text.",
                "Der Lebenslauf erscheint auf Englisch. Bestätige unten die englische Schreibweise. Leere Felder nutzen den Originaltext."))
            .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var identitySection: some View {
        Section {
            labeledField(localized("영문 이름", "Name (English)", "Name (Englisch)"),
                         text: $nameEn, placeholder: session.profile?.realName ?? "e.g. Hyewon Heo")
            labeledField(localized("헤드라인", "Headline", "Überschrift"),
                         text: $eyebrow, placeholder: "e.g. VIOLINIST · BERLIN")
            birthDateRow
            labeledField(localized("전화", "Phone", "Telefon"),
                         text: $phone, placeholder: "+49 …")
            labeledField(localized("주소", "Address", "Adresse"),
                         text: $address, placeholder: "Torstraße 12, Berlin")
        } header: {
            Text(localized("이름 · 연락처", "Name & contact", "Name & Kontakt"))
        } footer: {
            Text(localized("전화·주소·생년월일은 공개 웹 프로필에는 표시되지 않고, 내려받는 PDF에만 들어갑니다.",
                           "Phone, address and date of birth appear only in the downloaded PDF, never on the public web profile.",
                           "Telefon, Adresse und Geburtsdatum erscheinen nur im PDF, nicht im öffentlichen Profil."))
        }
    }

    private var repertoireSection: some View {
        Section(localized("레퍼토리", "Repertoire", "Repertoire")) {
            ForEach(repertoire, id: \.self) { item in
                Text(item).font(.subheadline)
            }
            .onDelete { repertoire.remove(atOffsets: $0) }
            .onMove { repertoire.move(fromOffsets: $0, toOffset: $1) }

            HStack {
                TextField(localized("작품 추가 (예: Brahms — Violin Concerto)",
                                    "Add a work (e.g. Brahms — Violin Concerto)",
                                    "Werk hinzufügen"), text: $newRepItem)
                Button {
                    let v = newRepItem.trimmingCharacters(in: .whitespaces)
                    guard !v.isEmpty else { return }
                    repertoire.append(v); newRepItem = ""
                } label: { Image(systemName: "plus.circle.fill") }
                .disabled(newRepItem.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private struct ComposerTarget: Identifiable {
        let id = UUID()
        var existing: CVEntryRow?
        var kind: String
    }

    private var cvKinds: [(code: String, label: String)] {
        [("performance", localized("연주", "Performance", "Auftritt")),
         ("competition", localized("콩쿠르", "Competition", "Wettbewerb")),
         ("education",   localized("학력", "Education", "Ausbildung")),
         ("masterclass", localized("마스터클래스", "Masterclass", "Meisterkurs"))]
    }

    private var cvEntriesSection: some View {
        Section {
            ForEach(cvEntries) { row in
                Button { composer = ComposerTarget(existing: row, kind: row.kind) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title ?? row.institution ?? "—")
                                .font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                            Text(kindLabel(row.kind) + (row.year.map { " · \($0)" } ?? ""))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .onDelete { idx in
                let ids = idx.map { cvEntries[$0].id }
                Task { await deleteEntries(ids) }
            }
            Menu {
                ForEach(cvKinds, id: \.code) { k in
                    Button(k.label) { composer = ComposerTarget(existing: nil, kind: k.code) }
                }
            } label: {
                Label(localized("항목 추가", "Add entry", "Eintrag hinzufügen"), systemImage: "plus.circle.fill")
            }
        } header: {
            Text(localized("CV 전용 항목", "CV-only entries", "Nur-CV-Einträge"))
        } footer: {
            Text(localized("기록과 별개로 CV에만 넣을 항목을 타입별로 추가합니다. 추가 후 ‘항목 영어화’에서 번역하세요.",
                           "Add CV-only entries by type, separate from your records. Translate them under ‘English per entry’.",
                           "Nur-CV-Einträge je Typ, getrennt von Aktivitäten."))
        }
    }

    private func kindLabel(_ k: String) -> String { cvKinds.first { $0.code == k }?.label ?? k }

    private func deleteEntries(_ ids: [UUID]) async {
        for id in ids { try? await session.repo.deleteCVEntry(id: id) }
        await load()
    }

    private var entriesSection: some View {
        Section {
            if loading {
                HStack { ProgressView().scaleEffect(0.8); Text(localized("불러오는 중…", "Loading…", "Lädt…")).foregroundStyle(.secondary) }
            } else if entries.isEmpty {
                Text(localized("아직 등록된 활동이 없습니다.", "No activities yet.", "Noch keine Aktivitäten."))
                    .foregroundStyle(.secondary).font(.subheadline)
            } else {
                ForEach(entries) { entry in
                    NavigationLink {
                        CVEntryOverrideView(entry: entry,
                                            existing: overrides[entry.id]) { updated in
                            overrides[entry.id] = updated
                        }
                    } label: { entryRow(entry) }
                }
            }
        } header: {
            Text(localized("항목 영어화", "English per entry", "Englisch je Eintrag"))
        } footer: {
            Text(localized("각 항목을 눌러 영어 표기를 확정하고, CV에 넣을지 정하세요.",
                           "Tap an entry to confirm English wording and whether it appears on the CV.",
                           "Tippe einen Eintrag an, um Englisch und Sichtbarkeit festzulegen."))
        }
    }

    private func entryRow(_ entry: CVEntry) -> some View {
        let ov = overrides[entry.id]
        let excluded = ov?.include == false
        let hasEnglish = !(ov?.patch.isEmpty ?? true)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.titleOriginal).font(.subheadline.weight(.medium))
                    .foregroundStyle(excluded ? .secondary : .primary)
                    .lineLimit(1)
                Text(entry.sectionLabel + (entry.subtitleOriginal.map { " · \($0)" } ?? ""))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if excluded {
                Image(systemName: "eye.slash").font(.caption).foregroundStyle(.orange)
            } else if hasEnglish {
                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
            }
        }
    }

    private var exportSection: some View {
        Section {
            Button {
                Task { await export() }
            } label: {
                HStack {
                    Image(systemName: "arrow.down.doc")
                    Text(localized("PDF 내보내기", "Export PDF", "PDF exportieren"))
                    Spacer()
                    if exporting { ProgressView().scaleEffect(0.8) }
                }
            }
            .disabled(exporting)
        } footer: {
            Text(localized("저장 후 내보내면 최신 내용이 반영됩니다.",
                           "Save first so the export reflects your latest changes.",
                           "Zuerst speichern, damit der Export aktuell ist."))
        }
    }

    // MARK: - Helpers

    private var birthDateRow: some View {
        HStack {
            Text(localized("생년월일", "Date of birth", "Geburtsdatum"))
                .foregroundStyle(.secondary)
            Spacer()
            if let date = birthDate {
                DatePicker("", selection: Binding(get: { date }, set: { birthDate = $0 }),
                           in: Self.birthDateRange,
                           displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Button { birthDate = nil } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                }
                .buttonStyle(.plain)
            } else {
                Button(localized("설정", "Set", "Festlegen")) {
                    birthDate = Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1))
                }
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    private static let birthDateRange: ClosedRange<Date> = {
        let cal = Calendar.current
        let min = cal.date(from: DateComponents(year: 1900, month: 1, day: 1))!
        return min...Date()
    }()

    private static let isoDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private func labeledField(_ label: String, text: Binding<String>,
                              placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
        }
    }

    // MARK: - Data

    private func load() async {
        guard let me = session.currentUserID else { return }
        loading = true
        if let p = session.profile {
            nameEn = p.nameEn ?? ""
            eyebrow = p.eyebrow ?? ""
            if let dateStr = p.birthDate {
                birthDate = Self.isoDateFormatter.date(from: dateStr)
            } else if let year = p.birthYear {
                birthDate = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))
            } else {
                birthDate = nil
            }
            phone = p.phone ?? ""
            address = p.address ?? ""
            repertoire = p.repertoire ?? []
        }
        do {
            async let acts = session.repo.cvActivities(userId: me)
            async let affs = session.repo.affiliations(forUser: me)
            async let ces = session.repo.cvEntries(userId: me)
            let (activities, affiliations, entryRows) = try await (acts, affs, ces)
            cvEntries = entryRows
            // 오버레이는 부가 기능 — cv_i18n 미배포 환경에선 실패해도 편집기는 뜬다
            let overrideList = (try? await session.repo.cvOverrides(userId: me)) ?? []
            overrides = Dictionary(uniqueKeysWithValues:
                overrideList.map { ("\($0.sourceKind):\($0.sourceId.uuidString)", $0) })
            entries = CVEntry.build(activities: activities, affiliations: affiliations, cvEntries: entryRows)
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
    }

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true; errorText = nil
        do {
            try await session.repo.updateCVFields(
                id: me,
                nameEn: nameEn.trimmedOrNil,
                eyebrow: eyebrow.trimmedOrNil,
                birthDate: birthDate.map { Self.isoDateFormatter.string(from: $0) },
                phone: phone.trimmedOrNil,
                address: address.trimmedOrNil)
            try await session.repo.saveRepertoire(id: me, items: repertoire)
            await session.refreshProfile()
            busy = false
            dismiss()
        } catch {
            errorText = error.localizedDescription
            busy = false
        }
    }

    private func export() async {
        exporting = true; errorText = nil
        do {
            let url = try await session.repo.exportCV()
            openURL(url)
        } catch {
            errorText = error.localizedDescription
        }
        exporting = false
    }
}

private extension String {
    var trimmedOrNil: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
