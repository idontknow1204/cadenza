import SwiftUI
import PhotosUI

struct Step5ProfileView: View {
    @Bindable var coordinator: OnboardingCoordinator
    @Environment(SessionStore.self) private var session

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    photoSection
                    bioSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            Spacer(minLength: 0)
            OnboardingBottomBar(
                primaryLabel: "onboarding.next",
                primaryAction: {
                    Task { await coordinator.saveStep5(repo: session.repo, userID: session.currentUserID!) }
                },
                primaryDisabled: false,
                skipLabel: "onboarding.skip",
                skipAction: { coordinator.advance() },
                isBusy: coordinator.isBusy
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("onboarding.step5.title").font(.largeTitle.bold())
            Text("onboarding.step5.desc").foregroundStyle(.secondary)
        }
    }

    private var photoSection: some View {
        VStack(alignment: .center, spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    if let img = coordinator.avatarImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.accentColor, lineWidth: coordinator.avatarImage == nil ? 0 : 2))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .background(Circle().fill(.background))
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .onChange(of: pickerItem) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(type: Data.self),
                          let uiImage = UIImage(data: data) else { return }
                    coordinator.avatarImage = uiImage
                }
            }
        }
    }

    private var bioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("onboarding.bio").font(.headline)
                Spacer()
                Text("\(coordinator.bio.count)/300")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: $coordinator.bio)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: coordinator.bio) { _, v in
                    if v.count > 300 { coordinator.bio = String(v.prefix(300)) }
                }
            Text("onboarding.bio.hint")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
