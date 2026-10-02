import Foundation
import UIKit

/// Drives the onboarding flow (steps 2–8). Step 1 = AuthView (already done).
/// Each save is persisted immediately so the user can resume if they quit.
@MainActor
@Observable
final class OnboardingCoordinator {

    // Current visible step (2…8)
    var step: Int = 2
    let totalSteps = 8

    // Accumulated draft values
    var major: String = ""
    var instrument: String = ""

    var institutionName: String = ""
    var courseType: String = ""
    var enrollmentYear: Int = Calendar.current.component(.year, from: Date())
    var homeCities: Set<String> = []

    var teacherName: String = ""
    var teacherID: UUID? = nil

    var bio: String = ""
    var avatarImage: UIImage? = nil

    var defaultVisibility: Visibility = .industryFollowers

    // Error propagation
    var errorText: String?
    var isBusy = false

    var canSkip: Bool { step >= 4 && step <= 7 }
    var isLastStep: Bool { step == totalSteps }

    func advance() {
        if step < totalSteps { step += 1 }
    }

    func back() {
        if step > 2 { step -= 1 }
    }

    // MARK: - Step savers

    func saveStep2(repo: Repository, userID: UUID) async {
        guard !major.isEmpty, !instrument.isEmpty else { return }
        isBusy = true; defer { isBusy = false }
        do {
            try await repo.saveInstrument(id: userID, major: major, instrument: instrument)
            advance()
        } catch { errorText = error.localizedDescription }
    }

    func saveStep3(repo: Repository, userID: UUID) async {
        guard !institutionName.isEmpty else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let ct = courseType.isEmpty ? nil : courseType
            try await repo.upsertAffiliation(
                userId: userID,
                institutionName: institutionName,
                courseType: ct,
                enrollmentYear: enrollmentYear
            )
            try await repo.saveHomeCities(id: userID, cities: Array(homeCities))
            advance()
        } catch { errorText = error.localizedDescription }
    }

    func saveStep4(repo: Repository, userID: UUID) async {
        isBusy = true; defer { isBusy = false }
        do {
            if !teacherName.isEmpty {
                try await repo.saveTeacher(studentId: userID,
                                           teacherId: teacherID,
                                           teacherName: teacherName)
            }
            advance()
        } catch { errorText = error.localizedDescription }
    }

    func saveStep5(repo: Repository, userID: UUID) async {
        isBusy = true; defer { isBusy = false }
        do {
            if !bio.isEmpty { try await repo.saveBio(id: userID, bio: bio) }
            if let img = avatarImage { _ = try await repo.uploadAvatar(userId: userID, image: img) }
            advance()
        } catch { errorText = error.localizedDescription }
    }

    func skipToStep(repo: Repository, userID: UUID, target: Int) async {
        isBusy = true; defer { isBusy = false }
        step = target
    }

    func completeOnboarding(repo: Repository, userID: UUID, session: SessionStore) async {
        isBusy = true; defer { isBusy = false }
        do {
            try await repo.completeOnboarding(id: userID, visibility: defaultVisibility)
            await session.refreshProfile()
        } catch { errorText = error.localizedDescription }
    }
}
