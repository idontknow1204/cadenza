import SwiftUI
import UniformTypeIdentifiers

struct CvWebsiteEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var userId: UUID
    var currentCvUrl: String?
    var currentWebsiteUrl: String?
    var onSave: (String?, String?) -> Void

    @State private var cvUrl = ""
    @State private var websiteUrl = ""
    @State private var showFilePicker = false
    @State private var uploadingCV = false
    @State private var busy = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if !cvUrl.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(Color.accentColor)
                            Text(cvUrl.components(separatedBy: "/").last ?? "CV")
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Button { cvUrl = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if uploadingCV {
                        HStack { ProgressView(); Text("업로드 중…").foregroundStyle(.secondary) }
                    } else {
                        Button {
                            showFilePicker = true
                        } label: {
                            Label(cvUrl.isEmpty ? "PDF 파일 업로드" : "파일 교체", systemImage: "arrow.up.doc")
                        }

                        if cvUrl.isEmpty {
                            TextField("또는 링크 붙여넣기 (Google Drive 등)", text: $cvUrl)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                    }
                } header: {
                    Text("CV / 이력서")
                } footer: {
                    Text("PDF 파일을 업로드하거나 공유 링크를 붙여넣으세요.")
                }

                Section("홈페이지") {
                    TextField("https://", text: $websiteUrl)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("CV / 홈페이지")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() } else {
                        Button("저장", action: save)
                            .fontWeight(.semibold)
                    }
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { result in
                Task { await handlePicked(result) }
            }
            .onAppear {
                cvUrl      = currentCvUrl ?? ""
                websiteUrl = currentWebsiteUrl ?? ""
            }
        }
    }

    private func handlePicked(_ result: Result<URL, Error>) async {
        uploadingCV = true; errorText = nil
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "CV", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "파일 접근 권한이 없습니다"])
            }
            defer { url.stopAccessingSecurityScopedResource() }
            let data = try Data(contentsOf: url)
            try await session.ensureAuthenticatedSession()
            cvUrl = try await session.repo.uploadCV(userId: userId, data: data)
        } catch {
            errorText = localized(
                "PDF 업로드 실패: \(error.localizedDescription)",
                "PDF upload failed: \(error.localizedDescription)",
                "PDF-Upload fehlgeschlagen: \(error.localizedDescription)"
            )
        }
        uploadingCV = false
    }

    private func save() {
        busy = true
        Task {
            do {
                let cv  = cvUrl.trimmingCharacters(in: .whitespaces)
                let web = websiteUrl.trimmingCharacters(in: .whitespaces)
                let updatedProfile = try await session.repo.updateProfileLinks(
                    id: userId,
                    cvUrl: cv.isEmpty ? nil : cv,
                    websiteUrl: web.isEmpty ? nil : web)
                session.profile = updatedProfile
                onSave(cv.isEmpty ? nil : cv, web.isEmpty ? nil : web)
                dismiss()
            } catch {
                errorText = error.localizedDescription
                busy = false
            }
        }
    }
}
