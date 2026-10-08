import SwiftUI

/// Single source for all user avatar rendering across the app.
/// Shows AsyncImage when an URL is available; falls back to a two-letter
/// initial circle so there is always something visible.
struct UserAvatarView: View {
    let url: String?
    let name: String
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let urlStr = url, let u = URL(string: urlStr) {
                AsyncImage(url: u) { phase in
                    if case .success(let img) = phase {
                        img.resizable().scaledToFill()
                    } else {
                        initialsCircle
                    }
                }
            } else {
                initialsCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return "\(words[0].prefix(1))\(words[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var initialsCircle: some View {
        ZStack {
            Circle().fill(Color.accentColor.opacity(0.13))
            Text(initials)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color.accentColor)
        }
    }
}

/// Single source of truth for adaptive (iPhone ↔ iPad) layout decisions.
///
/// The app currently ships **iPhone-only** (`TARGETED_DEVICE_FAMILY = "1"` in
/// `project.yml`). On both iPhone *and* iPad (iPhone-compatibility mode) the
/// horizontal size class is therefore always `.compact`, which means every
/// helper in this file is a deliberate **no-op today** — wiring it into screens
/// now produces zero visual change, but prepares them for native iPad.
///
/// ## Upgrading to a native iPad app (future)
/// 1. `project.yml` → `TARGETED_DEVICE_FAMILY: "1,2"`
/// 2. `project.yml` → add landscape orientations to `UISupportedInterfaceOrientations`
///    (App Store review requires iPad apps to support multiple orientations).
/// 3. `xcodegen generate`
///
/// Because the primary content columns already carry `.adaptiveContentWidth()`,
/// they immediately reflow into a centered, readable column on `.regular`-width
/// screens the moment the device family flips — no per-screen rework required.
enum CadenzaLayout {
    /// Max width for a primary content column on regular-width (iPad) layouts.
    /// Keeps long-form content readable instead of stretching edge-to-edge.
    static let maxContentWidth: CGFloat = 640
}

private struct AdaptiveContentWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            // Constrain to a readable column, then re-expand so the column is
            // centered within the full width (background stays edge-to-edge).
            content
                .frame(maxWidth: maxWidth)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// Centers content within a readable column on regular-width (iPad) layouts.
    ///
    /// No-op on compact width — i.e. every iPhone, and iPad while the app runs
    /// in iPhone-compatibility mode. Safe to apply now; activates automatically
    /// when the app becomes a native iPad target. Apply to the content *inside*
    /// a `ScrollView` (not the `ScrollView` itself) so the background remains
    /// full-bleed while the content column is centered.
    func adaptiveContentWidth(_ maxWidth: CGFloat = CadenzaLayout.maxContentWidth) -> some View {
        modifier(AdaptiveContentWidth(maxWidth: maxWidth))
    }
}
