import SwiftUI
import UIKit

enum CadenzaLoadingMotion {
    static let duration: TimeInterval = 1.35

    static func degrees(at elapsed: TimeInterval) -> Double {
        let turns = max(0, elapsed) / duration
        // Nonzero speed at the cycle boundary keeps consecutive turns continuous.
        return 360 * (turns - 0.75 * sin(2 * .pi * turns) / (2 * .pi))
    }
}

struct CadenzaLoadingView: View {
    var size: CGFloat = 24
    var isAnimating = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: !isAnimating || reduceMotion || scenePhase != .active)) { context in
            Rectangle()
                .fill(Color(uiColor: .systemGray))
                .mask {
                    // The existing logo has a white background; use its ink as the mask.
                    Image("CadenzaLogo")
                        .resizable()
                        .scaledToFit()
                        .colorInvert()
                        .luminanceToAlpha()
                }
                .frame(width: size, height: size)
                .rotationEffect(.degrees(reduceMotion || !isAnimating ? 0 : CadenzaLoadingMotion.degrees(at: context.date.timeIntervalSince(start))))
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(localized("불러오는 중", "Loading", "Wird geladen"))
        .accessibilityIdentifier("cadenza.loading")
    }
}

struct CadenzaProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        if let fraction = configuration.fractionCompleted {
            ProgressView(value: fraction) {
                configuration.label
            } currentValueLabel: {
                configuration.currentValueLabel
            }
            .progressViewStyle(.linear)
        } else {
            VStack(spacing: 8) {
                CadenzaLoadingView()
                configuration.label
                configuration.currentValueLabel
            }
        }
    }
}

extension View {
    func cadenzaRefreshable(action: @escaping @Sendable () async -> Void) -> some View {
        refreshable(action: action)
            .background(RefreshLogoBridge().allowsHitTesting(false))
    }
}

// Preserve SwiftUI's refresh action, gestures and cancellation ownership. Only
// decorate the public UIRefreshControl, leaving its targets and insets untouched.
private struct RefreshLogoBridge: UIViewRepresentable {
    @Environment(\.scenePhase) private var scenePhase
    func makeUIView(context: Context) -> RefreshLogoProbe { RefreshLogoProbe() }
    func updateUIView(_ view: RefreshLogoProbe, context: Context) {
        view.setScenePhase(scenePhase)
        view.scheduleAttachment()
    }
    static func dismantleUIView(_ view: RefreshLogoProbe, coordinator: ()) { view.detach() }
}

private struct RefreshLoadingLogo: View {
    let isAnimating: Bool
    let scenePhase: ScenePhase

    var body: some View {
        CadenzaLoadingView(size: 28, isAnimating: isAnimating)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.scenePhase, scenePhase)
    }
}

private final class RefreshLogoProbe: UIView {
    private weak var control: UIRefreshControl?
    private var originalTint: UIColor?
    private var offsetObservation: NSKeyValueObservation?
    private var refreshingObservation: NSKeyValueObservation?
    private var logo: UIView?
    private var showingLogo = false
    private var attachmentScheduled = false
    private var scenePhase: ScenePhase = .active

    func setScenePhase(_ phase: ScenePhase) {
        guard scenePhase != phase else { return }
        scenePhase = phase
        updateLogo()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { detach() } else { scheduleAttachment() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scheduleAttachment()
    }

    func scheduleAttachment() {
        guard window != nil, !attachmentScheduled else { return }
        attachmentScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.attachmentScheduled = false
            self.attachIfNeeded()
        }
    }

    private func attachIfNeeded() {
        guard window != nil else { return }
        if let control, control.window != nil { return }
        var ancestor = superview
        while let view = ancestor {
            if let scroll = refreshScroll(in: view), let refresh = scroll.refreshControl {
                if control !== refresh {
                    detach()
                    control = refresh
                    originalTint = refresh.tintColor
                    let hosted = logoConfiguration.makeContentView()
                    hosted.backgroundColor = .clear
                    hosted.isUserInteractionEnabled = false
                    hosted.frame = refresh.bounds
                    hosted.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    hosted.isHidden = true
                    refresh.addSubview(hosted)
                    logo = hosted
                    refresh.tintColor = .clear
                    offsetObservation = scroll.observe(\.contentOffset, options: [.new]) { [weak self, weak scroll] _, _ in
                        guard let scroll else { return }
                        self?.updateVisibility(in: scroll)
                    }
                    refreshingObservation = refresh.observe(\.isRefreshing, options: [.new]) { [weak self, weak scroll] _, _ in
                        guard let scroll else { return }
                        self?.updateVisibility(in: scroll)
                    }
                }
                updateVisibility(in: scroll)
                return
            }
            // Never search beyond this screen's hosting controller into other tabs.
            if view.next is UIViewController { break }
            ancestor = view.superview
        }
    }

    private func refreshScroll(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.refreshControl != nil { return scroll }
        for child in view.subviews where child !== self {
            if let scroll = refreshScroll(in: child) { return scroll }
        }
        return nil
    }

    private func updateVisibility(in scroll: UIScrollView) {
        guard let control, let logo else { return }
        let pulledDown = scroll.contentOffset.y < -scroll.adjustedContentInset.top - 4
        let visible = control.isRefreshing || pulledDown
        guard visible != showingLogo else { return }
        showingLogo = visible
        logo.isHidden = !visible
        updateLogo()
    }

    private func updateLogo() {
        if let content = logo as? (UIView & UIContentView) {
            content.configuration = logoConfiguration
        }
    }

    private var logoConfiguration: UIHostingConfiguration<RefreshLoadingLogo, EmptyView> {
        UIHostingConfiguration {
            RefreshLoadingLogo(isAnimating: showingLogo, scenePhase: scenePhase)
        }.margins(.all, 0)
    }

    func detach() {
        offsetObservation = nil
        refreshingObservation = nil
        if let control { control.tintColor = originalTint }
        logo?.removeFromSuperview()
        logo = nil
        control = nil
        showingLogo = false
    }
}
