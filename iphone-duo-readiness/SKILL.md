---
name: iphone-duo-readiness
description: "Prepare, audit, or optimize an iOS app for iPhone Duo (Apple's foldable iPhone) and for resizable windows generally. Use when asked to get an app ready for iPhone Duo or the foldable iPhone, make an app resize correctly, fix layouts that break when the device folds or unfolds or in iPhone Mirroring, adopt the iOS 27.1 vertical toolbars and tab bars, lay out around the fold (reserved regions, ArrangementView, hinge), test in the iPhone Duo simulator, or submit iPhone Duo screenshots to the App Store. Covers SwiftUI and UIKit, Swift and Objective-C."
---

# iPhone Duo readiness

Based on Apple's "Three steps to make your app shine on iPhone Duo"
(developer.apple.com/iphone-duo/prepare), the technology overview "Preparing your
app for iPhone Duo", the Human Interface Guidelines "Designing for iPhone Duo",
and the iPhone Duo Tech Talks. Every API named in this skill was checked against
the iOS 27.1 SDK headers and Swift interfaces.

## What iPhone Duo changes

iPhone Duo has a compact **outer display** (behaves like a normal iPhone, compact
width) and a large **inner display** (regular width *and* regular height, like an
iPad). Both displays have a front camera. When the device opens, closes, folds
partway, or rotates, the app's window **changes size while it runs** and may move
between displays. The outer display is always occluded by a camera; the inner
camera occludes only while active; the fold divides the inner display when the
device is partially open.

Three facts drive every fix in this skill:

1. **The window is not the screen.** Anything sized from `UIScreen.main` is wrong.
2. **Orientation does not describe the window.** The inner display ignores
   supported interface orientations. Only size classes and bounds are reliable.
3. **Idiom is not layout.** An iPhone app can now have any combination of size
   classes. `userInterfaceIdiom == .pad` and `horizontalSizeClass == .regular`
   no longer mean "iPad".

What the user sees depends on the SDK the app was built with:

| Built with | Inner display (open) | Outer display (closed) |
|---|---|---|
| iOS 26 SDK or earlier | Letterboxed in the center, empty space around | Content left of the status bar and camera |
| iOS 27 SDK | Fills most of the display, still avoids the status bar on the right edge | Same as above |
| iOS 27.1 SDK or later | Full display. Toolbars and tab bars become **vertical** below the status bar | Vertical bars on the side; status bar and Dynamic Island on the side |

Starting **April 2027**, every app submitted with the iOS 27.1 SDK or later must
include iPhone Duo screenshots. Submitting them earlier earns an "optimized for
iPhone Duo" badge on the product page.

## Workflow

Run the steps in order. For a request scoped to one thing ("fix the vertical
toolbar", "add Duo screenshots"), jump to that step and skip the rest.

### Step 0: Establish the baseline

- Confirm Xcode 27.1 or later: `xcodebuild -version`. Earlier Xcode cannot build
  with the 27.1 SDK or run the iPhone Duo simulator.
- Record the iOS deployment target. Every API marked 27.1 in this skill needs
  `if #available(iOS 27.1, *)` gating when the target is lower. For SwiftUI
  modifiers, gate inside a `ViewModifier` or a `toolbar` builder branch.
- Read `Info.plist` and build settings (`INFOPLIST_KEY_*` in the project file and
  any `.xcconfig`). Report, but do not change, these keys:
  - `UIRequiresFullScreen`: see TN3192. Removing it makes the app resizable at
    once, so it comes out only after the layouts are fixed and tested.
  - `UISupportedInterfaceOrientations~ipad` missing any orientation.
  - No `UIApplicationSceneManifest`: the app still uses the application
    lifecycle. Scene-based windows are required for `UIWindow(windowScene:)`.
  - No launch screen key (`UILaunchScreen`, `UILaunchStoryboardName`, or
    `INFOPLIST_KEY_UILaunchScreen_Generation`): iOS 27 rejects the upload.

### Step 1: Scan for the patterns

Run the bundled scanner from the project root:

```bash
bash ~/.claude/skills/iphone-duo-readiness/scripts/scan.sh [path] [--include-pods]
```

It greps Swift and Objective-C sources, plus `Info.plist` and the project file,
and groups hits by category (main screen, orientation, idiom, size-class-as-device,
hard-coded device sizes, fixed-frame windows, stored screens, full-bleed media,
legacy safe-area guides, custom bars, device-model sniffing). Hits are leads, not
verdicts. Read the surrounding code before changing anything.

For a deep UIKit API-migration pass with strict per-file rules (Objective-C and
Swift, including `AppDelegate` to `SceneDelegate`), Apple ships its own
**app-resizability** skill in Xcode 27.1. Export it with:

```bash
xcrun agent skills export
```

It is also installed at `~/.claude/skills/app-resizability/` on this machine.
Use it when the request is "migrate every deprecated API"; use this skill for
the end-to-end Duo checklist, SwiftUI, vertical bars, fold-aware layout, testing,
and App Store steps. Apple says its skill finds most issues but not all, so
still review the full pattern list below.

### Step 2: Fix the patterns

Details, before/after code for UIKit and SwiftUI, and gotchas are in
[references/fix-patterns.md](references/fix-patterns.md). Summary:

| Pattern | Replace with |
|---|---|
| `UIScreen.main.bounds` | `view.bounds`, `window.bounds`, or scene bounds. SwiftUI: `GeometryReader` or `onGeometryChange` |
| Size read once at launch or in `viewIsAppearing` | Re-read in `layoutSubviews` / `viewDidLayoutSubviews`; use `viewWillTransition(to:with:)` for size-change work |
| `UIScreen.main.scale` | `traitCollection.displayScale`; SwiftUI `@Environment(\.displayScale)` |
| `UIWindow(frame: UIScreen.main.bounds)` | `UIWindow(windowScene:)` |
| Stored `UIScreen` property | Read `view.window?.windowScene?.screen` when needed |
| `UIDevice.current.orientation`, `statusBarOrientation`, `interfaceOrientation`, `effectiveGeometry.interfaceOrientation` for layout | Compare width and height of `view.bounds` / `superview.bounds` / `GeometryReader` size, or use size classes |
| `userInterfaceIdiom == .phone` / `.pad` for layout | Size classes or available space |
| `horizontalSizeClass == .regular` meaning "iPad" | Accept that iPhone can be regular; make the regular layout a natural extension of the compact one |
| `bounds.height == 844`, lists of known iPhone sizes | Delete. Lay out from available space |
| `.scaleAspectFill` / `.aspectRatio(contentMode: .fill)` hero media | Choose fill vs fit from size class or aspect ratio, or set a focal point |
| Symmetric safe-area math (`insets.left * 2`) | Treat each edge independently; `bounds.inset(by: safeAreaInsets)` |
| `topLayoutGuide` / `bottomLayoutGuide`, hard-coded status-bar offsets | `safeAreaLayoutGuide`, `safeAreaInsets`, `keyboardLayoutGuide` |

Rules while editing:

- Never replace a dynamic value with a literal.
- Preserve control flow and unrelated guards (`#available`, nil checks).
- Change only the lines that carry the pattern. No drive-by cleanup.
- When two replacements are both valid and change behavior differently (for
  example, orientation used for left-versus-right, not for shape), ask the user.
  If running non-interactively, leave an actionable `// TODO:` on its own line.
- Never produce an empty result for a file that contains a pattern. Fix it,
  or say why you did not.

### Step 3: Adapt to vertical bars (iOS 27.1 SDK)

Building with the 27.1 SDK moves navigation bars, toolbars, and tab bars to the
side on the outer display and on the inner display in landscape. This only
works for bars owned by `NavigationStack` / `NavigationSplitView` / `TabView`
in SwiftUI and `UINavigationController` / `UITabBarController` in UIKit.
Hand-built `UIToolbar`, `UITabBar`, and `UINavigationBar` are ignored.

Checklist:

- Every toolbar item has **both a symbol and a title**. Title-only items and
  custom-view items never go vertical.
- Back/Close at the top (`.cancellationAction` / `leadingItemGroups`), then
  prominent actions (`.topBarPinnedTrailing` / `pinnedTrailingGroup`).
- Custom views read `@Environment(\.toolbarVerticalEdge)` (SwiftUI) or
  `traitCollection.verticalBarEdge` (UIKit) and provide a narrow layout, or set
  `axisBehavior(.horizontalOnly)`.
- Replace manual spacers with groups. Flexible spacers are zero-size vertically.
- Pick a compression preference for tab apps:
  `toolbarVerticalCompressionBehavior(.prefersTabBar | .prefersToolbarItems)`.
- Hero or background images extend under the bar with
  `backgroundExtensionEffect()` / `UIBackgroundExtensionView`.
- Opt out only for bottom-heavy single screens or tiny sheets:
  `toolbarVerticalBehavior(.disabled)` / `preferredVerticalBarBehavior = .disabled`.

Full API table with verified names and code: [references/vertical-bars.md](references/vertical-bars.md).

### Step 4: Lay out around the fold and the cameras (optional, "go further")

Only needed when the app has custom layouts, two-pane screens, media players,
games, or camera capture. System containers (split views, tab views, sheets,
alerts, context menus) already avoid the fold and cameras.

- **Reserved regions**: `GeometryProxy.reservedRegions(kind: .division | .occlusion)`
  in SwiftUI, `view.reservedRegions(kind:)` in UIKit. Pass `.includeInactive`
  to see the fold while flat (for example, to pick an even column count).
- **ArrangementView / UIArrangementViewController**: a two-view container with
  `.split` and `.overlay` styles that re-flows across poses. Keep navigation
  containers outside it.
- **Hinge**: `onHingeChange` / `UIHingeInteraction` for effects and
  interactions only, never layout.
- **Camera**: `sceneAccessory { CameraCaptureAccessory(...) }` shows content on
  the outer display while capturing on the inner one.
- **Sheets**: `presentationPlacement(_:)` / `UISheetPresentationController.preferredPlacement`.

Details and code: [references/adaptive-layout.md](references/adaptive-layout.md).

### Step 5: Test resizing

Use all three, in this order of fidelity:

1. **iPhone Duo simulator in Xcode 27.1 (Device Hub)**: open, close, fold, and
   rotate with the pose controls; test Split View multitasking on both sides.
2. **iPhone Mirroring on macOS 27**: drag the window to extreme sizes in both
   directions.
3. **iOS resizable simulator in Device Hub**.

The per-pose checklist, `simctl` commands, and what to look for are in
[references/testing.md](references/testing.md).

### Step 6: App Store

Submit iPhone Duo screenshots (outer 1398×2034, inner 2007×2853, plus
landscape) to get the badge now and to meet the April 2027 requirement; preview
assets with the App Store Connect preview tool; nominate the app for featuring
and state Duo support, including all device poses. Details:
[references/app-store.md](references/app-store.md).

## Reporting

When finishing an audit or a fix pass, give the user:

1. Baseline: Xcode and SDK version, deployment target, plist findings.
2. Per category: files changed, with the one-line rule applied to each.
3. Anything left as a TODO or a question, with the reason.
4. The exact poses and tools still to be tested, if testing was not done.

Keep the write-up short. A reviewer should be able to verify each change from
the file and line alone.
