import SwiftUI

struct LanguageEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let current: [ProfileLanguage]

    @State private var languages: [ProfileLanguage] = []
    @State private var showAdd = false
    @State private var newLanguage = ""
    @State private var newLevel = "fluent"
    @State private var busy = false

    private let presetLanguages = [
        "한국어", "English", "Deutsch", "日本語", "Français",
        "中文", "Español", "Italiano", "Русский", "Português"
    ]
    private let levels: [(id: String, label: String)] = [
        ("native",       "원어민 / Native"),
        ("fluent",       "유창 / Fluent"),
        ("intermediate", "중급 / Intermediate"),
        ("basic",        "기초 / Basic")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(languages) { lang in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lang.language).font(.subheadline.weight(.medium))
                                Text(levelLabel(lang.level)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { idxs in
                        Task { await deleteAt(idxs) }
                    }
                } header: {
                    Text("profile.language")
                } footer: {
                    Text("profile.language.swipe").font(.caption)
                }

                Section("profile.language.add") {
                    Picker("profile.language.name", selection: $newLanguage) {
                        Text("profile.edit.none").tag("")
                        ForEach(presetLanguages, id: \.self) { l in
                            Text(l).tag(l)
                        }
                    }
                    Picker("profile.language.level", selection: $newLevel) {
                        ForEach(levels, id: \.id) { l in
                            Text(l.label).tag(l.id)
                        }
                    }
                    Button("profile.language.add.btn") {
                        Task { await addLanguage() }
                    }
                    .disabled(newLanguage.isEmpty || busy)
                }
            }
            .navigationTitle("profile.language.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.ok") { dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear { languages = current }
        }
    }

    private func levelLabel(_ level: String) -> String {
        switch level {
        case "native":       return NSLocalizedString("profile.language.native", comment: "")
        case "fluent":       return NSLocalizedString("profile.language.fluent", comment: "")
        case "intermediate": return NSLocalizedString("profile.language.intermediate", comment: "")
        default:             return NSLocalizedString("profile.language.basic", comment: "")
        }
    }

    private func addLanguage() async {
        guard let me = session.currentUserID, !newLanguage.isEmpty else { return }
        busy = true
        do {
            try await session.repo.upsertLanguage(userId: me, language: newLanguage, level: newLevel)
            if let lang = try? await session.repo.languages(forUser: me).first(where: { $0.language == newLanguage }) {
                if !languages.contains(where: { $0.language == newLanguage }) {
                    languages.append(lang)
                }
            }
            newLanguage = ""; newLevel = "fluent"
        } catch {}
        busy = false
    }

    private func deleteAt(_ idxs: IndexSet) async {
        for i in idxs {
            guard i < languages.count else { continue }
            let lang = languages[i]
            try? await session.repo.deleteLanguage(id: lang.id)
        }
        languages.remove(atOffsets: idxs)
    }
}
