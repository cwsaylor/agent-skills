# Fix patterns

For each pattern: why it breaks on iPhone Duo, how to find it, the replacement in
UIKit and SwiftUI, and the gotchas that turn a correct-looking fix into a bug.
Apply the rules from SKILL.md (dynamic values only, preserve control flow, no
drive-by edits).

## 1. Sizing from the main screen

**Why it breaks.** On iPhone Duo the app's window changes size whenever the
device folds or unfolds, and it does not always match the screen. There are two
screens. `UIScreen.main` is also wrong in Split View, Stage Manager, and iPhone
Mirroring.

**Find.** `UIScreen.main`, `[UIScreen mainScreen]`, `UIScreen.screens`.

### 1a. Bounds

```swift
// Before
let width = UIScreen.main.bounds.width

// After, in a view controller
let width = view.bounds.width

// After, in a view
let width = bounds.width            // or superview?.bounds.width

// After, anything with a window
let width = window.bounds.width

// After, scene-level
let size = windowScene.effectiveGeometry.coordinateSpace.bounds.size
```

SwiftUI:

```swift
// Read once per layout pass
GeometryReader { proxy in
    Content(width: proxy.size.width)
}

// React to size changes without a GeometryReader wrapping the layout
Content()
    .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
        columns = newSize.width > newSize.height ? 2 : 1
    }
```

Gotcha: in a cell or a subview `view.bounds` can be zero in `init`. Do the
math where the size is final (see 1b).

### 1b. Reading the size once

**Why it breaks.** A fold resizes the app mid-session. A value captured in
`viewDidLoad`, `viewIsAppearing`, or `init` goes stale.

```swift
// UIKit: size-dependent layout
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    columns = view.bounds.width > view.bounds.height ? 2 : 1
}

// UIKit: work that must run once per size change (animations, re-fetch)
override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate { _ in self.updateLayout(for: size) }
}

// UIKit view
override func layoutSubviews() {
    super.layoutSubviews()
    // compute from bounds here
}
```

For traits (size class, display scale) use automatic trait tracking, which
re-runs `layoutSubviews`, `updateConstraints`, `draw(_:)`, `viewIsAppearing`,
and `updateConfiguration` when a trait they read changes. Outside those methods,
register:

```swift
registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitDisplayScale.self]) {
    (self: Self, _) in self.updateLayout()
}
```

Do not use `traitCollectionDidChange(_:)` in new code; it is deprecated.

### 1c. Scale

```swift
// Before
let scale = UIScreen.main.scale

// After, UIKit (view, view controller, or anything with a trait collection)
let scale = traitCollection.displayScale

// After, SwiftUI
@Environment(\.displayScale) private var displayScale
```

Gotchas:

- `displayScale` can change (the app moves between displays). If the value is
  cached, for example in a `CALayer.contentsScale`, a rendered image, or a
  constraint constant, the cache must be invalidated on trait change (1b).
- `UIScreen.main.nativeScale` has no trait-collection equivalent. Read
  `view.window?.windowScene?.screen.nativeScale` at the point of use.
- `UIGraphicsImageRendererFormat(for: UIScreen.main.traitCollection)` becomes
  `UIGraphicsImageRendererFormat(for: traitCollection)`.
- Non-view helpers (image caches, free functions) should take the scale as a
  parameter from the caller, not reach for a global.

### 1d. Windows

```swift
// Before
window = UIWindow(frame: UIScreen.main.bounds)

// After, in UIWindowSceneDelegate
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene else { return }
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = RootViewController()
    self.window = window
    window.makeKeyAndVisible()
}
```

If the app has no scene delegate, migrate the lifecycle first (Apple's
app-resizability skill, `scene-lifecycle-task.md`, has the full procedure).

### 1e. Stored screens

```swift
// Before
let screen = UIScreen.main        // stored property

// After: no stored property; read at the point of use
if let screen = view.window?.windowScene?.screen { ... }
```

### 1f. Keyboard notifications

`UIResponder.keyboardFrameEndUserInfoKey` is in screen coordinates. Convert
with `view.convert(frame, from: nil)` or, better, use `view.keyboardLayoutGuide`
and drop the notification code.

## 2. Orientation used for layout

**Why it breaks.** On iPhone Duo the device orientation says nothing about the
window's shape. The inner display does not honor
`supportedInterfaceOrientations`. In Split View the window can be portrait-shaped
on a landscape device.

**Find.** `UIDevice.current.orientation`, `statusBarOrientation`,
`interfaceOrientation`, `windowScene.effectiveGeometry.interfaceOrientation`,
`UIDevice.orientationDidChangeNotification`, `isLandscape` / `isPortrait`,
`windowScene(_:didUpdateCoordinateSpace:...)`.

Classify each use first:

| The code is asking | Replace with |
|---|---|
| "Is there room for a side-by-side layout?" | `traitCollection.horizontalSizeClass == .regular` |
| "Is the window wider than tall?" (aspect) | `view.bounds.width > view.bounds.height` |
| "Which way should subviews flow?" | Size class, or bounds comparison |
| Camera / sensor / video rotation (physical orientation) | Keep `UIDevice.current.orientation`; it is not a layout question |
| Locking rotation (`supportedInterfaceOrientations`) | Keep it; it is not a layout question |

```swift
// Before
if UIDevice.current.orientation.isLandscape { showSidebar() } else { hideSidebar() }

// After (constrained space)
if traitCollection.horizontalSizeClass == .regular { showSidebar() } else { hideSidebar() }

// After (pure aspect ratio)
if view.bounds.width > view.bounds.height { ... }
```

SwiftUI:

```swift
@Environment(\.horizontalSizeClass) private var horizontalSizeClass
@Environment(\.verticalSizeClass) private var verticalSizeClass

var body: some View {
    GeometryReader { proxy in
        let isWide = proxy.size.width > proxy.size.height
        ...
    }
}
```

Scene callback:

```swift
// Before (deprecated)
func windowScene(_ windowScene: UIWindowScene, didUpdateCoordinateSpace previousCoordinateSpace: UICoordinateSpace,
                 interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
                 traitCollection previousTraitCollection: UITraitCollection)

// After (iOS 26+)
func windowScene(_ windowScene: UIWindowScene, didUpdateEffectiveGeometry previousEffectiveGeometry: UIWindowScene.Geometry)
```

Gotcha: `orientation.isLandscape` also covers left-versus-right. If the code
cares which side (for example, mirroring a control next to the camera), a
width-versus-height comparison changes behavior. Ask the user.

## 3. Idiom used for layout

**Why it breaks.** With iPhone Duo and resizable iPhone Mirroring, an iPhone
app can have any combination of size classes. On the inner display the app
should look like a natural extension of its iPad layout.

**Find.** `userInterfaceIdiom`, `UI_USER_INTERFACE_IDIOM()`,
`UIUserInterfaceIdiomPad`, app helpers named `isPad` / `isPhone`.

```swift
// Before
if UIDevice.current.userInterfaceIdiom == .pad { useTwoColumns() } else { useOneColumn() }

// After
if traitCollection.horizontalSizeClass == .regular { useTwoColumns() } else { useOneColumn() }
```

```swift
// SwiftUI before
if UIDevice.current.userInterfaceIdiom == .pad { ... }

// SwiftUI after
@Environment(\.horizontalSizeClass) private var hSize
if hSize == .regular { ... }
```

When the idiom is genuinely needed (an iPad-only feature, pointer behavior),
read it from the local trait collection, never from `UIDevice`:

```swift
let idiom = traitCollection.userInterfaceIdiom
```

Gotcha: an app-defined `isPad` helper is often used for three different
questions (space, feature availability, analytics). Classify each call site;
do not replace the helper wholesale.

## 4. Size class treated as "iPad"

**Why it breaks.** Code that shows an iPad-only layout when
`horizontalSizeClass == .regular`, or assumes iPhone is always compact, now
runs that layout on iPhone Duo's inner display, which is regular in both
dimensions.

What to check for every regular-width branch:

- It does not also assume a minimum width (for example, three columns that
  need 1024 pt). Check with the resizable simulator at the smallest regular
  width.
- It does not reach for iPad-only features (`UIPointerInteraction` is fine;
  hard-coded popover anchors that assume a 1024-pt window are not).
- It is a visual continuation of the compact layout. The HIG asks that the
  app keep function and state identical across displays and add at most one
  level of hierarchy on the inner display.
- `UISplitViewController` / `NavigationSplitView` collapse to one column on
  the outer display and expand on the inner display. That is the model.

## 5. Hard-coded device sizes

**Find.** `bounds.height == 844`, `CGSize(width: 390, height: 844)`, arrays of
known iPhone sizes, `if screenHeight < 700`.

Delete the branch and lay out from available space. If the branch picks a font
or spacing tier, drive it from size class or from the bounds the view has.

## 6. Full-bleed media

**Why it breaks.** `.scaleAspectFill` / `.aspectRatio(contentMode: .fill)` on
hero images and video crops heavily when the window gets wide and short (inner
display landscape, or the outer display with a vertical bar).

```swift
// UIKit: choose per size class
imageView.contentMode = traitCollection.horizontalSizeClass == .regular ? .scaleAspectFit : .scaleAspectFill

// Or by aspect ratio of the available box vs the image
let boxAspect = bounds.width / bounds.height
let imageAspect = image.size.width / image.size.height
imageView.contentMode = abs(boxAspect - imageAspect) > 0.6 ? .scaleAspectFit : .scaleAspectFill
```

```swift
// SwiftUI
Image(hero)
    .resizable()
    .aspectRatio(contentMode: hSize == .regular ? .fit : .fill)
```

For video use `AVLayerVideoGravity.resizeAspect` on wide windows, or keep
`resizeAspectFill` and set a focal point so the subject stays visible.

## 7. Safe areas

**Why it breaks.** On iPhone Duo the safe area is asymmetric: a vertical bar
on one side (observed in the simulator as an 84 pt trailing inset with a 0 pt
leading inset), a camera on one edge, and a status bar on the side. Any code
that mirrors one inset to the other, or hard-codes 20/44/47/59 pt status-bar
and navigation-bar offsets, is wrong.

```swift
// Before
let width = view.bounds.width - view.safeAreaInsets.left * 2

// After
let contentFrame = view.bounds.inset(by: view.safeAreaInsets)
let width = contentFrame.width
```

- Replace `topLayoutGuide` / `bottomLayoutGuide` with `view.safeAreaLayoutGuide`.
- Constrain interactive content to `safeAreaLayoutGuide`; let backgrounds
  extend to the superview edges.
- Never store an inset. Re-read in `layoutSubviews` /
  `viewSafeAreaInsetsDidChange()`.
- Keyboard: `view.keyboardLayoutGuide`, not frame notifications.
- SwiftUI: content respects safe areas by default. Use `ignoresSafeArea()`
  only on backgrounds, scoped with `edges:`. Read insets from
  `GeometryProxy.safeAreaInsets`. Replace hard-coded `.padding(.top, 47)`
  with the default safe-area behavior.
- `safeAreaInsets` is physical (`left` / `right`); `safeAreaLayoutGuide` and
  `directionalLayoutMargins` resolve for right-to-left. On Duo the vertical bar
  stays on the hardware side even in RTL, so use the layout guide, not
  hand-mirrored insets.

## 8. Lifecycle

`UIWindow(windowScene:)`, `effectiveGeometry`, and
`didUpdateEffectiveGeometry` need a scene. If the app has `var window` on the
`AppDelegate` and no `UIApplicationSceneManifest`, the migration is a
prerequisite. It is mechanical but touches `Info.plist`, a new
`SceneDelegate`, and every lifecycle method. Follow Apple's app-resizability
skill, `references/scene-lifecycle-task.md`, which has the 1:1 method mapping,
and ask before moving `didFinishLaunchingWithOptions` work.
