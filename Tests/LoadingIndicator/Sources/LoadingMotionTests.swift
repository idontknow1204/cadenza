import XCTest
import SwiftUI
@testable import CadenzaLoadingPreview

final class LoadingMotionTests: XCTestCase {
    func testFullTurnsAndContinuousBoundary() {
        let duration = CadenzaLoadingMotion.duration
        XCTAssertEqual(CadenzaLoadingMotion.degrees(at: 0), 0)
        XCTAssertEqual(CadenzaLoadingMotion.degrees(at: duration), 360, accuracy: 0.00001)
        XCTAssertEqual(CadenzaLoadingMotion.degrees(at: duration * 10), 3600, accuracy: 0.00001)
        XCTAssertEqual(speed(at: duration - 0.001), speed(at: duration + 0.001), accuracy: 0.01)
    }

    func testAlwaysForwardWithRepeatedAccelerationAndDeceleration() {
        let duration = CadenzaLoadingMotion.duration
        for step in 0..<1000 {
            XCTAssertGreaterThan(speed(at: Double(step) * duration / 100), 0)
        }
        for cycle in 0..<3 {
            let start = Double(cycle) * duration
            let slow = speed(at: start + 0.01)
            let medium = speed(at: start + duration / 4)
            let fast = speed(at: start + duration / 2)
            XCTAssertLessThan(slow, medium)
            XCTAssertLessThan(medium, fast)
            XCTAssertEqual(medium, speed(at: start + duration * 3 / 4), accuracy: 0.1)
            XCTAssertEqual(slow, speed(at: start + duration - 0.01), accuracy: 0.1)
        }
    }

    private func speed(at time: TimeInterval) -> Double {
        (CadenzaLoadingMotion.degrees(at: time + 0.00001) - CadenzaLoadingMotion.degrees(at: time)) / 0.00001
    }

    @MainActor
    func testNativeRefreshDecorationAndCleanup() async throws {
        let root = NavigationStack {
            ScrollView {
                VStack { ForEach(0..<30) { Text("Row \($0)").padding() } }
                    .frame(maxWidth: .infinity)
            }.cadenzaRefreshable {}
        }
        let host = UIHostingController(rootView: AnyView(root))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(500))
        let scroll = try XCTUnwrap(findScroll(in: host.view))
        let refresh = try XCTUnwrap(scroll.refreshControl)
        XCTAssertEqual(refresh.tintColor, .clear)
        let logo = try XCTUnwrap(refresh.subviews.last)
        XCTAssertTrue(logo.isHidden)
        refresh.beginRefreshing()
        scroll.contentOffset.y = -scroll.adjustedContentInset.top - 80
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(logo.isHidden)
        refresh.endRefreshing()
        scroll.contentOffset.y = -scroll.adjustedContentInset.top
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertTrue(logo.isHidden)
        host.rootView = AnyView(Color.white)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(logo.superview)
        XCTAssertNotEqual(refresh.tintColor, .clear)
    }

    @MainActor
    func testActiveLogoChangesFrames() async throws {
        let host = UIHostingController(rootView: CadenzaLoadingView(size: 60)
            .environment(\.scenePhase, .active))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        let first = snapshot(host.view)
        try await Task.sleep(for: .milliseconds(400))
        let second = snapshot(host.view)
        XCTAssertNotEqual(first.pngData(), second.pngData())
        for (index, image) in [first, second].enumerated() {
            let attachment = XCTAttachment(image: image)
            attachment.name = "Animated logo frame \(index)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    @MainActor
    func testPausedLogoStaysStill() async throws {
        let host = UIHostingController(rootView: CadenzaLoadingView(size: 60, isAnimating: false))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        let first = snapshot(host.view)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(first.pngData(), snapshot(host.view).pngData())
    }

    @MainActor
    private func findScroll(in view: UIView) -> UIScrollView? {
        if let scroll = view as? UIScrollView, scroll.refreshControl != nil { return scroll }
        return view.subviews.lazy.compactMap { self.findScroll(in: $0) }.first
    }

    @MainActor
    private func snapshot(_ view: UIView) -> UIImage {
        UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}
