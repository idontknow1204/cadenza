import SwiftUI

struct CreateJobView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var type: JobType = .audition
    @State private var title = ""
    @State private var organization = ""
    @State private var location = ""
    @State private var selectedInstruments: Set<String> = []
    @State private var description = ""
    @State private var requirements = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var contact = ""

    @State private var busy = false
    @State private var errorText: String?
    @State private var showInstrumentPicker = false

    private var canPost: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        description.trimmingCharacters(in: .whitespaces).count >= 10
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── 공고 유형 ──────────────────────────────────────
                Section {
                    typeSelector
                }

                // ── 기본 정보 ──────────────────────────────────────
                Section("기본 정보") {
                    TextField("공고 제목 *", text: $title)
                    TextField("기관 / 단체명", text: $organization)
                    TextField("지역", text: $location)
                }

                // ── 모집 악기 ──────────────────────────────────────
                Section {
                    Button {
                        showInstrumentPicker = true
                    } label: {
                        HStack {
                            Text(selectedInstruments.isEmpty
                                 ? localized("악기 선택", "Select instruments", "Instrumente wählen")
                                 : selectedInstruments
                                    .map { OnboardingData.instrumentDisplay($0) }
                                    .sorted()
                                    .joined(separator: ", "))
                                .foregroundStyle(selectedInstruments.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: { Text("모집 악기") }

                // ── 상세 내용 ──────────────────────────────────────
                Section("상세 내용 *") {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }

                // ── 지원 자격 ──────────────────────────────────────
                Section("지원 자격") {
                    TextEditor(text: $requirements)
                        .frame(minHeight: 60)
                }

                // ── 마감일 ────────────────────────────────────────
                Section("마감일") {
                    Toggle("마감일 설정", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("마감일",
                                   selection: $deadline,
                                   in: Date()...,
                                   displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "ko_KR"))
                    }
                }

                // ── 연락처 ────────────────────────────────────────
                Section("연락처 / 지원 방법") {
                    TextField("이메일, 전화번호, 링크 등", text: $contact, axis: .vertical)
                        .lineLimit(3, reservesSpace: false)
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("공고 올리기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button("게시") { Task { await post() } }
                            .disabled(!canPost)
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showInstrumentPicker) {
                InstrumentPickerSheet(selected: $selectedInstruments)
            }
            .alert("오류", isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) {
                Button("확인") { errorText = nil }
            } message: { Text(errorText ?? "") }
        }
    }

    // MARK: - Type selector

    private var typeSelector: some View {
        HStack(spacing: 0) {
            ForEach(JobType.allCases) { t in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { type = t }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: t.symbol)
                            .font(.system(size: 18))
                        Text(t.label)
                            .font(.caption2.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        type == t
                            ? Color("BrandSurface")
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .foregroundStyle(type == t ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
    }



    // MARK: - Post

    private func post() async {
        guard let me = session.currentUserID else { return }
        busy = true; errorText = nil
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let job = NewJob(
            userId: me,
            type: type.rawValue,
            title: title.trimmingCharacters(in: .whitespaces),
            organization: organization.isEmpty ? nil : organization,
            location: location.isEmpty ? nil : location,
            instruments: Array(selectedInstruments).sorted(),
            description: description.trimmingCharacters(in: .whitespaces),
            requirements: requirements.isEmpty ? nil : requirements,
            deadline: hasDeadline ? fmt.string(from: deadline) : nil,
            contact: contact.isEmpty ? nil : contact
        )
        do {
            try await session.repo.postJob(job)
            dismiss()
        } catch {
            errorText = error.localizedDescription
            busy = false
        }
    }
}

// MARK: - Instrument picker sheet

private struct InstrumentPickerSheet: View {
    @Binding var selected: Set<String>
    @Environment(\.dismiss) private var dismiss

    // Group instruments under their major, using the major's canonical order.
    private var groups: [(major: OnboardingData.LocalizedOption, instruments: [OnboardingData.LocalizedOption])] {
        OnboardingData.majors.compactMap { major in
            guard let insts = OnboardingData.instrumentsByMajor[major.id], !insts.isEmpty else { return nil }
            return (major: major, instruments: insts)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.major.id) { group in
                    Section(group.major.localizedName) {
                        ForEach(group.instruments) { inst in
                            Button {
                                if selected.contains(inst.id) { selected.remove(inst.id) }
                                else { selected.insert(inst.id) }
                            } label: {
                                HStack {
                                    Text(inst.localizedName).foregroundStyle(.primary)
                                    Spacer()
                                    if selected.contains(inst.id) {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(localized("악기 선택", "Select instruments", "Instrumente wählen"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("완료", "Done", "Fertig")) { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
