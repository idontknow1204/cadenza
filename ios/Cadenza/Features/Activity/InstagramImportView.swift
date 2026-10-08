import SwiftUI

struct InstagramImportResult {
    var caption: String
    var thumbnailUrl: String?
}

struct InstagramImportView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var onImport: (InstagramImportResult) -> Void

    @State private var urlText = ""
    @State private var state: LoadState = .idle
    @State private var result: InstagramImportResult? = nil

    enum LoadState {
        case idle, loading, done, failure(String)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("https://www.instagram.com/p/…", text: $urlText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                        if !urlText.isEmpty {
                            Button { urlText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Instagram 게시물 URL")
                } footer: {
                    Text("공개로 설정된 게시물만 가져올 수 있습니다.")
                        .font(.caption)
                }

                if case .loading = state {
                    Section {
                        HStack {
                            ProgressView()
                            Text("가져오는 중…").foregroundStyle(.secondary)
                        }
                    }
                }

                if case .failure(let msg) = state {
                    Section {
                        Label(msg, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                if let result {
                    Section("미리보기") {
                        if let thumb = result.thumbnailUrl {
                            AsyncImage(url: URL(string: thumb)) { img in
                                img.resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.15))
                                    .frame(height: 200)
                                    .overlay { ProgressView() }
                            }
                            .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }

                        if !result.caption.isEmpty {
                            Text(result.caption)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                        }
                    }

                    Section {
                        Button {
                            onImport(result)
                            dismiss()
                        } label: {
                            Label("이 내용으로 불러오기", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowInsets(.init(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
            .navigationTitle("Instagram에서 가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("가져오기") { Task { await fetch() } }
                        .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || {
                            if case .loading = state { return true }; return false
                        }())
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func fetch() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        state = .loading
        result = nil
        do {
            let imported = try await session.repo.importFromInstagram(url: trimmed)
            result = imported
            state = .done
        } catch {
            state = .failure(error.localizedDescription)
        }
    }
}
