import SwiftUI

struct CountryFlagView: View {
    let flag: String
    var width: CGFloat = 26
    var height: CGFloat = 18

    private var cornerRadius: CGFloat { min(width, height) * 0.18 }

    var body: some View {
        ZStack {
            switch flag {
            case "🇰🇷":
                korea
            case "🇩🇪":
                horizontalStripes([.black, .red, .yellow])
            case "🇦🇹":
                horizontalStripes([.red, .white, .red])
            case "🇨🇭":
                swiss
            case "🇫🇷":
                verticalStripes([.blue, .white, .red])
            case "🇬🇧":
                unitedKingdom
            case "🇳🇱":
                horizontalStripes([.red, .white, .blue])
            case "🇮🇹":
                verticalStripes([.green, .white, .red])
            case "🇺🇸":
                unitedStates
            default:
                Text(flag).font(.caption)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 0.7)
        }
        .accessibilityLabel(Text(flag))
    }

    private func horizontalStripes(_ colors: [Color]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
    }

    private func verticalStripes(_ colors: [Color]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                color
            }
        }
    }

    private var korea: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let markW = w * 0.16
            let markH = h * 0.08

            ZStack {
                Color.white
                ZStack {
                    VStack(spacing: 0) {
                        Color.red
                        Color.blue
                    }
                    Circle()
                        .fill(.red)
                        .frame(width: w * 0.22, height: w * 0.22)
                        .offset(x: -w * 0.055)
                    Circle()
                        .fill(.blue)
                        .frame(width: w * 0.22, height: w * 0.22)
                        .offset(x: w * 0.055)
                }
                .frame(width: h * 0.52, height: h * 0.52)
                .clipShape(Circle())

                Group {
                    koreanBars(x: w * 0.22, y: h * 0.24, barWidth: markW, barHeight: markH)
                        .rotationEffect(.degrees(-32))
                    koreanBars(x: w * 0.78, y: h * 0.24, barWidth: markW, barHeight: markH)
                        .rotationEffect(.degrees(32))
                    koreanBars(x: w * 0.22, y: h * 0.76, barWidth: markW, barHeight: markH)
                        .rotationEffect(.degrees(32))
                    koreanBars(x: w * 0.78, y: h * 0.76, barWidth: markW, barHeight: markH)
                        .rotationEffect(.degrees(-32))
                }
            }
        }
    }

    private func koreanBars(x: CGFloat, y: CGFloat, barWidth: CGFloat, barHeight: CGFloat) -> some View {
        VStack(spacing: barHeight * 0.55) {
            Color.black.frame(width: barWidth, height: barHeight)
            Color.black.frame(width: barWidth, height: barHeight)
            Color.black.frame(width: barWidth, height: barHeight)
        }
        .position(x: x, y: y)
    }

    private var swiss: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let bar = size * 0.22
            ZStack {
                Color.red
                Color.white.frame(width: size * 0.62, height: bar)
                Color.white.frame(width: bar, height: size * 0.62)
            }
        }
    }

    private var unitedKingdom: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Color.blue
                diagonalStripe(width: w * 0.2, color: .white, angle: 32)
                diagonalStripe(width: w * 0.2, color: .white, angle: -32)
                diagonalStripe(width: w * 0.09, color: .red, angle: 32)
                diagonalStripe(width: w * 0.09, color: .red, angle: -32)
                Color.white.frame(width: w, height: h * 0.28)
                Color.white.frame(width: w * 0.28, height: h)
                Color.red.frame(width: w, height: h * 0.15)
                Color.red.frame(width: w * 0.15, height: h)
            }
        }
    }

    private func diagonalStripe(width: CGFloat, color: Color, angle: CGFloat) -> some View {
        color
            .frame(width: width, height: 80)
            .rotationEffect(.degrees(angle))
    }

    private var unitedStates: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let stripeHeight = h / 13
            let cantonW = w * 0.44
            let cantonH = stripeHeight * 7

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<13, id: \.self) { index in
                        (index.isMultiple(of: 2) ? Color.red : Color.white)
                    }
                }
                Color.blue.frame(width: cantonW, height: cantonH)
                starField(width: cantonW, height: cantonH)
            }
        }
    }

    private func starField(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: height * 0.08) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: width * 0.12) {
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(.white)
                            .frame(width: width * 0.05, height: width * 0.05)
                    }
                }
            }
        }
        .frame(width: width, height: height)
    }
}
