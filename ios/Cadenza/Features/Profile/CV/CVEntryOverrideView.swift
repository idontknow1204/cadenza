import SwiftUI

// CV 항목 하나의 영어 오버레이 편집 — 필드별 영어 확정 + CV 포함 여부.
// 저장 시 cv_i18n 에 upsert 하고 상위(CVEditorView)에 갱신을 알린다.
struct CVEntryOverrideView: View {
    let entry: CVEntry
    let existing: CVOverride?
    var lang: String = "en"
    let onSaved: (CVOverride) -> Void

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var values: [String: String] = [:]
    @State private var include = true
    @State private var busy = false
    @State private var translating = false
    @State private var didAutoSuggest = false
    @State private var suggested = false
    @State private var errorText: String?

    var body: some View {
        Form {
            Section {
                Toggle(localized("CV에 포함", "Include in CV", "Im CV anzeigen"), isOn: $include)
            } footer: {
                Text(localized("끄면 이 항목은 CV에 나타나지 않습니다.",
                               "Turn off to hide this entry from the CV.",
                               "Aus: Eintrag erscheint nicht im Lebenslauf."))
            }

            Section {
                ForEach(entry.fields) { field in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(field.label).font(.caption).foregroundStyle(.secondary)
                        TextField(field.original ?? localized("영어로 입력", "Enter English", "Auf Englisch"),
                                  text: binding(for: field.key))
                            .textInputAutocapitalization(.words)
                        if let orig = field.original, !orig.isEmpty {
                            Text(localized("원문: ", "Original: ", "Original: ") + orig)
                                .font(.caption2).foregroundStyle(.tertiary).lineLimit(2)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                HStack {
                    Text(localized("영어 표기", "English wording", "Englische Schreibweise"))
                    Spacer()
                    if translating {
                        HStack(spacing: 5) {
                            ProgressView().scaleEffect(0.7)
                            Text(localized("번역 중…", "Translating…", "Übersetzt…"))
                                .font(.caption2).textCase(nil).foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task { await suggest(overwrite: true) }
                        } label: {
                            Label(localized("AI 번역 제안", "AI translate", "KI-Übersetzung"),
                                  systemImage: "sparkles")
                                .font(.caption).textCase(nil)
                        }
                    }
                }
            } footer: {
                Text(suggested
                     ? localized("✨ AI가 원문을 영어로 번역해 채웠어요. 자유롭게 수정하세요. 비운 필드는 원문이 쓰입니다.",
                                 "✨ AI filled English suggestions from the original — edit freely. Blank fields fall back to the original.",
                                 "✨ KI hat Vorschläge eingefügt — frei bearbeiten. Leere Felder nutzen das Original.")
                     : localized("비운 필드는 원문이 그대로 CV에 쓰입니다.",
                                 "Blank fields fall back to the original text on the CV.",
                                 "Leere Felder nutzen den Originaltext."))
            }
        }
        .navigationTitle(entry.titleOriginal)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
        .onAppear {
            include = existing?.include ?? true
            values = existing?.patch ?? [:]
            // 기존 영어가 없던 항목이면 자동으로 번역 제안을 채운다 (한 번만)
            if !didAutoSuggest && (existing?.patch.isEmpty ?? true) {
                didAutoSuggest = true
                Task { await suggest(overwrite: false) }
            }
        }
    }

    /// 원문을 영어로 번역해 비어있는(또는 overwrite 시 전부) 필드에 제안을 채운다. 실패해도 무시.
    private func suggest(overwrite: Bool) async {
        let originals = Dictionary(uniqueKeysWithValues:
            entry.fields.compactMap { f -> (String, String)? in
                guard let o = f.original?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !o.isEmpty else { return nil }
                return (f.key, o)
            })
        guard !originals.isEmpty else { return }
        translating = true
        defer { translating = false }
        do {
            let out = try await session.repo.translateCVEntry(kind: entry.kind, fields: originals,
                                                              targetLang: lang)
            for (k, v) in out {
                let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { continue }
                if overwrite || (values[k] ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
                    values[k] = t
                }
            }
            if !out.isEmpty { suggested = true }
        } catch {
            // 번역 실패는 치명적이지 않음 — 사용자가 직접 입력하면 됨
        }
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true; errorText = nil
        var patch: [String: String] = [:]
        for (k, v) in values {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { patch[k] = t }
        }
        let override = CVOverride(sourceKind: entry.sourceKind, sourceId: entry.sourceId,
                                  patch: patch, include: include)
        do {
            try await session.repo.upsertCVOverride(userId: me, override: override, lang: lang)
            onSaved(override)
            busy = false
            dismiss()
        } catch {
            errorText = error.localizedDescription
            busy = false
        }
    }
}
