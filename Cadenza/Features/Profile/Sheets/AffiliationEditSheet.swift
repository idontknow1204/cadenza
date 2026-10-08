import SwiftUI

struct AffiliationEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let existing: Affiliation?
    var onSave: (Affiliation) -> Void = { _ in }
    var onDelete: (UUID) -> Void = { _ in }

    @State private var institutionName = ""
    @State private var courseType: String? = nil
    @State private var enrollmentYear: Int = Calendar.current.component(.year, from: Date())
    @State private var isCurrent = true
    @State private var graduationYear: Int = Calendar.current.component(.year, from: Date()) + 2
    @State private var busy = false
    @State private var showDelete = false
    @State private var errorText: String?

    private var years: [Int] { Array((1970...Calendar.current.component(.year, from: Date()) + 8).reversed()) }

    var body: some View {
        NavigationStack {
            Form {
                Section("profile.education.institution") {
                    SchoolAutocompleteField(text: $institutionName)
                    Picker("onboarding.course", selection: $courseType) {
                        Text("profile.edit.none").tag(String?.none)
                        ForEach(OnboardingData.courseOptions) { opt in
                            Text(opt.label).tag(String?.some(opt.id))
                        }
                    }
                }

                Section("profile.education.period") {
                    Picker("profile.career.start", selection: $enrollmentYear) {
                        ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                    }
                    Toggle("profile.career.current", isOn: $isCurrent)
                    if isCurrent {
                        Picker("profile.education.graduation", selection: $graduationYear) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    } else {
                        Picker("profile.education.graduated", selection: $graduationYear) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                }

                if existing != nil {
                    Section {
                        Button("common.delete", role: .destructive) { showDelete = true }
                    }
                }
            }
            .navigationTitle(existing == nil ? "profile.education.add" : "profile.education.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() } else {
                        Button("profile.edit.save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(institutionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .disabled(busy)
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
        guard let a = existing else { return }
        institutionName = a.institutionName
        courseType = a.courseType
        enrollmentYear = a.enrollmentYear ?? Calendar.current.component(.year, from: Date())
        isCurrent = a.isCurrent
        graduationYear = a.graduationYear ?? (enrollmentYear + 4)
    }

    private func save() async {
        guard !busy, let me = session.currentUserID else { return }
        let cleanedInstitution = institutionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedInstitution.isEmpty else { return }
        busy = true
        errorText = nil
        do {
            let saved: Affiliation
            if let id = existing?.id {
                saved = try await session.repo.updateAffiliation(
                    id: id, institutionName: cleanedInstitution, courseType: courseType,
                    enrollmentYear: enrollmentYear,
                    graduationYear: graduationYear,
                    isCurrent: isCurrent)
            } else {
                saved = try await session.repo.insertAffiliation(
                    NewAffiliation(userId: me, institutionName: cleanedInstitution,
                                   courseType: courseType, enrollmentYear: enrollmentYear,
                                   graduationYear: graduationYear, isCurrent: isCurrent))
            }
            onSave(saved)
            dismiss()
        } catch {
            busy = false
            errorText = error.localizedDescription
        }
    }

    private func delete() async {
        guard !busy, let id = existing?.id else { return }
        busy = true
        errorText = nil
        do {
            try await session.repo.deleteAffiliation(id: id)
            onDelete(id)
            dismiss()
        } catch {
            busy = false
            errorText = error.localizedDescription
        }
    }
}

/// Shared school entry field. Suggestions accelerate common input, but the
/// typed value remains the source of truth so schools outside the bundled list
/// are valid and persist normally.
struct SchoolAutocompleteField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    private var suggestions: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(OnboardingData.schools
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("onboarding.school.hint", text: $text)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { isFocused = false }

            if isFocused && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { index, school in
                        Button {
                            text = school
                            isFocused = false
                        } label: {
                            Text(school)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                        }
                        // A Form treats all automatic-style buttons in one row
                        // as a single action. Plain style gives every suggestion
                        // its own hit target instead of activating the last row.
                        .buttonStyle(.plain)
                        if index < suggestions.count - 1 { Divider() }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
