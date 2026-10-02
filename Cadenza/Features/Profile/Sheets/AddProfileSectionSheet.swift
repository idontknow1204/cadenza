import SwiftUI

struct AddProfileSectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSections: Set<String>
    @State private var isSaving = false
    @State private var errorText: String?

    private let initialSections: [String]
    private let onSave: ([String]) async throws -> Void

    init(visibleSections: [String], onSave: @escaping ([String]) async throws -> Void) {
        initialSections = visibleSections
        _selectedSections = State(initialValue: Set(visibleSections))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(ProfileSection.allCases) { section in
                    Toggle(isOn: Binding(
                        get: { selectedSections.contains(section.rawValue) },
                        set: { enabled in
                            if enabled { selectedSections.insert(section.rawValue) }
                            else { selectedSections.remove(section.rawValue) }
                        }
                    )) {
                        Label(section.title, systemImage: section.icon)
                    }
                    .accessibilityIdentifier("profile.sections.toggle.\(section.rawValue)")
                }
            }
            .disabled(isSaving)
            .navigationTitle(localized("프로필 섹션 관리", "Profile Sections", "Abschnitte"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                        .disabled(isSaving)
                        .accessibilityIdentifier("profile.sections.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() }
                        else { Text(localized("저장", "Save", "Speichern")) }
                    }
                    .disabled(isSaving || selectedSections == Set(initialSections))
                    .accessibilityIdentifier("profile.sections.save")
                }
            }
            .interactiveDismissDisabled(isSaving)
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

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        // Preserve sections introduced by newer clients without exposing unknown toggles.
        let known = ProfileSection.allCases.map(\.rawValue)
        let sections = known.filter { selectedSections.contains($0) }
            + initialSections.filter { !known.contains($0) }
        do {
            try await onSave(sections)
            dismiss()
        } catch {
            errorText = localized("프로필 섹션을 저장하지 못했습니다. 다시 시도해 주세요.",
                                  "Could not save profile sections. Please try again.",
                                  "Profilabschnitte konnten nicht gespeichert werden. Bitte erneut versuchen.")
        }
    }
}
