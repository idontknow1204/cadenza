import Foundation

/// CV 항목 하나(활동/학적)에서 영어로 확정할 필드 한 개.
struct CVFieldSpec: Identifiable {
    let key: String        // cv_i18n patch 키: title/org/place/detail/result/institution/degree/teacher
    let label: String
    let original: String?  // 원문(placeholder·참고용)
    var id: String { key }
}

/// 편집기에 나열되는 CV 항목. activities + affiliations 를 한 목록으로 정규화.
struct CVEntry: Identifiable {
    let id: String            // "activity:<uuid>" | "affiliation:<uuid>"
    let sourceKind: String    // "activity" | "affiliation"
    let sourceId: UUID
    let kind: String          // performance | competition | masterclass | education (번역 문맥용)
    let sectionLabel: String  // 연주 / 콩쿠르 / 마스터클래스 / 학력
    let titleOriginal: String
    let subtitleOriginal: String?
    let fields: [CVFieldSpec]

    static func build(activities: [Activity], affiliations: [Affiliation],
                      cvEntries: [CVEntryRow] = [],
                      careers: [Career] = [], awards: [ProfileAward] = []) -> [CVEntry] {
        var out: [CVEntry] = []

        let titleLabel  = localized("제목", "Title", "Titel")
        let orgLabel    = localized("주최/기관", "Organization", "Veranstalter")
        let placeLabel  = localized("장소", "Place", "Ort")
        let detailLabel = localized("설명", "Detail", "Detail")
        let resultLabel = localized("결과", "Result", "Ergebnis")
        let instLabel   = localized("기관명", "Institution", "Institution")
        let degreeLabel = localized("학위", "Degree", "Abschluss")
        let teacherLabel = localized("사사 교수", "Teacher", "Lehrer")
        let roleLabel     = localized("역할", "Role", "Rolle")
        let contribLabel  = localized("기여", "Contribution", "Beitrag")
        let issuerLabel   = localized("주최", "Issuer", "Veranstalter")
        let prizeLabel    = localized("수상", "Prize", "Preis")

        for a in activities {
            let idKey = "activity:\(a.id.uuidString)"
            switch a.type {
            case .performance:
                out.append(CVEntry(
                    id: idKey, sourceKind: "activity", sourceId: a.id, kind: "performance",
                    sectionLabel: localized("연주", "Performance", "Auftritt"),
                    titleOriginal: a.title, subtitleOriginal: a.organizer,
                    fields: [
                        CVFieldSpec(key: "title", label: titleLabel, original: a.title),
                        CVFieldSpec(key: "org",   label: orgLabel,   original: a.organizer),
                        CVFieldSpec(key: "place", label: placeLabel, original: a.location),
                        CVFieldSpec(key: "detail", label: detailLabel, original: a.role),
                    ]))
            case .competition:
                out.append(CVEntry(
                    id: idKey, sourceKind: "activity", sourceId: a.id, kind: "competition",
                    sectionLabel: localized("콩쿠르", "Competition", "Wettbewerb"),
                    titleOriginal: a.title, subtitleOriginal: a.prize,
                    fields: [
                        CVFieldSpec(key: "title",  label: titleLabel,  original: a.title),
                        CVFieldSpec(key: "place",  label: placeLabel,  original: a.location),
                        CVFieldSpec(key: "result", label: resultLabel, original: a.prize),
                    ]))
            case .education:
                // activities type=education = 마스터클래스/아카데미 (날짜 있는 이벤트)
                out.append(CVEntry(
                    id: idKey, sourceKind: "activity", sourceId: a.id, kind: "masterclass",
                    sectionLabel: localized("마스터클래스", "Masterclass", "Meisterkurs"),
                    titleOriginal: a.title, subtitleOriginal: a.location,
                    fields: [
                        CVFieldSpec(key: "institution", label: instLabel,    original: a.title),
                        CVFieldSpec(key: "place",       label: placeLabel,   original: a.location),
                        CVFieldSpec(key: "teacher",     label: teacherLabel, original: a.role ?? a.organizer),
                    ]))
            case .recording:
                continue   // CV 에는 녹음 섹션이 없음
            }
        }

        for af in affiliations {
            out.append(CVEntry(
                id: "affiliation:\(af.id.uuidString)", sourceKind: "affiliation", sourceId: af.id,
                kind: "education",
                sectionLabel: localized("학력", "Education", "Ausbildung"),
                titleOriginal: af.institutionName, subtitleOriginal: nil,
                fields: [
                    CVFieldSpec(key: "institution", label: instLabel,   original: af.institutionName),
                    CVFieldSpec(key: "degree",      label: degreeLabel, original: nil),
                ]))
        }

        // CV 전용 항목 (cv_entries) — 오버레이(언어별) 편집 대상으로도 포함
        for ce in cvEntries {
            let idKey = "cv_entry:\(ce.id.uuidString)"
            switch ce.kind {
            case "performance":
                out.append(CVEntry(
                    id: idKey, sourceKind: "cv_entry", sourceId: ce.id, kind: "performance",
                    sectionLabel: localized("연주", "Performance", "Auftritt"),
                    titleOriginal: ce.title ?? "", subtitleOriginal: ce.org,
                    fields: [
                        CVFieldSpec(key: "title", label: titleLabel, original: ce.title),
                        CVFieldSpec(key: "org",   label: orgLabel,   original: ce.org),
                        CVFieldSpec(key: "place", label: placeLabel, original: ce.place),
                        CVFieldSpec(key: "detail", label: detailLabel, original: ce.detail),
                    ]))
            case "competition":
                out.append(CVEntry(
                    id: idKey, sourceKind: "cv_entry", sourceId: ce.id, kind: "competition",
                    sectionLabel: localized("콩쿠르", "Competition", "Wettbewerb"),
                    titleOriginal: ce.title ?? "", subtitleOriginal: ce.result,
                    fields: [
                        CVFieldSpec(key: "title",  label: titleLabel,  original: ce.title),
                        CVFieldSpec(key: "place",  label: placeLabel,  original: ce.place),
                        CVFieldSpec(key: "result", label: resultLabel, original: ce.result),
                    ]))
            case "education":
                out.append(CVEntry(
                    id: idKey, sourceKind: "cv_entry", sourceId: ce.id, kind: "education",
                    sectionLabel: localized("학력", "Education", "Ausbildung"),
                    titleOriginal: ce.institution ?? "", subtitleOriginal: ce.degree,
                    fields: [
                        CVFieldSpec(key: "institution", label: instLabel,   original: ce.institution),
                        CVFieldSpec(key: "degree",      label: degreeLabel, original: ce.degree),
                    ]))
            case "masterclass":
                out.append(CVEntry(
                    id: idKey, sourceKind: "cv_entry", sourceId: ce.id, kind: "masterclass",
                    sectionLabel: localized("마스터클래스", "Masterclass", "Meisterkurs"),
                    titleOriginal: ce.institution ?? "", subtitleOriginal: ce.teacher,
                    fields: [
                        CVFieldSpec(key: "institution", label: instLabel,    original: ce.institution),
                        CVFieldSpec(key: "place",       label: placeLabel,   original: ce.place),
                        CVFieldSpec(key: "teacher",     label: teacherLabel, original: ce.teacher),
                    ]))
            default:
                break
            }
        }

        // 경력 (career) — 프로필 전용 항목
        for c in careers {
            out.append(CVEntry(
                id: "career:\(c.id.uuidString)", sourceKind: "career", sourceId: c.id,
                kind: "career",
                sectionLabel: localized("경력", "Career", "Werdegang"),
                titleOriginal: c.organization, subtitleOriginal: c.role,
                fields: [
                    CVFieldSpec(key: "organization", label: orgLabel,    original: c.organization),
                    CVFieldSpec(key: "role",         label: roleLabel,   original: c.role),
                    CVFieldSpec(key: "description",  label: detailLabel, original: c.description),
                    CVFieldSpec(key: "contribution", label: contribLabel, original: c.contribution),
                ]))
        }

        // 수상 (award) — 프로필 전용 항목
        for aw in awards {
            out.append(CVEntry(
                id: "award:\(aw.id.uuidString)", sourceKind: "award", sourceId: aw.id,
                kind: "award",
                sectionLabel: localized("수상", "Awards", "Auszeichnungen"),
                titleOriginal: aw.title, subtitleOriginal: aw.prize,
                fields: [
                    CVFieldSpec(key: "title",   label: titleLabel,  original: aw.title),
                    CVFieldSpec(key: "prize",   label: prizeLabel,  original: aw.prize),
                    CVFieldSpec(key: "issuer",  label: issuerLabel, original: aw.issuer),
                    CVFieldSpec(key: "details", label: detailLabel, original: aw.details),
                ]))
        }

        return out
    }
}
