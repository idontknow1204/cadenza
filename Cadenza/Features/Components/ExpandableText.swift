import SwiftUI

/// Text that collapses only when it actually overflows at the rendered width.
/// This stays correct across languages, Dynamic Type sizes, and device widths;
/// callers do not need character-count heuristics.
struct ExpandableText: View {
    let text: String
    var collapsedLineLimit = 3
    var font: Font = .subheadline
    var textColor: Color = .primary.opacity(0.78)

    @State private var expanded = false
    @State private var fullHeight: CGFloat = 0
    @State private var collapsedHeight: CGFloat = 0

    private var isTruncated: Bool {
        collapsedHeight > 0 && fullHeight > collapsedHeight + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: text)
                .font(font)
                .foregroundStyle(textColor)
                .multilineTextAlignment(.leading)
                .lineLimit(expanded ? nil : collapsedLineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(measurementViews)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard isTruncated, !expanded else { return }
                    setExpanded(true)
                }

            if isTruncated {
                Button {
                    setExpanded(!expanded)
                } label: {
                    HStack(spacing: 3) {
                        Text(verbatim: expanded
                             ? localized("접기", "Collapse", "Einklappen")
                             : localized("더보기", "More", "Mehr"))
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityValue(Text(verbatim: expanded
                    ? localized("펼쳐짐", "Expanded", "Ausgeklappt")
                    : localized("접힘", "Collapsed", "Eingeklappt")))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: text) { _, _ in expanded = false }
    }

    private var measurementViews: some View {
        ZStack(alignment: .topLeading) {
            measurementText(lineLimit: nil)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ExpandableFullTextHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
            measurementText(lineLimit: collapsedLineLimit)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ExpandableCollapsedTextHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
        }
        .hidden()
        .onPreferenceChange(ExpandableFullTextHeightKey.self) { fullHeight = $0 }
        .onPreferenceChange(ExpandableCollapsedTextHeightKey.self) { collapsedHeight = $0 }
    }

    private func measurementText(lineLimit: Int?) -> some View {
        Text(verbatim: text)
            .font(font)
            .multilineTextAlignment(.leading)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func setExpanded(_ value: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            expanded = value
        }
    }
}

private struct ExpandableFullTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ExpandableCollapsedTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
