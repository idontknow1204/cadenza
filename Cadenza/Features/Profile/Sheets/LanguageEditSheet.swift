import SwiftUI

struct LanguageEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let current: [ProfileLanguage]
    var onChange: ([ProfileLanguage]) -> Void = { _ in }

    @State private var languages: [ProfileLanguage] = []
    @State private var showAdd = false
    @State private var newLanguage = ""
    @State private var newLevel = "fluent"
    @State private var busy = false
    @State private var errorText: String?

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
                    Button {
                        Task { await addLanguage() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("profile.language.add.btn")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(newLanguage.isEmpty || busy)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((newLanguage.isEmpty || busy) ? Color.accentColor.opacity(0.3) : Color.accentColor)
                            .padding(.horizontal, 0)
                    )
                    .foregroundStyle(.white)
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
        errorText = nil
        do {
            let saved = try await session.repo.upsertLanguage(
                userId: me,
                language: newLanguage,
                level: newLevel
            )
            if let index = languages.firstIndex(where: { $0.language == saved.language }) {
                languages[index] = saved
            } else {
                languages.append(saved)
            }
            onChange(languages)
            newLanguage = ""; newLevel = "fluent"
        } catch {
            errorText = error.localizedDescription
        }
        busy = false
    }

    private func deleteAt(_ idxs: IndexSet) async {
        let values = idxs.compactMap { index in
            languages.indices.contains(index) ? languages[index] : nil
        }
        guard !values.isEmpty else { return }
        busy = true
        errorText = nil
        do {
            for language in values {
                try await session.repo.deleteLanguage(id: language.id)
            }
            let deletedIDs = Set(values.map(\.id))
            languages.removeAll { deletedIDs.contains($0.id) }
            onChange(languages)
        } catch {
            errorText = error.localizedDescription
        }
        busy = false
    }
}
