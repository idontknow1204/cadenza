import SwiftUI
import PhotosUI

struct EditActivityView: View {
    let item: ActivityWithAuthor

    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var type: ActivityType
    @State private var title: String
    @State private var date: Date
    @State private var location: String
    @State private var role: String
    @State private var program: String
    @State private var prize: String
    @State private var organizer: String
    @State private var personalNote: String
    @State private var visibility: Visibility = .industryFollowers

    @State private var existingImageUrls: [String]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var newImages: [UIImage] = []

    @State private var busy = false
    @State private var loadingFull = false
    @State private var errorText: String?

    private let performanceRoles = ["독주", "협연", "실내악", "반주", "오케스트라"]
    private let educationRoles   = ["수강/강의", "마스터클래스"]
    private let prizeShortcuts   = ["1위", "2위", "3위", "특별상", "입선", "파이널리스트"]

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(item: ActivityWithAuthor) {
        self.item = item
        let fmt = EditActivityView.dateFmt
        _type            = State(initialValue: item.type)
        _title           = State(initialValue: item.title)
        _date            = State(initialValue: fmt.date(from: item.activityDate) ?? Date())
        _location        = State(initialValue: item.location ?? "")
        _role            = State(initialValue: item.role ?? "")
        _program         = State(initialValue: item.program ?? "")
        _prize           = State(initialValue: item.prize ?? "")
        _organizer       = State(initialValue: item.organizer ?? "")
        _personalNote    = State(initialValue: item.personalNote ?? "")
        _existingImageUrls = State(initialValue: item.imageUrls)
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Type ──────────────────────────────────────────
                Section {
                    Picker("create.type", selection: $type) {
                        ForEach(ActivityType.allCases) { t in
                            Label(LocalizedStringKey(t.labelKey), systemImage: t.symbol).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // ── Common fields ─────────────────────────────────
                Section("create.details") {
                    TextField(LocalizedStringKey(type.titleHint), text: $title)
                    DatePicker(LocalizedStringKey(type.dateLabel), selection: $date,
                               displayedComponents: .date)
                    TextField(LocalizedStringKey(type.locationHint), text: $location)
                }

                // ── Type-specific ─────────────────────────────────
                typeSpecificSections

                // ── Images ────────────────────────────────────────
                imageSection

                // ── Visibility ────────────────────────────────────
                Section("create.visibility") {
                    if loadingFull {
                        HStack { ProgressView().scaleEffect(0.8); Text("불러오는 중...").foregroundStyle(.secondary) }
                    } else {
                        Picker("create.visibility", selection: $visibility) {
                            ForEach(Visibility.allCases) { v in
                                Text(LocalizedStringKey(v.labelKey)).tag(v)
                            }
                        }
                    }
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("게시글 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button("저장") { Task { await save() } }
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                            .fontWeight(.semibold)
                    }
                }
            }
            .task { await fetchFull() }
        }
    }

    // MARK: - Image section

    private var imageSection: some View {
        Section {
            // Existing images
            if !existingImageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(existingImageUrls.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                AsyncImage(url: URL(string: existingImageUrls[i])) { phase in
                                    if case .success(let img) = phase {
                                        img.resizable().scaledToFill()
                                    } else {
                                        Color.secondary.opacity(0.15)
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    existingImageUrls.remove(at: i)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.black.opacity(0.55))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                        // New images preview
                        ForEach(newImages.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: newImages[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button {
                                    newImages.remove(at: i)
                                    if i < pickerItems.count { pickerItems.remove(at: i) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.accentColor.opacity(0.8))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            } else if !newImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(newImages.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: newImages[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Button {
                                    newImages.remove(at: i)
                                    if i < pickerItems.count { pickerItems.remove(at: i) }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, Color.black.opacity(0.55))
                                }
                                .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }

            let totalCount = existingImageUrls.count + newImages.count
            let remaining = max(0, 5 - totalCount)
            if remaining > 0 {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: remaining,
                    matching: .images
                ) {
                    Label("create.images.add", systemImage: "photo.badge.plus")
                }
                .onChange(of: pickerItems) { _, items in
                    Task {
                        var imgs: [UIImage] = []
                        for pickerItem in items {
                            guard let data = try? await pickerItem.loadTransferable(type: Data.self),
                                  let img = UIImage(data: data) else { continue }
                            imgs.append(img)
                        }
                        newImages = imgs
                    }
                }
            }

            if totalCount > 0 {
                Text("create.images.count \(totalCount)/5")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text("create.images")
        }
    }

    // MARK: - Type-specific sections

    @ViewBuilder
    private var typeSpecificSections: some View {
        switch type {
        case .performance: performanceSections
        case .competition: competitionSections
        case .education:   educationSections
        case .recording:   recordingSections
        }
    }

    @ViewBuilder
    private var performanceSections: some View {
        Section("create.performance.role") {
            EditChipGrid(options: performanceRoles, selected: $role)
        }
        Section("create.performance.program") {
            TextField("create.performance.program.hint", text: $program, axis: .vertical)
                .lineLimit(3...8)
        }
        Section("create.performance.organizer") {
            TextField("create.performance.organizer", text: $organizer)
        }
    }

    @ViewBuilder
    private var competitionSections: some View {
        Section("create.competition.prize") {
            EditChipGrid(options: prizeShortcuts, selected: $prize)
            if !prize.isEmpty && !prizeShortcuts.contains(prize) {
                Text(prize).font(.subheadline).foregroundStyle(Color.accentColor)
            }
            TextField("create.competition.prize.hint", text: $prize)
                .font(.subheadline)
        }
        Section("create.competition.organizer") {
            TextField("create.competition.organizer", text: $organizer)
        }
        Section {
            TextField("이 경험에 대한 나만의 이야기나 감상을 남겨보세요 (선택)",
                      text: $personalNote, axis: .vertical)
                .lineLimit(3...8)
                .font(.subheadline)
        } header: { Text("나의 스토리 / 감상") }
    }

    @ViewBuilder
    private var educationSections: some View {
        Section("create.education.role") {
            EditChipGrid(options: educationRoles, selected: $role)
        }
        Section {
            TextField("배우면서 느낀 점이나 인상 깊었던 내용을 남겨보세요 (선택)",
                      text: $personalNote, axis: .vertical)
                .lineLimit(3...8)
                .font(.subheadline)
        } header: { Text("나의 스토리 / 감상") }
    }

    @ViewBuilder
    private var recordingSections: some View {
        Section("create.recording.role") {
            TextField("create.recording.role", text: $role)
        }
        Section("create.recording.program") {
            TextField("create.recording.program.hint", text: $program, axis: .vertical)
                .lineLimit(3...8)
        }
        Section {
            TextField("이 음반·미디어 작업에 담긴 이야기나 감상을 남겨보세요 (선택)",
                      text: $personalNote, axis: .vertical)
                .lineLimit(3...8)
                .font(.subheadline)
        } header: { Text("나의 스토리 / 감상") }
    }

    // MARK: - Fetch full activity (visibility + personalNote)

    private func fetchFull() async {
        loadingFull = true; defer { loadingFull = false }
        guard let full = try? await session.repo.activity(id: item.id) else { return }
        visibility    = full.visibility
        personalNote  = full.personalNote ?? personalNote
    }

    // MARK: - Save

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true; errorText = nil
        do {
            let payload = UpdateActivity(
                type:         type,
                title:        title.trimmingCharacters(in: .whitespaces),
                activityDate: Self.dateFmt.string(from: date),
                location:     location.isEmpty     ? nil : location,
                role:         role.isEmpty         ? nil : role,
                program:      program.isEmpty      ? nil : program,
                prize:        prize.isEmpty        ? nil : prize,
                organizer:    organizer.isEmpty    ? nil : organizer,
                personalNote: personalNote.isEmpty ? nil : personalNote,
                visibility:   visibility
            )
            try await session.repo.updateActivity(id: item.id, payload: payload)

            // Upload new images with UUID filenames to avoid path conflicts
            var uploadedUrls: [String] = []
            for img in newImages {
                guard let data = img.jpegData(compressionQuality: 0.82) else { continue }
                let url = try await session.repo.uploadActivityImageEdit(
                    userId: me,
                    activityId: item.id,
                    data: data
                )
                uploadedUrls.append(url)
            }
            let finalUrls = existingImageUrls + uploadedUrls
            try await session.repo.updateActivityImages(activityId: item.id, imageUrls: finalUrls)

            dismiss()
        } catch {
            errorText = error.localizedDescription
            busy = false
        }
    }
}

// MARK: - Chip grid (local copy so CreateActivityView's private version stays private)

private struct EditChipGrid: View {
    let options: [String]
    @Binding var selected: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { opt in
                Button {
                    selected = selected == opt ? "" : opt
                } label: {
                    Text(opt)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            selected == opt ? Color.accentColor : Color.secondary.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(selected == opt ? .white : .primary)
                        .animation(.easeInOut(duration: 0.12), value: selected)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
