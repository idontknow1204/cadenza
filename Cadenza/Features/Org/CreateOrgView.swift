import SwiftUI

struct CreateOrgView: View {
    var onCreated: ((Organization) -> Void)? = nil

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var handle = ""
    @State private var handleEdited = false
    @State private var category: OrgCategory = .orchestra
    @State private var description = ""
    @State private var website = ""
    @State private var busy = false
    @State private var errorText: String?
    @State private var handleError: String?

    private var canSubmit: Bool {
        !name.isEmpty && !handle.isEmpty && handleError == nil && !busy
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        OrgAvatar(category: category, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "기관 이름" : name)
                                .font(.headline)
                                .foregroundStyle(name.isEmpty ? Color.secondary : Color.primary)
                            Text(category.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.vertical, 4)
                }

                Section("기관 정보") {
                    TextField("기관 이름 *", text: $name)
                        .onChange(of: name) { _, v in
                            if !handleEdited {
                                handle = makeHandle(from: v)
                            }
                        }

                    HStack {
                        Text("@").foregroundStyle(.secondary)
                        TextField("핸들 *", text: $handle)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onChange(of: handle) { _, v in
                                handleEdited = true
                                handle = v.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
                                handleError = handle.count < 3 ? "3자 이상 입력하세요" : nil
                            }
                    }
                    if let err = handleError {
                        Text(err).font(.caption).foregroundStyle(.red)
                    }

                    Picker("분야", selection: $category) {
                        ForEach(OrgCategory.allCases) { c in
                            Label(c.label, systemImage: c.symbol).tag(c)
                        }
                    }
                }

                Section("소개") {
                    TextField("기관 소개 (선택)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("웹사이트 (선택)", text: $website)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let e = errorText {
                    Section {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("기관 페이지 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("만들기") { Task { await create() } }
                        .disabled(!canSubmit)
                        .bold()
                }
            }
            .overlay { if busy { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(.ultraThinMaterial) } }
        }
    }

    // MARK: - Helpers

    private func makeHandle(from name: String) -> String {
        name.lowercased()
            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
            .replacingOccurrences(of: " ", with: "_")
            .prefix(30)
            .description
    }

    private func create() async {
        guard let me = session.currentUserID else { return }
        busy = true
        errorText = nil
        defer { busy = false }
        do {
            let org = try await session.repo.createOrg(
                name: name,
                handle: handle,
                category: category,
                description: description.isEmpty ? nil : description,
                website: website.isEmpty ? nil : website,
                createdBy: me
            )
            onCreated?(org)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
