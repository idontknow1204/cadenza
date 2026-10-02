import SwiftUI

struct AffiliationEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let existing: Affiliation?

    @State private var institutionName = ""
    @State private var schoolQuery = ""
    @State private var showSuggestions = false
    @State private var courseType: String? = nil
    @State private var enrollmentYear: Int = Calendar.current.component(.year, from: Date())
    @State private var isCurrent = true
    @State private var graduationYear: Int = Calendar.current.component(.year, from: Date()) + 2
    @State private var busy = false
    @State private var showDelete = false

    private var years: [Int] { Array((1970...Calendar.current.component(.year, from: Date()) + 8).reversed()) }

    private var filteredSchools: [String] {
        guard !schoolQuery.isEmpty else { return [] }
        return OnboardingData.schools.filter { $0.localizedCaseInsensitiveContains(schoolQuery) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("profile.education.institution") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("onboarding.school.hint", text: $schoolQuery)
                            .onChange(of: schoolQuery) { _, v in
                                institutionName = v; showSuggestions = !v.isEmpty
                            }
                        if showSuggestions && !filteredSchools.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredSchools.prefix(5), id: \.self) { s in
                                    Button {
                                        institutionName = s; schoolQuery = s
                                        showSuggestions = false
                                    } label: {
                                        Text(s).font(.subheadline)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 12).padding(.vertical, 9)
                                    }
                                    .foregroundStyle(.primary)
                                    Divider()
                                }
                            }
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 4, y: 2)
                        }
                    }
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
                            .disabled(institutionName.isEmpty)
                    }
                }
            }
            .onAppear(perform: load)
            .confirmationDialog("common.delete.confirm", isPresented: $showDelete, titleVisibility: .visible) {
                Button("common.delete", role: .destructive) { Task { await delete() } }
                Button("common.cancel", role: .cancel) {}
            }
        }
    }

    private func load() {
        guard let a = existing else { return }
        institutionName = a.institutionName; schoolQuery = a.institutionName
        courseType = a.courseType
        enrollmentYear = a.enrollmentYear ?? Calendar.current.component(.year, from: Date())
        isCurrent = a.isCurrent
        graduationYear = a.graduationYear ?? (enrollmentYear + 4)
    }

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true
        do {
            if let id = existing?.id {
                try await session.repo.updateAffiliation(
                    id: id, institutionName: institutionName, courseType: courseType,
                    enrollmentYear: enrollmentYear,
                    graduationYear: graduationYear,
                    isCurrent: isCurrent)
            } else {
                try await session.repo.insertAffiliation(
                    NewAffiliation(userId: me, institutionName: institutionName,
                                   courseType: courseType, enrollmentYear: enrollmentYear,
                                   graduationYear: graduationYear))
            }
            dismiss()
        } catch { busy = false }
    }

    private func delete() async {
        guard let id = existing?.id else { return }
        busy = true
        try? await session.repo.deleteAffiliation(id: id)
        dismiss()
    }
}
