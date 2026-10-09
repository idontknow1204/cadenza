import SwiftUI

struct Step3AffiliationView: View {
    @Bindable var coordinator: OnboardingCoordinator
    @Environment(SessionStore.self) private var session

    @State private var schoolQuery = ""
    @State private var showSuggestions = false
    @State private var showCityPicker = false

    private var filteredSchools: [String] {
        guard !schoolQuery.isEmpty else { return [] }
        return OnboardingData.schools.filter {
            $0.localizedCaseInsensitiveContains(schoolQuery)
        }
    }

    /// Display names of selected cities for the current locale.
    private var selectedCityNames: [String] {
        coordinator.homeCities.compactMap { id in
            OnboardingData.cityOptions.first { $0.id == id }?.localizedName
        }.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    schoolSection
                    courseSection
                    yearSection
                    citySection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            Spacer(minLength: 0)
            OnboardingBottomBar(
                primaryLabel: "onboarding.next",
                primaryAction: {
                    Task { await coordinator.saveStep3(repo: session.repo, userID: session.currentUserID!) }
                },
                primaryDisabled: coordinator.institutionName.isEmpty,
                isBusy: coordinator.isBusy
            )
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerSheet(selectedIDs: $coordinator.homeCities)
        }
    }

    // MARK: – Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("onboarding.step3.title").font(.largeTitle.bold())
            Text("onboarding.step3.desc").foregroundStyle(.secondary)
        }
    }

    private var schoolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("onboarding.school").font(.headline)
            TextField("onboarding.school.hint", text: $schoolQuery)
                .textFieldStyle(.roundedBorder)
                .onChange(of: schoolQuery) { _, v in
                    coordinator.institutionName = v
                    showSuggestions = !v.isEmpty
                }
                .onAppear { schoolQuery = coordinator.institutionName }

            if showSuggestions && !filteredSchools.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(filteredSchools.prefix(6), id: \.self) { school in
                        Button {
                            coordinator.institutionName = school
                            schoolQuery = school
                            showSuggestions = false
                        } label: {
                            Text(school)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
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
    }

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("onboarding.course").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                ForEach(OnboardingData.courseOptions) { option in
                    SelectChip(
                        label: option.label,
                        selected: coordinator.courseType == option.id
                    ) { coordinator.courseType = option.id }
                }
            }
        }
    }

    private var yearSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("onboarding.year").font(.headline)
            Picker("onboarding.year", selection: $coordinator.enrollmentYear) {
                ForEach(OnboardingData.enrollmentYears, id: \.self) { yr in
                    Text(String(yr)).tag(yr)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
        }
    }

    private var citySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("onboarding.cities").font(.headline)
                Text("onboarding.cities.hint").font(.caption).foregroundStyle(.secondary)
            }

            // Selected cities as removable chips
            if !coordinator.homeCities.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(Array(coordinator.homeCities), id: \.self) { id in
                        if let city = OnboardingData.cityOptions.first(where: { $0.id == id }) {
                            HStack(spacing: 4) {
                                Text(city.localizedName).font(.subheadline)
                                Button {
                                    coordinator.homeCities.remove(id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.12),
                                        in: Capsule())
                        }
                    }
                }
            }

            // Open picker button
            Button {
                showCityPicker = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(coordinator.homeCities.isEmpty
                         ? "onboarding.cities.search"
                         : "onboarding.cities.add")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .font(.subheadline)
                .padding(12)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .foregroundStyle(.primary)
        }
    }
}

// MARK: – City Picker Sheet

struct CityPickerSheet: View {
    @Binding var selectedIDs: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredGroups: [(country: String, flag: String, cities: [OnboardingData.CityOption])] {
        if query.isEmpty { return OnboardingData.cityGroups }
        let q = query.lowercased()
        return OnboardingData.cityGroups.compactMap { group in
            let matches = group.cities.filter {
                $0.ko.lowercased().contains(q) ||
                $0.en.lowercased().contains(q) ||
                $0.de.lowercased().contains(q) ||
                $0.localizedName.lowercased().contains(q)
            }
            return matches.isEmpty ? nil : (group.country, group.flag, matches)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups, id: \.country) { group in
                    Section {
                        ForEach(group.cities) { city in
                            Button {
                                if selectedIDs.contains(city.id) {
                                    selectedIDs.remove(city.id)
                                } else {
                                    selectedIDs.insert(city.id)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(city.localizedName).font(.subheadline.weight(.medium))
                                        if city.localizedName != city.en {
                                            Text(city.en).font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedIDs.contains(city.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        Text(group.country)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, prompt: Text("onboarding.cities.search"))
            .navigationTitle("onboarding.cities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.ok") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: – Flow layout (wrapping chip container)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
