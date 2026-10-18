import SwiftUI

struct CVPhotoCropView: View {
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    private static let cropRatio: CGFloat = 3.0 / 4.0
    private static let outputSize = CGSize(width: 600, height: 800)

    private let img: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var liveScale: CGFloat = 1.0
    @GestureState private var liveDrag: CGSize = .zero

    init(image: UIImage, onConfirm: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        if image.imageOrientation == .up {
            self.img = image
        } else {
            self.img = UIGraphicsImageRenderer(size: image.size).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            // 화면 폭의 82%, 상한 320pt — iPhone/iPad 모두 대응
            let frameW = min(geo.size.width * 0.82, 320)
            let frameH = frameW / Self.cropRatio
            let bs     = baseScale(frameW: frameW, frameH: frameH)
            let totalS = bs * scale * liveScale
            let totalOffset = CGSize(
                width:  offset.width  + liveDrag.width,
                height: offset.height + liveDrag.height
            )

            // 시각 레이어만 ZStack에 — 이미지 frame이 커도 ZStack은 geo.size로 고정
            ZStack {
                Color.black

                Image(uiImage: img)
                    .resizable()
                    .frame(width:  img.size.width  * totalS,
                           height: img.size.height * totalS)
                    .offset(totalOffset)
                    .gesture(
                        DragGesture()
                            .updating($liveDrag) { v, s, _ in s = v.translation }
                            .onEnded { v in
                                let raw = CGSize(
                                    width:  offset.width  + v.translation.width,
                                    height: offset.height + v.translation.height
                                )
                                offset = clamped(raw, userScale: scale,
                                                 frameW: frameW, frameH: frameH)
                            }
                            .simultaneously(with:
                                MagnificationGesture()
                                    .updating($liveScale) { v, s, _ in s = v }
                                    .onEnded { v in
                                        let ns = max(1.0, min(5.0, scale * v))
                                        scale = ns
                                        offset = clamped(offset, userScale: ns,
                                                         frameW: frameW, frameH: frameH)
                                    }
                            )
                    )

                // 어두운 오버레이: Color가 ZStack 전체를 채우므로 Rectangle 중앙 정렬이 보장됨
                Color.black.opacity(0.6)
                    .overlay(
                        Rectangle()
                            .frame(width: frameW, height: frameH)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
                    .allowsHitTesting(false)

                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.85), lineWidth: 1)
                    .frame(width: frameW, height: frameH)
                    .allowsHitTesting(false)
            }
            // ZStack을 geo.size로 고정 — 이미지 frame 팽창 차단
            .frame(width: geo.size.width, height: geo.size.height)
            // 힌트: safe area 아래, ZStack 상단에 고정
            .overlay(alignment: .top) {
                Text("드래그·핀치로 위치와 크기 조정")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, geo.safeAreaInsets.top + 16)
                    .allowsHitTesting(false)
            }
            // 버튼: safe area 위, ZStack 하단에 고정
            .overlay(alignment: .bottom) {
                HStack {
                    Button(action: onCancel) {
                        Text("취소")
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                    }
                    Spacer()
                    Button {
                        onConfirm(crop(userScale: scale, userOffset: offset,
                                       frameW: frameW, frameH: frameH))
                    } label: {
                        Text("확인")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.black)
                            .frame(minWidth: 100)
                            .padding(.vertical, 14)
                            .background(.white, in: Capsule())
                    }
                    .padding(.trailing, 24)
                }
                .padding(.bottom, geo.safeAreaInsets.bottom + 16)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 좌표 계산

    private func baseScale(frameW: CGFloat, frameH: CGFloat) -> CGFloat {
        max(frameW / img.size.width, frameH / img.size.height)
    }

    private func clamped(_ off: CGSize, userScale: CGFloat,
                         frameW: CGFloat, frameH: CGFloat) -> CGSize {
        let bs    = baseScale(frameW: frameW, frameH: frameH)
        let dispW = img.size.width  * bs * userScale
        let dispH = img.size.height * bs * userScale
        let mx = max(0, (dispW - frameW) / 2)
        let my = max(0, (dispH - frameH) / 2)
        return CGSize(
            width:  min(mx,  max(-mx,  off.width)),
            height: min(my,  max(-my,  off.height))
        )
    }

    private func crop(userScale: CGFloat, userOffset: CGSize,
                      frameW: CGFloat, frameH: CGFloat) -> UIImage {
        let bs    = baseScale(frameW: frameW, frameH: frameH)
        let ts    = bs * userScale
        let dispW = img.size.width  * ts
        let dispH = img.size.height * ts
        let imgX  = (frameW - dispW) / 2 + userOffset.width
        let imgY  = (frameH - dispH) / 2 + userOffset.height
        let pixX  = -imgX / ts
        let pixY  = -imgY / ts
        let pixW  = frameW / ts
        let pixH  = frameH / ts
        let cropRect = CGRect(x: pixX, y: pixY, width: pixW, height: pixH)
            .intersection(CGRect(origin: .zero, size: img.size))

        let out = Self.outputSize
        let sx  = out.width  / pixW
        let sy  = out.height / pixH
        return UIGraphicsImageRenderer(size: out).image { _ in
            img.draw(in: CGRect(
                x:      -cropRect.origin.x * sx,
                y:      -cropRect.origin.y * sy,
                width:   img.size.width  * sx,
                height:  img.size.height * sy
            ))
        }
    }
}
