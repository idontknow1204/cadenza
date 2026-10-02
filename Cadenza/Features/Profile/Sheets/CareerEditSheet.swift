import SwiftUI

struct CareerEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let existing: Career?

    @State private var organization = ""
    @State private var role = ""
    @State private var startYear: Int = Calendar.current.component(.year, from: Date())
    @State private var endYear: Int = Calendar.current.component(.year, from: Date())
    @State private var isCurrent = true
    @State private var description = ""
    @State private var contribution = ""
    @State private var linkUrl = ""
    @State private var mediaUrl = ""
    @State private var busy = false
    @State private var showDelete = false

    private var years: [Int] {
        let cur = Calendar.current.component(.year, from: Date())
        return Array((1970...cur + 1).reversed())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("profile.career.basic") {
                    TextField("profile.career.organization", text: $organization)
                    TextField("profile.career.role", text: $role)
                }

                Section("profile.career.period") {
                    Picker("profile.career.start", selection: $startYear) {
                        ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                    }
                    Toggle("profile.career.current", isOn: $isCurrent)
                    if !isCurrent {
                        Picker("profile.career.end", selection: $endYear) {
                            ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                }

                Section("profile.career.description") {
                    TextField("profile.career.description.hint", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    TextField("이 역할에서 직접 기여한 일, 만든 결과, 개선한 지표를 작성해 주세요.", text: $contribution, axis: .vertical)
                        .lineLimit(3...7)
                } header: {
                    Text("기여 내용")
                } footer: {
                    Text("예: 오디션 운영 프로세스 개선, 공연 기획 리드, 사용자 리서치 설계 및 인사이트 도출")
                }

                Section {
                    TextField("관련 링크 URL", text: $linkUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("영상 URL", text: $mediaUrl)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("첨부")
                } footer: {
                    Text("LinkedIn, 포트폴리오, 기사, YouTube, Vimeo 등 경력 증빙에 도움이 되는 링크를 첨부할 수 있습니다.")
                }

                if existing != nil {
                    Section {
                        Button("common.delete", role: .destructive) { showDelete = true }
                    }
                }
            }
            .navigationTitle(existing == nil ? "profile.career.add" : "profile.career.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() } else {
                        Button("profile.edit.save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .disabled(organization.isEmpty || role.isEmpty)
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
        guard let c = existing else { return }
        organization = c.organization
        role = c.role
        startYear = c.startYear ?? Calendar.current.component(.year, from: Date())
        isCurrent = c.isCurrent
        endYear = c.endYear ?? Calendar.current.component(.year, from: Date())
        description = c.description ?? ""
        contribution = c.contribution ?? ""
        linkUrl = c.linkUrl ?? ""
        mediaUrl = c.mediaUrl ?? ""
    }

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true
        let cleanedDescription = cleaned(description)
        let cleanedContribution = cleaned(contribution)
        let cleanedLinkUrl = normalizedURL(linkUrl)
        let cleanedMediaUrl = normalizedURL(mediaUrl)
        do {
            if let id = existing?.id {
                try await session.repo.updateCareer(
                    id: id, organization: organization, role: role,
                    startYear: startYear, endYear: isCurrent ? nil : endYear,
                    isCurrent: isCurrent,
                    description: cleanedDescription,
                    contribution: cleanedContribution,
                    linkUrl: cleanedLinkUrl,
                    mediaUrl: cleanedMediaUrl)
            } else {
                try await session.repo.insertCareer(NewCareer(
                    userId: me, organization: organization, role: role,
                    startYear: startYear, endYear: isCurrent ? nil : endYear,
                    isCurrent: isCurrent,
                    description: cleanedDescription,
                    contribution: cleanedContribution,
                    linkUrl: cleanedLinkUrl,
                    mediaUrl: cleanedMediaUrl))
            }
            dismiss()
        } catch { busy = false }
    }

    private func delete() async {
        guard let id = existing?.id else { return }
        busy = true
        try? await session.repo.deleteCareer(id: id)
        dismiss()
    }

    private func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedURL(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lowercased = trimmed.lowercased()
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
            return trimmed
        }
        return "https://\(trimmed)"
    }
}
