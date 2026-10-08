import SwiftUI

// MARK: - Filter state (§7)

struct JobFilter: Equatable {
    var types: Set<JobType> = []          // empty = all
    var instruments: Set<String> = []     // canonical ids; empty = all
    var countryCodes: Set<String> = []    // empty = all
    var videoOnly = false                 // 전형: 영상 예선 있음
    var freeOnly = false                  // 비용: 지원료 없음
    var scholarshipOnly = false           // 비용: 장학금 있음
    var openOnly = true                   // 상태: 모집 중만 (기본)

    /// Number of non-default filters (for the badge on the filter button).
    var activeCount: Int {
        var n = 0
        if !types.isEmpty { n += 1 }
        if !instruments.isEmpty { n += 1 }
        if !countryCodes.isEmpty { n += 1 }
        if videoOnly { n += 1 }
        if freeOnly { n += 1 }
        if scholarshipOnly { n += 1 }
        if !openOnly { n += 1 }
        return n
    }

    func apply(to jobs: [Job], cityByID: [String: City]) -> [Job] {
        jobs.filter { j in
            guard types.isEmpty || types.contains(j.type) else { return false }
            if !instruments.isEmpty,
               Set(j.instruments).isDisjoint(with: instruments) { return false }
            if !countryCodes.isEmpty {
                guard let cc = j.cityId.flatMap({ cityByID[$0]?.countryCode }),
                      countryCodes.contains(cc) else { return false }
            }
            if videoOnly, !(j.videoAudition ?? false) { return false }
            if freeOnly, j.applicationFee != 0 { return false }   // nil(미상) 제외
            if scholarshipOnly, !(j.hasScholarship ?? false) { return false }
            if openOnly, !j.isAcceptingApplications { return false }
            return true
        }
    }
}

// MARK: - Sort (§6/§7)

enum JobSort: String, CaseIterable, Identifiable {
    case cityFirst, deadline, recent
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cityFirst: return localized("내 도시 우선", "My city first", "Meine Stadt zuerst")
        case .deadline:  return localized("마감 임박순", "By deadline", "Nach Frist")
        case .recent:    return localized("최근 등록순", "Newest", "Neueste")
        }
    }
    var symbol: String {
        switch self {
        case .cityFirst: return "mappin.and.ellipse"
        case .deadline:  return "clock"
        case .recent:    return "sparkles"
        }
    }
}

/// Localized country name shared by the filter and the city-first sections.
func localizedCountryName(_ code: String) -> String {
    switch code {
    case "KR": return localized("한국", "Korea", "Südkorea")
    case "DE": return localized("독일", "Germany", "Deutschland")
    case "AT": return localized("오스트리아", "Austria", "Österreich")
    case "CH": return localized("스위스", "Switzerland", "Schweiz")
    case "FR": return localized("프랑스", "France", "Frankreich")
    case "GB": return localized("영국", "UK", "Vereinigtes Königreich")
    case "NL": return localized("네덜란드", "Netherlands", "Niederlande")
    case "IT": return localized("이탈리아", "Italy", "Italien")
    case "US": return localized("미국", "USA", "USA")
    default:   return code
    }
}

// MARK: - Filter sheet

struct JobFilterSheet: View {
    @Binding var filter: JobFilter
    @Binding var sort: JobSort
    let myInstrument: String?
    let availableCountries: [String]   // country codes present in the archive
    @Environment(\.dismiss) private var dismiss

    // Instruments sorted so the user's own instrument comes first.
    private var instrumentOptions: [OnboardingData.LocalizedOption] {
        let all = OnboardingData.allInstruments
        guard let mine = myInstrument else { return all }
        return all.sorted { a, b in
            (a.id == mine ? 0 : 1) < (b.id == mine ? 0 : 1)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(localized("정렬", "Sort", "Sortierung")) {
                    Picker(localized("정렬", "Sort", "Sortierung"), selection: $sort) {
                        ForEach(JobSort.allCases) { s in
                            Label(s.label, systemImage: s.symbol).tag(s)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section(localized("유형", "Type", "Art")) {
                    chipFlow(JobType.allCases.map { ($0.label, filter.types.contains($0)) }) { idx in
                        toggle(&filter.types, JobType.allCases[idx])
                    }
                }

                Section {
                    chipFlow(instrumentOptions.map {
                        ($0.localizedName + ($0.id == myInstrument ? " ★" : ""),
                         filter.instruments.contains($0.id))
                    }) { idx in
                        toggle(&filter.instruments, instrumentOptions[idx].id)
                    }
                } header: {
                    Text(localized("악기", "Instrument", "Instrument"))
                } footer: {
                    if myInstrument != nil {
                        Text(localized("★ 내 악기", "★ My instrument", "★ Mein Instrument"))
                    }
                }

                if !availableCountries.isEmpty {
                    Section(localized("지역", "Region", "Region")) {
                        chipFlow(availableCountries.map {
                            (localizedCountryName($0), filter.countryCodes.contains($0))
                        }) { idx in
                            toggle(&filter.countryCodes, availableCountries[idx])
                        }
                    }
                }

                Section(localized("전형·비용", "Format & cost", "Format & Kosten")) {
                    Toggle(localized("영상 예선 있음", "Video round available", "Video-Vorrunde"), isOn: $filter.videoOnly)
                    Toggle(localized("지원료 없음", "No application fee", "Keine Bewerbungsgebühr"), isOn: $filter.freeOnly)
                    Toggle(localized("장학금 있음", "Scholarship available", "Stipendium"), isOn: $filter.scholarshipOnly)
                }

                Section(localized("상태", "Status", "Status")) {
                    Toggle(localized("모집 중만 보기", "Open only", "Nur offene"), isOn: $filter.openOnly)
                }
            }
            .navigationTitle(localized("필터", "Filters", "Filter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localized("초기화", "Reset", "Zurücksetzen")) {
                        filter = JobFilter()
                        sort = .cityFirst
                    }
                    .disabled(filter == JobFilter() && sort == .cityFirst)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("완료", "Done", "Fertig")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func chipFlow(_ items: [(String, Bool)], onTap: @escaping (Int) -> Void) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                Button { onTap(idx) } label: {
                    Text(item.0)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(item.1 ? Color("BrandSurface") : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(item.1 ? Color.accentColor : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item.1 ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 2)
    }
}
