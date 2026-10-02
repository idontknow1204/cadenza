import SwiftUI

struct BioEditSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var bio = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $bio)
                        .frame(minHeight: 120)
                        .onChange(of: bio) { _, v in
                            if v.count > 300 { bio = String(v.prefix(300)) }
                        }
                } header: {
                    Text("onboarding.bio")
                } footer: {
                    Text("\(bio.count)/300").frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .navigationTitle("profile.bio.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if busy { ProgressView() } else {
                        Button("profile.edit.save") { Task { await save() } }
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear { bio = session.profile?.bio ?? "" }
        }
    }

    private func save() async {
        guard let me = session.currentUserID else { return }
        busy = true
        try? await session.repo.saveBio(id: me, bio: bio)
        await session.refreshProfile()
        dismiss()
    }
}
