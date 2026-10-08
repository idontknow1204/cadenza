import SwiftUI
import PhotosUI

struct CreateActivityView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// Delivers the completed post to the owning timeline immediately after a
    /// successful commit, avoiding a second network read just to display it.
    var onPost: ((ActivityWithAuthor) -> Void)? = nil

    @State private var type: ActivityType = .performance
    @State private var title = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var role = ""
    @State private var program = ""
    @State private var prize = ""
    @State private var organizer = ""
    @State private var visibility: Visibility = .industryFollowers

    // Images
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []

    @State private var people: [ProfileLite] = []
    @State private var taggedIDs: [UUID] = []
    @State private var tagSearch = ""

    @State private var personalNote = ""
    @State private var busy = false
    @State private var errorText: String?

    // Link preview
    @State private var linkInput = ""
    @State private var linkMetadata: LinkMetadata?
    @State private var linkLoading = false
    @State private var linkError: String?
    @State private var linkFetchTask: Task<Void, Never>?

    // Org posting
    @State private var myOrgs: [Organization] = []
    @State private var selectedOrgId: UUID? = nil

    // Instagram import
    @State private var showInstagramImport = false

    // Draft
    @State private var restoredFromDraft = false
    @State private var showCancelDialog = false
    @State private var draftSaveTask: Task<Void, Never>?

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Role / prize option lists (id = stored value, label = localized display)

    private var performanceRoleOptions: [(id: String, label: String)] {
        [
            ("독주",      localized("독주",      "Solo",           "Solo")),
            ("협연",      localized("협연",      "Concerto",       "Konzert")),
            ("실내악",    localized("실내악",    "Chamber music",  "Kammermusik")),
            ("반주",      localized("반주",      "Accompaniment",  "Begleitung")),
            ("오케스트라", localized("오케스트라", "Orchestra",     "Orchester")),
        ]
    }

    private var educationRoleOptions: [(id: String, label: String)] {
        [
            ("수강/강의",   localized("수강/강의",   "Attending / Teaching", "Teilnehmen/Lehren")),
            ("마스터클래스", localized("마스터클래스", "Masterclass",          "Meisterkurs")),
        ]
    }

    private var prizeOptions: [(id: String, label: String)] {
        [
            ("1위",      localized("1위",      "1st place",     "1. Preis")),
            ("2위",      localized("2위",      "2nd place",     "2. Preis")),
            ("3위",      localized("3위",      "3rd place",     "3. Preis")),
            ("특별상",    localized("특별상",    "Special award", "Sonderpreis")),
            ("입선",      localized("입선",      "Finalist",      "Finalist")),
            ("파이널리스트", localized("파이널리스트", "Semifinalist", "Semifinalist")),
        ]
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Draft restore banner ───────────────────────
                if restoredFromDraft {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text(verbatim: localized(
                                "이전에 작성하던 내용을 불러왔습니다",
                                "Draft restored",
                                "Entwurf wiederhergestellt"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            Spacer()
                            Button(localized("초기화", "Clear", "Löschen")) { clearDraft() }
                                .font(.footnote)
                        }
                    }
                }

                // ── Posting as ────────────────────────────────
                if !myOrgs.isEmpty {
                    Section {
                        Picker(selection: $selectedOrgId) {
                            Label(localized("개인으로", "As individual", "Als Einzelperson"), systemImage: "person.crop.circle")
                                .tag(Optional<UUID>.none)
                            ForEach(myOrgs) { org in
                                Label(org.name, systemImage: org.category.symbol)
                                    .tag(Optional(org.id))
                            }
                        } label: {
                            Text(verbatim: localized("게시 주체", "Post as", "Posten als"))
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Text(verbatim: localized("게시 주체", "Post as", "Posten als"))
                    }
                }

                // ── Type selector ──────────────────────────────
                Section {
                    Picker(selection: $type) {
                        ForEach(ActivityType.allCases) { t in
                            Label(t.localizedLabel, systemImage: t.symbol).tag(t)
                        }
                    } label: {
                        Text(verbatim: localized("활동 유형", "Type", "Art"))
                    }
                    .pickerStyle(.menu)
                    .onChange(of: type) { _, _ in
                        role = ""; program = ""; prize = ""; organizer = ""; personalNote = ""
                    }
                }

                // ── Common fields (type-aware hints) ───────────
                Section {
                    TextField(text: $title) {
                        Text(verbatim: type.localizedTitleHint)
                    }
                    DatePicker(selection: $date, displayedComponents: .date) {
                        Text(verbatim: type.localizedDateLabel)
                    }
                    TextField(text: $location) {
                        Text(verbatim: type.localizedLocationHint)
                    }
                } header: {
                    Text(verbatim: localized("상세", "Details", "Details"))
                }

                // ── Type-specific extras ───────────────────────
                typeSpecificSections

                // ── Images ────────────────────────────────────
                imageSection

                // ── Link preview ──────────────────────────────
                linkSection

                // ── Tag ───────────────────────────────────────
                Section {
                    if !taggedIDs.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(taggedIDs, id: \.self) { uid in
                                    if let p = people.first(where: { $0.id == uid }) {
                                        HStack(spacing: 4) {
                                            Text(p.realName).font(.caption)
                                            Button { taggedIDs.removeAll { $0 == uid } } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                                        .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    TextField(text: $tagSearch) {
                        Text(verbatim: localized("이름으로 검색", "Search by name", "Nach Name suchen"))
                    }
                    .autocorrectionDisabled()
                    let filtered = tagSearch.isEmpty ? []
                        : people.filter { $0.realName.localizedCaseInsensitiveContains(tagSearch) }
                    ForEach(filtered.prefix(8)) { p in
                        Button {
                            if taggedIDs.contains(p.id) {
                                taggedIDs.removeAll { $0 == p.id }
                            } else {
                                taggedIDs.append(p.id)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.realName).font(.subheadline)
                                    if let inst = p.instrument {
                                        Text(inst).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if taggedIDs.contains(p.id) {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                } header: {
                    Text(verbatim: localized("함께한 사람 태그", "Tag people", "Personen markieren"))
                }

                // ── Visibility ────────────────────────────────
                Section {
                    Picker(selection: $visibility) {
                        ForEach(Visibility.allCases) { v in
                            Text(verbatim: v.localizedLabel).tag(v)
                        }
                    } label: {
                        Text(verbatim: localized("공개 범위", "Visibility", "Sichtbarkeit"))
                    }
                } header: {
                    Text(verbatim: localized("공개 범위", "Visibility", "Sichtbarkeit"))
                }

                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(localized("기록하기", "New record", "Neuer Eintrag"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showInstagramImport) {
                InstagramImportView { imported in
                    if !imported.caption.isEmpty { personalNote = imported.caption }
                    if let thumbUrl = imported.thumbnailUrl {
                        Task {
                            guard let url = URL(string: thumbUrl),
                                  let (data, _) = try? await URLSession.shared.data(from: url),
                                  let img = UIImage(data: data) else { return }
                            selectedImages = [img]
                        }
                    }
                }
            }
            .confirmationDialog(
                localized("작성 중인 내용이 있어요", "You have unsaved content", "Inhalt nicht gespeichert"),
                isPresented: $showCancelDialog,
                titleVisibility: .visible
            ) {
                Button(localized("임시저장", "Save draft", "Entwurf speichern")) {
                    draftSaveTask?.cancel()
                    makeDraft().save()
                    dismiss()
                }
                Button(localized("버리기", "Discard", "Verwerfen"), role: .destructive) {
                    ActivityDraft.clear()
                    dismiss()
                }
                Button(localized("계속 작성", "Keep editing", "Weiter bearbeiten"), role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("취소", "Cancel", "Abbrechen")) { cancelTapped() }
                        .disabled(busy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button(localized("게시", "Post", "Posten"), action: post)
                            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                            .fontWeight(.semibold)
                    }
                }
            }
            .task { loadDraft(); await loadPeople() }
            .onChange(of: title)        { _, _ in scheduleDraftSave() }
            .onChange(of: location)     { _, _ in scheduleDraftSave() }
            .onChange(of: role)         { _, _ in scheduleDraftSave() }
            .onChange(of: program)      { _, _ in scheduleDraftSave() }
            .onChange(of: prize)        { _, _ in scheduleDraftSave() }
            .onChange(of: organizer)    { _, _ in scheduleDraftSave() }
            .onChange(of: personalNote) { _, _ in scheduleDraftSave() }
            .onChange(of: linkInput)    { _, _ in scheduleDraftSave() }
            .onChange(of: date)         { _, _ in scheduleDraftSave() }
            .onChange(of: type)         { _, _ in scheduleDraftSave() }
            .onChange(of: visibility)   { _, _ in scheduleDraftSave() }
            .onChange(of: selectedOrgId){ _, _ in scheduleDraftSave() }
        }
        .interactiveDismissDisabled(busy)
    }

    // MARK: - Image section

    private var imageSection: some View {
        Section {
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedImages.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: selectedImages[i])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Button {
                                    selectedImages.remove(at: i)
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

            PhotosPicker(
                selection: $pickerItems,
                maxSelectionCount: 5,
                matching: .images
            ) {
                Label(
                    selectedImages.isEmpty
                        ? localized("사진 추가", "Add photos", "Fotos hinzufügen")
                        : localized("사진 변경", "Change photos", "Fotos ändern"),
                    systemImage: "photo.badge.plus"
                )
            }
            .onChange(of: pickerItems) { _, items in
                Task {
                    var imgs: [UIImage] = []
                    for item in items {
                        guard let data = try? await item.loadTransferable(type: Data.self),
                              let img = UIImage(data: data) else { continue }
                        imgs.append(img)
                    }
                    selectedImages = imgs
                }
            }

            Button {
                showInstagramImport = true
            } label: {
                Label(localized("Instagram에서 불러오기", "Import from Instagram", "Von Instagram importieren"), systemImage: "link")
            }

            if !selectedImages.isEmpty {
                Text(verbatim: "\(localized("선택한 사진", "Selected", "Ausgewählt")) \(selectedImages.count)/5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(verbatim: localized("사진", "Photos", "Fotos"))
        }
    }

    // MARK: - Link section

    private var linkSection: some View {
        Section {
            if linkLoading || linkMetadata != nil {
                LinkPreviewComposerCard(
                    urlString: linkMetadata?.url ?? LinkMetadataFetcher.normalized(linkInput) ?? linkInput,
                    isLoading: linkLoading,
                    metadata: linkMetadata,
                    errorText: linkError,
                    onRemove: clearLink
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } else {
                TextField(text: $linkInput) {
                    Text(verbatim: "https://…")
                }
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit { scheduleLinkFetch(linkInput) }
            }
        } header: {
            Text(verbatim: localized("링크", "Link", "Link"))
        } footer: {
            if linkMetadata == nil && !linkLoading {
                Text(verbatim: localized(
                    "기사·영상 등 링크를 붙여넣으면 미리보기 카드가 함께 게시됩니다.",
                    "Paste an article or video link to attach a preview card.",
                    "Füge einen Link ein, um eine Vorschaukarte anzuhängen."))
            }
        }
        .onChange(of: linkInput) { _, value in scheduleLinkFetch(value) }
    }

    private func scheduleLinkFetch(_ raw: String) {
        linkFetchTask?.cancel()
        linkError = nil
        guard let normalized = LinkMetadataFetcher.normalized(raw) else {
            linkLoading = false
            linkMetadata = nil
            return
        }
        linkLoading = true
        linkFetchTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if Task.isCancelled { return }
            do {
                let meta = try await LinkMetadataFetcher.fetch(normalized)
                if Task.isCancelled { return }
                await MainActor.run {
                    linkMetadata = meta
                    linkLoading = false
                    linkError = nil
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    // Keep the bare URL so it still posts as a simple link card.
                    linkMetadata = LinkMetadata(url: normalized, title: nil, description: nil,
                                                imageUrl: nil, siteName: nil)
                    linkLoading = false
                    linkError = (error as? LinkMetadataError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }

    private func clearLink() {
        linkFetchTask?.cancel()
        linkInput = ""
        linkMetadata = nil
        linkLoading = false
        linkError = nil
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
        Section {
            ChipGrid(options: performanceRoleOptions, selected: $role)
        } header: {
            Text(verbatim: localized("역할", "Role", "Rolle"))
        }
        Section {
            TextField(text: $program, axis: .vertical) {
                Text(verbatim: localized("곡목을 입력하세요…", "List repertoire…", "Repertoire eingeben…"))
            }
            .lineLimit(3...8)
        } header: {
            Text(verbatim: localized("레퍼토리", "Repertoire", "Repertoire"))
        }
        Section {
            TextField(text: $organizer) {
                Text(verbatim: localized("주최", "Organizer", "Veranstalter"))
            }
        } header: {
            Text(verbatim: localized("주최", "Organizer", "Veranstalter"))
        }
        Section {
            TextField(text: $personalNote, axis: .vertical) {
                Text(verbatim: localized("이 연주에 대한 나만의 이야기나 감상을 남겨보세요 (선택)",
                                        "Share your personal story or reflection (optional)",
                                        "Persönliche Reflexion (optional)"))
            }
            .lineLimit(3...8)
            .font(.subheadline)
        } header: {
            Text(verbatim: localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"))
        }
    }

    @ViewBuilder
    private var competitionSections: some View {
        Section {
            ChipGrid(options: prizeOptions, selected: $prize)
            if !prize.isEmpty && !prizeOptions.map(\.id).contains(prize) {
                Text(prize).font(.subheadline).foregroundStyle(Color.accentColor)
            }
            TextField(text: $prize) {
                Text(verbatim: localized("직접 입력…", "Or type custom result…", "Oder eigene Eingabe…"))
            }
            .font(.subheadline)
        } header: {
            Text(verbatim: localized("결과·수상", "Result", "Ergebnis"))
        }
        Section {
            TextField(text: $organizer) {
                Text(verbatim: localized("주최", "Organizer", "Veranstalter"))
            }
        } header: {
            Text(verbatim: localized("주최", "Organizer", "Veranstalter"))
        }
        Section {
            TextField(text: $personalNote, axis: .vertical) {
                Text(verbatim: localized("이 경험에 대한 나만의 이야기나 감상을 남겨보세요 (선택)",
                                        "Share your personal story or reflection (optional)",
                                        "Persönliche Reflexion (optional)"))
            }
            .lineLimit(3...8)
            .font(.subheadline)
        } header: {
            Text(verbatim: localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"))
        }
    }

    @ViewBuilder
    private var educationSections: some View {
        Section {
            ChipGrid(options: educationRoleOptions, selected: $role)
        } header: {
            Text(verbatim: localized("역할", "Role", "Rolle"))
        }
        Section {
            TextField(text: $personalNote, axis: .vertical) {
                Text(verbatim: localized("배우면서 느낀 점이나 인상 깊었던 내용을 남겨보세요 (선택)",
                                        "Share what you learned or found memorable (optional)",
                                        "Teile, was du gelernt oder bemerkenswert fandest (optional)"))
            }
            .lineLimit(3...8)
            .font(.subheadline)
        } header: {
            Text(verbatim: localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"))
        }
    }

    @ViewBuilder
    private var recordingSections: some View {
        Section {
            TextField(text: $role) {
                Text(verbatim: localized("역할", "Role", "Rolle"))
            }
        } header: {
            Text(verbatim: localized("역할", "Role", "Rolle"))
        }
        Section {
            TextField(text: $program, axis: .vertical) {
                Text(verbatim: localized("수록곡 목록…", "List tracks…", "Tracks eingeben…"))
            }
            .lineLimit(3...8)
        } header: {
            Text(verbatim: localized("수록곡", "Track list", "Trackliste"))
        }
        Section {
            TextField(text: $personalNote, axis: .vertical) {
                Text(verbatim: localized("이 음반·미디어 작업에 담긴 이야기나 감상을 남겨보세요 (선택)",
                                        "Share the story or reflection behind this recording (optional)",
                                        "Geschichte oder Reflexion zur Aufnahme (optional)"))
            }
            .lineLimit(3...8)
            .font(.subheadline)
        } header: {
            Text(verbatim: localized("나의 스토리 / 감상", "My story / Reflection", "Meine Geschichte / Reflexion"))
        }
    }

    // MARK: - Draft

    private func makeDraft() -> ActivityDraft {
        ActivityDraft(
            type: type, title: title, date: date, location: location,
            role: role, program: program, prize: prize, organizer: organizer,
            visibility: visibility, personalNote: personalNote,
            linkInput: linkInput, selectedOrgId: selectedOrgId
        )
    }

    private func loadDraft() {
        guard let draft = ActivityDraft.load(), !draft.isEmpty else { return }
        type = draft.type
        title = draft.title
        date = draft.date
        location = draft.location
        role = draft.role
        program = draft.program
        prize = draft.prize
        organizer = draft.organizer
        visibility = draft.visibility
        personalNote = draft.personalNote
        linkInput = draft.linkInput
        selectedOrgId = draft.selectedOrgId
        restoredFromDraft = true
    }

    private func scheduleDraftSave() {
        draftSaveTask?.cancel()
        draftSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            makeDraft().save()
        }
    }

    private func cancelTapped() {
        if makeDraft().isEmpty {
            ActivityDraft.clear()
            dismiss()
        } else {
            showCancelDialog = true
        }
    }

    private func clearDraft() {
        type = .performance
        title = ""
        date = Date()
        location = ""
        role = ""
        program = ""
        prize = ""
        organizer = ""
        visibility = .industryFollowers
        personalNote = ""
        clearLink()
        selectedOrgId = nil
        restoredFromDraft = false
        ActivityDraft.clear()
    }

    // MARK: - Helpers

    private func loadPeople() async {
        guard let me = session.currentUserID else { return }
        async let peopleTask = session.repo.people(excluding: me)
        async let orgsTask   = session.repo.myOrgs(userId: me)
        people = (try? await peopleTask) ?? []
        myOrgs = (try? await orgsTask) ?? []
    }

    private func post() {
        guard let me = session.currentUserID else { return }
        busy = true; errorText = nil
        // Fall back to a bare URL if the user pasted a link but the preview
        // never resolved (e.g. posted before the fetch finished).
        let link = linkMetadata ?? LinkMetadataFetcher.normalized(linkInput).map {
            LinkMetadata(url: $0, title: nil, description: nil, imageUrl: nil, siteName: nil)
        }
        Task {
            do {
                let payload = NewActivity(
                    userId: me,
                    orgId: selectedOrgId,
                    type: type,
                    title: title.trimmingCharacters(in: .whitespaces),
                    activityDate: Self.dateFmt.string(from: date),
                    location: location.isEmpty ? nil : location,
                    role: role.isEmpty ? nil : role,
                    program: program.isEmpty ? nil : program,
                    prize: prize.isEmpty ? nil : prize,
                    organizer: organizer.isEmpty ? nil : organizer,
                    personalNote: personalNote.isEmpty ? nil : personalNote,
                    visibility: visibility,
                    linkUrl: link?.url,
                    linkTitle: link?.title,
                    linkDescription: link?.description,
                    linkImageUrl: link?.imageUrl,
                    linkSiteName: link?.siteName
                )
                let imageData = selectedImages.compactMap { $0.jpegData(compressionQuality: 0.82) }
                let created = try await session.repo.createActivity(
                    payload,
                    imageData: imageData,
                    taggedUserIds: taggedIDs
                )
                let author = session.profile.map {
                    ProfileLite(id: $0.id, realName: $0.realName, instrument: $0.instrument, avatarUrl: $0.avatarUrl)
                }
                let org = myOrgs.first(where: { $0.id == selectedOrgId }).map {
                    OrgSummary(id: $0.id, name: $0.name, logoUrl: $0.logoUrl, category: $0.category)
                }
                let completed = ActivityWithAuthor(
                    activity: created,
                    author: author,
                    org: org,
                    feedReason: "own"
                )
                ActivityDraft.clear()
                onPost?(completed)
                dismiss()
            } catch {
                errorText = error.localizedDescription
                busy = false
            }
        }
    }
}

// MARK: - Chip grid (role / prize quick-select)

private struct ChipGrid: View {
    let options: [(id: String, label: String)]
    @Binding var selected: String
    @ScaledMetric(relativeTo: .subheadline) private var minimumColumnWidth = 100.0

    init(options: [(id: String, label: String)], selected: Binding<String>) {
        self.options = options
        self._selected = selected
    }

    var body: some View {
        EqualHeightChipLayout(minimumColumnWidth: minimumColumnWidth) {
            ForEach(options, id: \.id) { opt in
                chipButton(opt)
            }
        }
        .padding(.vertical, 4)
    }

    private func chipButton(_ opt: (id: String, label: String)) -> some View {
        Button {
            selected = selected == opt.id ? "" : opt.id
        } label: {
            Text(opt.label)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    selected == opt.id ? Color.accentColor : Color.secondary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(selected == opt.id ? .white : .primary)
                .animation(.easeInOut(duration: 0.12), value: selected)
        }
        .buttonStyle(.plain)
    }
}

// Measure intrinsic button heights at the available column width. Placement uses
// that result directly, without writing rendered geometry back into view state.
private struct EqualHeightChipLayout: Layout {
    var minimumColumnWidth: CGFloat
    var spacing: CGFloat = 8

    private struct Metrics {
        var columns: Int
        var columnWidth: CGFloat
        var rowHeight: CGFloat
        var size: CGSize
    }

    private func metrics(width: CGFloat?, subviews: Subviews) -> Metrics {
        let proposedWidth = width ?? minimumColumnWidth
        let width = proposedWidth.isFinite ? max(0, proposedWidth) : minimumColumnWidth
        guard !subviews.isEmpty else {
            return Metrics(columns: 1, columnWidth: width, rowHeight: 0, size: .zero)
        }
        let columns = max(1, min(subviews.count, Int((width + spacing) / (minimumColumnWidth + spacing))))
        let columnWidth = max(0, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        let proposal = ProposedViewSize(width: columnWidth, height: nil)
        let rowHeight = max(44, subviews.map { $0.sizeThatFits(proposal).height }.max() ?? 0)
        let rows = (subviews.count + columns - 1) / columns
        return Metrics(columns: columns, columnWidth: columnWidth, rowHeight: rowHeight,
                       size: CGSize(width: width, height: CGFloat(rows) * rowHeight + CGFloat(rows - 1) * spacing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        metrics(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = metrics(width: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let column = index % layout.columns
            let row = index / layout.columns
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(column) * (layout.columnWidth + spacing),
                            y: bounds.minY + CGFloat(row) * (layout.rowHeight + spacing)),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: layout.columnWidth, height: layout.rowHeight)
            )
        }
    }
}
