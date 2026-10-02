import SwiftUI

struct LanguagePickerView: View {
    @AppStorage("appLanguage") private var appLanguage: String = ""
    @AppStorage("languageChosen") private var languageChosen: Bool = false
    @State private var showLanguageSelection: Bool

    init() {
        // 뒤로 돌아온 경우 스플래시 생략하고 언어 선택 바로 표시
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? ""
        _showLanguageSelection = State(initialValue: !lang.isEmpty)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if showLanguageSelection {
                languagePage
                    .transition(.move(edge: .trailing))
            } else {
                splashPage
                    .transition(.move(edge: .leading))
            }
        }
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.35), value: showLanguageSelection)
    }

    // MARK: - 스플래시 (로고)

    private var splashPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Image("CadenzaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .padding(.bottom, -24)

                Text("Cadenza")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.black)
            }

            Spacer()
        }
        .task {
            try? await Task.sleep(for: .seconds(3.5))
            showLanguageSelection = true
        }
    }

    // MARK: - 언어 선택

    private struct LangOption: Identifiable {
        let id: String
        let code: String
        let native: String
    }

    private let options: [LangOption] = [
        LangOption(id: "ko", code: "KO", native: "한국어"),
        LangOption(id: "en", code: "EN", native: "English"),
        LangOption(id: "de", code: "DE", native: "Deutsch"),
    ]

    private var languagePage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Image("CadenzaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .opacity(0.5)

                Text("언어를 선택하세요\nSelect your language\nSprache wählen")
                    .font(.subheadline)
                    .foregroundStyle(Color(.systemGray))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 36)

            VStack(spacing: 12) {
                ForEach(options) { lang in
                    Button {
                        LanguageBundle.setLanguage(lang.id)
                        appLanguage = lang.id
                        languageChosen = true
                    } label: {
                        HStack(spacing: 14) {
                            Text(lang.code)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                                .frame(width: 36, height: 36)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))

                            Text(lang.native)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.black)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer()
            Spacer()
        }
    }
}
