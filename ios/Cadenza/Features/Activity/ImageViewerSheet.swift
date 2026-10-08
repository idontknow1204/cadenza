import SwiftUI

// MARK: - Full-screen image viewer

/// Identifiable presentation value used by feed cards to open a specific
/// image while preserving the complete gallery for horizontal paging.
struct ImageViewerContext: Identifiable {
    let id = UUID()
    let urls: [String]
    let initialIndex: Int
}

struct ImageViewerSheet: View {
    let urls: [String]
    let initialIndex: Int

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var isZoomed = false

    init(urls: [String], initialIndex: Int = 0) {
        self.urls = urls
        self.initialIndex = max(0, min(initialIndex, urls.count - 1))
        self._currentIndex = State(initialValue: max(0, min(initialIndex, urls.count - 1)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, urlStr in
                    ZoomableImagePage(urlString: urlStr, isZoomed: $isZoomed)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .onChange(of: currentIndex) { isZoomed = false }

            // Top controls
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    .accessibilityLabel(Text("닫기"))

                    Spacer()

                    if let url = URL(string: urls[safe: currentIndex] ?? "") {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.black.opacity(0.5), in: Circle())
                        }
                        .accessibilityLabel(Text("공유"))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                if urls.count > 1 {
                    HStack(spacing: 5) {
                        ForEach(urls.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: i == currentIndex ? 16 : 6, height: 6)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: currentIndex)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .statusBarHidden(true)
        .interactiveDismissDisabled(isZoomed)
    }
}

// MARK: - Per-page zoomable image

private struct ZoomableImagePage: View {
    let urlString: String
    @Binding var isZoomed: Bool

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    private var zoomed: Bool { scale > 1.02 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                AsyncImage(url: URL(string: urlString)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        Image(systemName: "photo.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.white.opacity(0.4))
                    default:
                        ProgressView().tint(.white)
                    }
                }
                .scaleEffect(scale)
                .offset(x: panOffset.width, y: panOffset.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            // Pinch to zoom
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = max(1, lastScale * value)
                        isZoomed = scale > 1.02
                    }
                    .onEnded { _ in
                        if scale < 1.1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scale = 1; lastScale = 1
                                panOffset = .zero; lastPanOffset = .zero
                                isZoomed = false
                            }
                        } else {
                            lastScale = scale
                            isZoomed = true
                        }
                    }
            )
            // Double-tap to toggle zoom
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if zoomed {
                        scale = 1; lastScale = 1
                        panOffset = .zero; lastPanOffset = .zero
                        isZoomed = false
                    } else {
                        scale = 2.5; lastScale = 2.5
                        isZoomed = true
                    }
                }
            }
            // Pan gesture attached only when zoomed — when not zoomed, no DragGesture
            // is installed so the TabView's page controller handles horizontal swipes freely.
            .panWhenZoomed(zoomed) { drag in
                panOffset = CGSize(
                    width: lastPanOffset.width + drag.translation.width,
                    height: lastPanOffset.height + drag.translation.height
                )
            } onEnded: { _ in
                lastPanOffset = panOffset
            }
        }
    }
}

// MARK: - Conditional pan gesture modifier

private extension View {
    @ViewBuilder
    func panWhenZoomed(
        _ zoomed: Bool,
        onChanged: @escaping (DragGesture.Value) -> Void,
        onEnded: @escaping (DragGesture.Value) -> Void
    ) -> some View {
        if zoomed {
            self.gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged(onChanged)
                    .onEnded(onEnded)
            )
        } else {
            self
        }
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
