import SwiftUI

// CV 전용 항목 추가/편집 — 기록하기와 달리 CV에 들어가는 최소 필드만, 타입별로.
//   연주: 연도·제목·주최·장소·설명 / 콩쿠르: 연도·대회명·장소·결과
//   학력: 기간·기관·학위 / 마스터클래스: 연도·기관·사사·장소
struct CVEntryComposerView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    let existing: CVEntryRow?
    let onDone: () -> Void

    @State private var kind: String
    @State private var yearText = ""
    @State private var period = ""
    @State private var title = ""
    @State private var org = ""
    @State private var place = ""
    @State private var detail = ""
    @State private var result = ""
    @State private var institution = ""
    @State private var degree = ""
    @State private var teacher = ""
    @State private var busy = false
    @State private var errorText: String?

    init(existing: CVEntryRow? = nil, initialKind: String = "performance", onDone: @escaping () -> Void) {
        self.existing = existing
        self.onDone = onDone
        _kind = State(initialValue: existing?.kind ?? initialKind)
    }

    private let kinds: [(code: String, label: String)] = [
        ("performance", localized("연주", "Performance", "Auftritt")),
        ("competition", localized("콩쿠르", "Competition", "Wettbewerb")),
        ("education",   localized("학력", "Education", "Ausbildung")),
        ("masterclass", localized("마스터클래스", "Masterclass", "Meisterkurs")),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(localized("유형", "Type", "Typ"), selection: $kind) {
                        ForEach(kinds, id: \.code) { Text($0.label).tag($0.code) }
                    }
                    .disabled(existing != nil)   // 편집 시 유형 고정
                }

                Section {
                    switch kind {
                    case "performance":
                        field(localized("연도", "Year", "Jahr"), $yearText, keyboard: .numberPad)
                        field(localized("제목", "Title", "Titel"), $title)
                        field(localized("주최", "Organizer", "Veranstalter"), $org)
                        field(localized("장소", "Place", "Ort"), $place)
                        field(localized("설명", "Detail", "Detail"), $detail)
                    case "competition":
                        field(localized("연도", "Year", "Jahr"), $yearText, keyboard: .numberPad)
                        field(localized("대회명", "Competition", "Wettbewerb"), $title)
                        field(localized("장소", "Place", "Ort"), $place)
                        field(localized("결과", "Result", "Ergebnis"), $result)
                    case "education":
                        field(localized("기간", "Period", "Zeitraum"), $period, placeholder: "2020 – 2024")
                        field(localized("기관", "Institution", "Institution"), $institution)
                        field(localized("학위", "Degree", "Abschluss"), $degree)
                    case "masterclass":
                        field(localized("연도", "Year", "Jahr"), $yearText, keyboard: .numberPad)
                        field(localized("기관/행사", "Institution", "Institution"), $institution)
                        field(localized("사사/강사", "Teacher", "Lehrer"), $teacher)
                        field(localized("장소", "Place", "Ort"), $place)
                    default: EmptyView()
                    }
                } footer: {
                    Text(localized("CV에 들어가는 간단한 내용만 입력하세요. 기록(활동)과는 별개입니다. 번역은 저장 후 ‘항목 영어화’에서.",
                                   "Enter only the brief content that appears on the CV. Separate from your activity records. Translate afterwards under ‘English per entry’.",
                                   "Nur kurze CV-Inhalte. Getrennt von den Aktivitäten. Übersetzung danach."))
                }
            }
            .navigationTitle(existing == nil
                             ? localized("항목 추가", "Add entry", "Eintrag hinzufügen")
                             : localized("항목 편집", "Edit entry", "Eintrag bearbeiten"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("취소", "Cancel", "Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() }
                    else { Button(localized("저장", "Save", "Speichern")) { Task { await save() } }
                        .fontWeight(.semibold).disabled(!isValid) }
                }
            }
            .alert(localized("오류", "Error", "Fehler"),
                   isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) {
                Button(localized("확인", "OK", "OK")) { errorText = nil }
            } message: { Text(errorText ?? "") }
            .onAppear(perform: loadExisting)
        }
    }

    private var isValid: Bool {
        let primary = kind == "education" || kind == "masterclass" ? institution : title
        return !primary.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func field(_ label: String, _ text: Binding<String>,
                       placeholder: String? = nil, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            TextField(placeholder ?? "", text: text)
                .multilineTextAlignment(.trailing).keyboardType(keyboard)
        }
    }

    private func loadExisting() {
        guard let e = existing else { return }
        yearText = e.year.map(String.init) ?? ""
        period = e.period ?? ""; title = e.title ?? ""; org = e.org ?? ""
        place = e.place ?? ""; detail = e.detail ?? ""; result = e.result ?? ""
        institution = e.institution ?? ""; degree = e.degree ?? ""; teacher = e.teacher ?? ""
    }

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true; errorText = nil
        func s(_ v: String) -> String? {
            let t = v.trimmingCharacters(in: .whitespacesAndNewlines); return t.isEmpty ? nil : t
        }
        // 학력은 기간 텍스트에서 정렬용 연도 추출, 그 외엔 연도 입력
        let yr: Int? = kind == "education"
            ? period.firstMatch4Digit
            : Int(yearText.trimmingCharacters(in: .whitespaces))
        var row = CVEntryRow(id: existing?.id ?? UUID(), kind: kind)
        row.year = yr; row.period = s(period); row.title = s(title); row.org = s(org)
        row.place = s(place); row.detail = s(detail); row.result = s(result)
        row.institution = s(institution); row.degree = s(degree); row.teacher = s(teacher)
        do {
            if existing == nil { try await session.repo.createCVEntry(userId: me, row) }
            else { try await session.repo.updateCVEntry(userId: me, row) }
            onDone()
            busy = false
            dismiss()
        } catch {
            errorText = error.localizedDescription
            busy = false
        }
    }
}

private extension String {
    /// 문자열에서 첫 4자리 연도 추출 (학력 기간 정렬용).
    var firstMatch4Digit: Int? {
        var digits = ""
        for ch in self {
            if ch.isNumber { digits.append(ch); if digits.count == 4 { return Int(digits) } }
            else { digits = "" }
        }
        return nil
    }
}
