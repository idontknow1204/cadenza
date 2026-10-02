import SwiftUI

struct RecommendationEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    var existing: Recommendation? = nil
    var recipientId: UUID
    var onSave: (Recommendation) -> Void
    var onDelete: (() -> Void)? = nil

    @State private var recommenderName = ""
    @State private var recommenderTitle = ""
    @State private var bodyText = ""
    @State private var isVisible = true
    @State private var busy = false
    @State private var showDeleteConfirm = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("추천인 정보") {
                    TextField("이름 (예: 정명훈)", text: $recommenderName)
                    TextField("직함·소속 (예: 서울시향 음악감독)", text: $recommenderTitle)
                }

                Section {
                    TextField("추천 내용을 입력하세요", text: $bodyText, axis: .vertical)
                        .lineLimit(5...15)
                } header: {
                    Text("추천서 내용")
                } footer: {
                    Text("추천서 원문 그대로 입력하거나, 주요 내용을 요약해서 입력할 수 있습니다.")
                }

                if existing != nil {
                    Section {
                        Toggle("프로필에 공개", isOn: $isVisible)
                    }

                    Section {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("추천서 삭제", systemImage: "trash")
                        }
                    }
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(existing == nil ? "추천서 추가" : "추천서 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() } else {
                        Button("저장", action: save)
                            .fontWeight(.semibold)
                            .disabled(recommenderName.trimmingCharacters(in: .whitespaces).isEmpty
                                      || bodyText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .confirmationDialog("추천서를 삭제하시겠어요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("삭제", role: .destructive) { Task { await delete() } }
                Button("취소", role: .cancel) {}
            }
            .onAppear {
                if let rec = existing {
                    recommenderName  = rec.recommenderName
                    recommenderTitle = rec.recommenderTitle ?? ""
                    bodyText         = rec.body
                    isVisible        = rec.isVisible
                }
            }
        }
    }

    private func save() {
        busy = true
        Task {
            do {
                let name  = recommenderName.trimmingCharacters(in: .whitespaces)
                let title = recommenderTitle.trimmingCharacters(in: .whitespaces)
                let content = bodyText.trimmingCharacters(in: .whitespaces)

                if let rec = existing {
                    try await session.repo.updateRecommendation(
                        id: rec.id, recommenderName: name,
                        recommenderTitle: title.isEmpty ? nil : title,
                        body: content, isVisible: isVisible)
                    var updated = rec
                    updated.recommenderName  = name
                    updated.recommenderTitle = title.isEmpty ? nil : title
                    updated.body      = content
                    updated.isVisible = isVisible
                    onSave(updated)
                } else {
                    let saved = try await session.repo.addRecommendation(
                        recipientId: recipientId,
                        recommenderName: name,
                        recommenderTitle: title.isEmpty ? nil : title,
                        body: content)
                    onSave(saved)
                }
                dismiss()
            } catch {
                errorText = error.localizedDescription
                busy = false
            }
        }
    }

    private func delete() async {
        guard let rec = existing else { return }
        busy = true
        do {
            try await session.repo.deleteRecommendation(id: rec.id)
            onDelete?()
            dismiss()
        } catch {
            errorText = error.localizedDescription
            busy = false
        }
    }
}
