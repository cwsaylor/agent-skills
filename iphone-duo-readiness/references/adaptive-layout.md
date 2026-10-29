# Adaptive layout: size classes, the fold, the cameras, the hinge

Names checked against the iOS 27.1 SDK. Everything in "Reserved regions",
"Arrangement views", "Hinge", and "Scene accessories" is iOS 27.1 and later.

## Size classes per display

| Where | Horizontal | Vertical | Behaves like |
|---|---|---|---|
| Outer display (closed), portrait | compact | regular | Any iPhone |
| Outer display, landscape | compact | compact | Any iPhone |
| Inner display (open) | regular | regular | iPad |
| Inner display, Split View | compact or regular | regular | iPad multitasking |
| iPhone Mirroring (resizable) | any | any | A Mac window |

The HIG's rule: a compact-width layout for the outer display and a regular-width
layout for the inner display cover every pose. Do not design per pose. Let the
existing layout expand into the available space.

Prefer system containers. They already handle resizing, both displays, the fold,
and camera occlusion:

- `NavigationSplitView` / `UISplitViewController`: one column on the outer
  display, side by side on the inner display; column widths adapt as the
  device folds.
- `TabView` / `UITabBarController`: tab bar becomes vertical or, on the inner
  display, can be a sidebar with `.defaultTabBarPlacement(.sidebar)` /
  `tabBarController.sidebar.preferredPlacement = .sidebar`.
- `NavigationStack` / `UINavigationController` for bars.
- Sheets, popovers, alerts, context menus move away from the fold on their own.
- Grids: prefer an **even number of columns** so content divides cleanly at
  the fold.
- Games: change aspect ratio rather than letterbox; if you must letterbox, fill
  the padding with artwork.

## Reserved regions

Framework views avoid the fold and the cameras. Custom views (canvases, players,
games, full-screen readers) must ask. Two kinds:

- **Division**: the fold. Active only while the device is partially open; when
  flat it is inactive with zero width (still reported with `.includeInactive`).
- **Occlusion**: hardware over the display. The outer camera is always active.
  The inner camera is active only while capturing; the UI moves aside when it
  turns on.

Each region has a `frame` (in the queried view's coordinate space), margins for
interactive content, and `isActive`.

SwiftUI:

```swift
GeometryReader { proxy in
    let folds = proxy.reservedRegions(kind: .division)
    let cutouts = proxy.reservedRegions(kind: .occlusion)
    let allFolds = proxy.reservedRegions(kind: .division, options: [.includeInactive])

    if let fold = folds.first {
        HStack(spacing: 0) {
            LeftPage().frame(width: fold.frame.minX)
            Spacer().frame(width: fold.frame.width)
            RightPage()
        }
    } else {
        SinglePage()
    }
}
```

`reservedRegions(kind:options:layoutDirectionBehavior:)` also takes a
`LayoutDirectionBehavior`; the default is fine for most views.

UIKit:

```swift
override func layoutSubviews() {
    super.layoutSubviews()
    let folds = reservedRegions(kind: .division)
    let frames = folds.map(\.frame)
    // position subviews around frames
}
```

Objective-C: `-[UIView reservedRegionsOfKind:]` and
`-reservedRegionsOfKind:options:` with `UIViewReservedRegionKind`.

Gotchas (observed in the simulator):

- Regions arrive after the first layout pass. Read them in `GeometryReader` /
  `layoutSubviews`; never cache them.
- Use the inactive division region to choose an even column count for a grid
  so the gutter lands on the fold when the user folds the device.
- Reserved regions describe layout. Use them, not the hinge angle, to decide
  where content goes.

## Arrangement views

`ArrangementView` (SwiftUI) and `UIArrangementViewController` (UIKit) hold a
**primary** and a **secondary** view and re-flow them by size, orientation, and
reserved regions.

| Style | Wider than tall | Taller than wide | Partially folded |
|---|---|---|---|
| `.split` | Side by side | Stacked, primary on top | Each view on its own side of the fold |
| `.overlay` | Primary on top of secondary | Same | Primary moves to the trailing / bottom region, secondary to the leading / top |

Use `.split` where the layout already resembles an `HStack` / `VStack` pair
(list and detail, player and up-next, canvas and inspector). Use `.overlay`
where it resembles a `ZStack` (map with a results panel, video with a
transcript). Keep navigation containers *outside* the arrangement view, and do
not put an arrangement view inside a list, scroll view, or navigation split
view where part of it could become unreachable.

SwiftUI:

```swift
NavigationStack {
    ArrangementView {
        PlayerView()
    } secondary: {
        UpNextView()
    }
    .arrangementViewStyle(.split.axes(.horizontal))   // or .split, .overlay
}
```

Overlay: read the z-index from a *subview* of the content (the root always
reads 0) to collapse the floating view:

```swift
struct UpNextView: View {
    @Environment(\.overlayArrangementZIndex) private var zIndex
    var body: some View {
        UpNextList(collapsed: zIndex > 0)
    }
}
```

`overlayArrangementEdge(_:)` picks which edge the primary view docks to.

UIKit:

```swift
let arrangementVC = UIArrangementViewController()
arrangementVC.setViewController(PlayerViewController(), for: .primary)
arrangementVC.setViewController(UpNextViewController(), for: .secondary)
arrangementVC.updateArrangement(.split.axes(.horizontal), animated: true)
let nav = UINavigationController(rootViewController: arrangementVC)

let primaryState = arrangementVC.state(for: .primary)
model.collapsed = (primaryState?.zIndex ?? 0) > 0
```

Arrangements are `UISplitArrangement` and `UIOverlayArrangement`.

## Hinge

For interactions and effects (a pitch bend, a parallax, a page-turn), **not**
layout. Layout should come from reserved regions and arrangement views, which
update when the fold becomes active or inactive rather than on every degree.

SwiftUI:

```swift
GuitarView(pitchBend: pitchBend)
    .onHingeChange { _, context in
        if let hinge = context.hinge, hinge.status == .partiallyOpen {
            pitchBend = calculatePitchBend(angle: hinge.angle)   // SwiftUI Angle; 180° when flat
        } else {
            pitchBend = 0
        }
    }
```

`onHingeChange(isEnabled:_:)` takes an `isEnabled` flag to pause delivery.
`context.hinge` is `DeviceHinge?` and is `nil` on devices without a hinge.
`status` is `.closed`, `.partiallyOpen`, or `.fullyOpen`. Do not depend on the
timing or frequency of updates; if only posture matters, read `status`.

UIKit:

```swift
let interaction = UIHingeInteraction { interaction, update in
    guard let hinge = update.hinge else { return }
    self.apply(angle: hinge.angle, status: hinge.status)
}
view.addInteraction(interaction)
interaction.isEnabled = false   // pause; the handler is called with the latest state on re-enable
```

## Scene accessories and cameras

When the device is fully open and the app captures with the rear camera, it
can show content on the **outer** display while running on the inner one (a
viewfinder, a teleprompter, a countdown):

```swift
CameraView(model: model)
    .sceneAccessory {
        CameraCaptureAccessory(isEnabled: $model.isEnabled) {
            TeleprompterView(model: model)
        }
        .onAvailabilityChange { available in
            model.isAvailable = available
        }
    }
```

The accessory is unavailable when folded. Gate the toggle on availability.

The device has an outer camera, an inner camera, and the rear camera. When the
device opens, closes, or rotates, the app may switch displays and the camera
may point the other way. Pick cameras by the direction they face
(AVFoundation / AVKit "Choosing a camera by the direction it faces"), not by
index or by assuming one front camera.

## Multiple scenes and Split View

- Split View on the inner display gives each app half the display, with the
  vertical bar on the app's outer edge. Test both sides; content laid out for a
  bar on the trailing edge must also work with the bar leading.
- If the app supports multiple windows, keep `UIApplicationSupportsMultipleScenes`
  and let the system hide `UIWindowSceneActivationAction` when new windows are
  unavailable.
- Scenes can move between displays. Nothing display-specific may be cached
  (scale, bounds, screen).
