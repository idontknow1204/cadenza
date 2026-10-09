import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss

    // Basic info
    @State private var realName = ""
    @State private var major = ""
    @State private var instrument = ""

    // Avatar
    @State private var pickerItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?

    // Affiliation
    @State private var institutionName = ""
    @State private var courseType: String? = nil
    @State private var enrollmentYear: Int = Calendar.current.component(.year, from: Date())
    @State private var schoolQuery = ""
    @State private var showSchoolSuggestions = false

    // Cities
    @State private var homeCities: Set<String> = []
    @State private var showCityPicker = false

    // Bio
    @State private var bio = ""

    // Visibility
    @State private var defaultVisibility: Visibility = .industryFollowers

    @State private var busy = false
    @State private var errorText: String?

    private var availableInstruments: [OnboardingData.LocalizedOption] {
        OnboardingData.instrumentsByMajor[major] ?? []
    }

    private var filteredSchools: [String] {
        guard !schoolQuery.isEmpty else { return [] }
        return OnboardingData.schools.filter {
            $0.localizedCaseInsensitiveContains(schoolQuery)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                basicSection
                affiliationSection
                citiesSection
                bioSection
                visibilitySection
            }
            .navigationTitle("profile.edit.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy {
                        ProgressView()
                    } else {
                        Button("profile.edit.save", action: { Task { await save() } })
                            .disabled(realName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showCityPicker) {
                CityPickerSheet(selectedIDs: $homeCities)
            }
            .alert("오류", isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) {
                Button("확인") { errorText = nil }
            } message: {
                Text(errorText ?? "")
            }
            .onAppear(perform: loadFromProfile)
            .task { await loadAffiliation() }
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Section {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    if let img = avatarImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else if let url = session.profile?.avatarUrl, let u = URL(string: url) {
                        AsyncImage(url: u) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            Color.secondary.opacity(0.2)
                        }
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.accentColor.opacity(0.3), lineWidth: 2))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .background(Circle().fill(.background))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
            .onChange(of: pickerItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let img = UIImage(data: data) else { return }
                    avatarImage = img
                }
            }
        }
    }

    private var basicSection: some View {
        Section("profile.edit.basic") {
            HStack {
                Text("profile.edit.name").foregroundStyle(.secondary)
                TextField("auth.name", text: $realName)
                    .multilineTextAlignment(.trailing)
            }
            Picker("onboarding.step2.major", selection: $major) {
                Text("profile.edit.none").tag("")
                ForEach(OnboardingData.majors) { m in
                    Text(m.localizedName).tag(m.id)
                }
            }
            if !availableInstruments.isEmpty {
                Picker("onboarding.step2.instrument", selection: $instrument) {
                    Text("profile.edit.none").tag("")
                    ForEach(availableInstruments) { i in
                        Text(i.localizedName).tag(i.id)
                    }
                }
            }
        }
        .onChange(of: major) { _, _ in
            if !availableInstruments.contains(where: { $0.id == instrument }) { instrument = "" }
        }
    }

    private var affiliationSection: some View {
        Section("profile.edit.affiliation") {
            VStack(alignment: .leading, spacing: 6) {
                TextField("onboarding.school.hint", text: $schoolQuery)
                    .onChange(of: schoolQuery) { _, v in
                        institutionName = v
                        showSchoolSuggestions = !v.isEmpty
                    }
                if showSchoolSuggestions && !filteredSchools.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredSchools.prefix(5), id: \.self) { school in
                            Button {
                                institutionName = school
                                schoolQuery = school
                                showSchoolSuggestions = false
                            } label: {
                                Text(school)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
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
            Picker("onboarding.year", selection: $enrollmentYear) {
                ForEach(OnboardingData.enrollmentYears, id: \.self) { yr in
                    Text(String(yr)).tag(yr)
                }
            }
        }
    }

    private var citiesSection: some View {
        Section("profile.edit.cities") {
            if !homeCities.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(Array(homeCities), id: \.self) { id in
                        if let city = OnboardingData.cityOptions.first(where: { $0.id == id }) {
                            HStack(spacing: 4) {
                                Text(city.localizedName).font(.subheadline)
                                Button {
                                    homeCities.remove(id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Button {
                showCityPicker = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(homeCities.isEmpty ? "onboarding.cities.search" : "onboarding.cities.add")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            .foregroundStyle(.primary)
        }
    }

    private var bioSection: some View {
        Section {
            HStack(alignment: .top) {
                TextEditor(text: $bio)
                    .frame(minHeight: 80)
                    .onChange(of: bio) { _, v in
                        if v.count > 300 { bio = String(v.prefix(300)) }
                    }
                Text("\(bio.count)/300")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        } header: {
            Text("onboarding.bio")
        }
    }

    private var visibilitySection: some View {
        Section("profile.edit.visibility") {
            Picker("profile.edit.visibility", selection: $defaultVisibility) {
                ForEach(Visibility.allCases) { v in
                    Text(LocalizedStringKey(v.labelKey)).tag(v)
                }
            }
        }
    }

    // MARK: - Data loading

    private func loadFromProfile() {
        guard let p = session.profile else { return }
        realName = p.realName
        major = p.major ?? ""
        instrument = p.instrument ?? ""
        bio = p.bio ?? ""
        defaultVisibility = p.defaultVisibility
        homeCities = Set(p.homeCities)
    }

    private func loadAffiliation() async {
        guard let me = session.currentUserID,
              let aff = try? await session.repo.affiliations(forUser: me).first else { return }
        institutionName = aff.institutionName
        schoolQuery = aff.institutionName
        courseType = aff.courseType
        enrollmentYear = aff.enrollmentYear ?? Calendar.current.component(.year, from: Date())
    }

    // MARK: - Save

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true; errorText = nil
        do {
            if let img = avatarImage {
                _ = try await session.repo.uploadAvatar(userId: me, image: img)
            }
            try await session.repo.updateBasicInfo(
                id: me,
                realName: realName.trimmingCharacters(in: .whitespaces),
                major: major.isEmpty ? nil : major,
                instrument: instrument.isEmpty ? nil : instrument
            )
            if !institutionName.isEmpty {
                try await session.repo.upsertAffiliation(
                    userId: me,
                    institutionName: institutionName,
                    courseType: courseType,
                    enrollmentYear: enrollmentYear
                )
            }
            try await session.repo.saveHomeCities(id: me, cities: Array(homeCities))
            try await session.repo.saveBio(id: me, bio: bio)
            try await session.repo.updateDefaultVisibility(id: me, visibility: defaultVisibility)
            await session.refreshProfile()
            busy = false
            dismiss()
        } catch {
            errorText = error.localizedDescription
            busy = false
        }
    }
}
