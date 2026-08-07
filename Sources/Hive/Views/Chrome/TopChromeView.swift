import SwiftUI
import HiveCore

// MARK: - TopChromeView (horizontal)
//
// The horizontal chrome container (SPEC §7.4 / §8.1 / §10.1): the tab strip on top, the
// omnibar directly beneath it, in a single glass panel flush to the window's top edge.
//
// It is a deliberately thin *container*: the tab-bar view and the omnibar view are passed in
// as `@ViewBuilder` content by `BrowserWindow`, which owns the `@Namespace` and applies the
// `matchedGeometryEffect` ids ("tabs" / "omnibar") BEFORE passing them in. That keeps all the
// H↔V morph wiring in one place (BrowserWindow) and this view purely structural — the glass
// frame, the 4pt-grid spacing, the bottom divider that separates chrome from content.
//
// Chrome glass: uses the proper NSVisualEffectView behind a warm tint wash, not the
// ad-hoc double-background. The result is a true translucent glass strip that lets the
// user's desktop wallpaper bleed through with Hive's signature warm amber hue.

struct TopChromeView<Tabs: View, SpaceBar: View, Bar: View>: View {

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder private var tabs: Tabs
    @ViewBuilder private var spaceBar: SpaceBar
    @ViewBuilder private var omnibar: Bar

    init(@ViewBuilder tabs: () -> Tabs,
         @ViewBuilder spaceBar: () -> SpaceBar = { EmptyView() },
         @ViewBuilder omnibar: () -> Bar) {
        self.tabs = tabs()
        self.spaceBar = spaceBar()
        self.omnibar = omnibar()
    }

    var body: some View {
        VStack(spacing: 0) {
            tabs
            spaceBar
            omnibar
            Divider().overlay(Color.hiveBorderSubtle)
        }
        .hiveSurface(.passiveChrome)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Browser chrome")
    }
}

// MARK: - CompactTopChromeView (vertical mode)
//
// The vertical-mode top chrome (SPEC §7.4 / §10.1): the omnibar ONLY — no tabs, because in
// vertical mode the tabs live in the left rail (`VerticalTabBarView`). Same glass frame as the
// horizontal chrome so the H↔V morph reads as the omnibar sliding up rather than a different
// chrome appearing.

struct CompactTopChromeView<Bar: View>: View {

    @ViewBuilder private var omnibar: Bar

    init(@ViewBuilder omnibar: () -> Bar) {
        self.omnibar = omnibar()
    }

    var body: some View {
        VStack(spacing: 0) {
            omnibar
            Divider().overlay(Color.hiveBorderSubtle)
        }
        .hiveSurface(.passiveChrome)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Browser chrome")
    }
}


