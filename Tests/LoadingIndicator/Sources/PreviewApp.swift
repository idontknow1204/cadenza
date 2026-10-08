import SwiftUI

@main
struct LoadingPreviewApp: App {
    var body: some Scene {
        WindowGroup {
            LoadingPreview()
                .progressViewStyle(CadenzaProgressViewStyle())
        }
    }
}

private struct LoadingPreview: View {
    @State private var refreshCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HStack(spacing: 40) {
                        ProgressView().accessibilityIdentifier("preview.light")
                        ProgressView()
                            .padding(20)
                            .background(.black)
                            .environment(\.colorScheme, .dark)
                        ProgressView().foregroundStyle(.white)
                            .padding(20)
                            .background(Color("AccentColor"))
                    }
                    Text("Refreshes: \(refreshCount)")
                        .accessibilityIdentifier("preview.refreshCount")
                    ProgressView(value: 0.5).accessibilityIdentifier("preview.determinate")
                    ForEach(0..<30) { index in
                        Text("Row \(index)").frame(maxWidth: .infinity).padding()
                    }
                }
                .padding()
            }
            .cadenzaRefreshable {
                try? await Task.sleep(for: .seconds(3))
                refreshCount += 1
            }
            .navigationTitle("Loading Preview")
        }
    }
}
