import SwiftUI

// 다국어 프로필 편집기 — 한국어(베이스) 위에 언어별(en/de) 버전을 직접 작성한다.
// 방문자는 자기 언어 버전을 보고, 없으면 한국어 원문으로 폴백(cv_data lang 해석).
// 프로필 본문(이름/소개/악기)은 profile-level 오버레이, 항목은 CVEntryOverrideView(lang) 재사용.
// AI 번역 제안(cv-translate, targetLang)으로 원문에서 채워줄 수 있다.
struct MultilingualProfileEditorView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    // 작성 가능한 오버레이 언어 (ko 는 베이스라 제외)
    private let langs: [(code: String, label: String)] = [("en", "English"), ("de", "Deutsch")]
    @State private var lang = "en"

    @State private var nameV = ""
    @State private var bioV = ""
    @State private var instrumentV = ""
    @State private var eyebrowV = ""

    @State private var entries: [CVEntry] = []
    @State private var overrides: [String: CVOverride] = [:]

    @State private var loading = true
    @State private var busy = false
    @State private var translating = false
    @State private var errorText: String?

    private var base: Profile? { session.profile }

    var body: some View {
        NavigationStack {
            Form {
                langSection
                introSection
                profileSection
                entriesSection
            }
            .navigationTitle(localized("다국어 프로필", "Multilingual profile", "Mehrsprachiges Profil"))
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

    private var langSection: some View {
        Section {
            Picker(localized("언어", "Language", "Sprache"), selection: $lang) {
                ForEach(langs, id: \.code) { Text($0.label).tag($0.code) }
            }
            .pickerStyle(.segmented)
            .onChange(of: lang) { _, _ in Task { await load() } }
        } footer: {
            Text(localized("한국어는 기본 버전입니다. 여기서 작성한 언어 버전이 방문자 언어에 맞춰 보여지고, 없는 항목은 한국어 원문으로 표시됩니다.",
                           "Korean is the base version. Versions you write here are shown to visitors in their language; anything left blank falls back to the Korean original.",
                           "Koreanisch ist die Basis. Hier erstellte Sprachversionen werden Besuchern angezeigt; Leeres nutzt das koreanische Original."))
        }
    }

    private var introSection: some View {
        Section {
            Button {
                Task { await suggestProfile() }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(localized("원문에서 AI 번역 제안", "AI-translate from the original", "KI-Übersetzung aus dem Original"))
                    Spacer()
                    if translating { ProgressView().scaleEffect(0.8) }
                }
            }
            .disabled(translating)
        }
    }

    private var profileSection: some View {
        Section {
            overlayField(localized("이름", "Name", "Name"), text: $nameV, original: base?.realName)
            VStack(alignment: .leading, spacing: 4) {
                Text(localized("소개", "About", "Über mich")).font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $bioV).frame(minHeight: 70)
                if let o = base?.bio, !o.isEmpty {
                    Text(localized("원문: ", "Original: ", "Original: ") + o)
                        .font(.caption2).foregroundStyle(.tertiary).lineLimit(3)
                }
            }
            overlayField(localized("악기", "Instrument", "Instrument"), text: $instrumentV, original: base?.instrument)
            overlayField(localized("헤드라인", "Headline", "Überschrift"), text: $eyebrowV, original: nil)
        } header: {
            Text(localized("프로필", "Profile", "Profil"))
        }
    }

    private var entriesSection: some View {
        Section {
            if loading {
                HStack { ProgressView().scaleEffect(0.8); Text(localized("불러오는 중…", "Loading…", "Lädt…")).foregroundStyle(.secondary) }
            } else {
                ForEach(entries) { entry in
                    NavigationLink {
                        CVEntryOverrideView(entry: entry, existing: overrides[entry.id], lang: lang) { updated in
                            overrides[entry.id] = updated
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.titleOriginal).font(.subheadline.weight(.medium)).lineLimit(1)
                                Text(entry.sectionLabel).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !(overrides[entry.id]?.patch.isEmpty ?? true) {
                                Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        } header: {
            Text(localized("커리어 항목", "Career entries", "Karriereeinträge"))
        } footer: {
            Text(localized("각 항목의 \(langLabel) 표기를 작성하세요.",
                           "Write the \(langLabel) wording for each entry.",
                           "Schreibe die \(langLabel)-Fassung je Eintrag."))
        }
    }

    private var langLabel: String { langs.first { $0.code == lang }?.label ?? lang }

    private func overlayField(_ label: String, text: Binding<String>, original: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(original ?? label, text: text)
            if let o = original, !o.isEmpty {
                Text(localized("원문: ", "Original: ", "Original: ") + o)
                    .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
    }

    // MARK: - Data

    private func load() async {
        guard let me = session.currentUserID else { return }
        loading = true
        do {
            async let acts = session.repo.cvActivities(userId: me)
            async let affs = session.repo.affiliations(forUser: me)
            async let ces = session.repo.cvEntries(userId: me)
            async let cars = session.repo.careers(forUser: me)
            async let aws = session.repo.awards(forUser: me)
            let (activities, affiliations, entryRows, careerRows, awardRows) =
                try await (acts, affs, ces, cars, aws)
            entries = CVEntry.build(activities: activities, affiliations: affiliations,
                                    cvEntries: entryRows, careers: careerRows, awards: awardRows)
            let overrideList = (try? await session.repo.cvOverrides(userId: me, lang: lang)) ?? []
            overrides = Dictionary(uniqueKeysWithValues:
                overrideList.map { ("\($0.sourceKind):\($0.sourceId.uuidString)", $0) })
            let pov = (try? await session.repo.profileOverlay(userId: me, lang: lang)) ?? [:]
            nameV = pov["name"] ?? ""
            bioV = pov["bio"] ?? ""
            instrumentV = pov["instrument"] ?? ""
            eyebrowV = pov["eyebrow"] ?? ""
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
    }

    private func suggestProfile() async {
        var originals: [String: String] = [:]
        if let n = base?.realName, !n.isEmpty { originals["name"] = n }
        if let b = base?.bio, !b.isEmpty { originals["bio"] = b }
        if let i = base?.instrument, !i.isEmpty { originals["instrument"] = i }
        guard !originals.isEmpty else { return }
        translating = true
        defer { translating = false }
        if let out = try? await session.repo.translateCVEntry(kind: "profile", fields: originals, targetLang: lang) {
            if nameV.isEmpty, let v = out["name"] { nameV = v }
            if bioV.isEmpty, let v = out["bio"] { bioV = v }
            if instrumentV.isEmpty, let v = out["instrument"] { instrumentV = v }
        }
    }

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true; errorText = nil
        var patch: [String: String] = [:]
        for (k, v) in ["name": nameV, "bio": bioV, "instrument": instrumentV, "eyebrow": eyebrowV] {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { patch[k] = t }
        }
        do {
            try await session.repo.upsertProfileOverlay(userId: me, lang: lang, patch: patch)
            // 이 언어에 내용이 생겼으니 제공 언어 목록에 추가
            var set = Set(base?.profileLangs ?? [])
            if !patch.isEmpty || !overrides.isEmpty { set.insert(lang) }
            try await session.repo.setProfileLangs(id: me, langs: Array(set).sorted())
            await session.refreshProfile()
            busy = false
            dismiss()
        } catch {
            errorText = error.localizedDescription
            busy = false
        }
    }
}
