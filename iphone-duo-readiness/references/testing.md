# Testing resizing

Apple's three tools, highest fidelity first. The iPhone Duo simulator is the
only one that shows the full native experience (vertical bars, fold, cameras,
poses).

## 1. iPhone Duo simulator (Xcode 27.1, Device Hub)

```bash
xcrun simctl list devicetypes | grep -i duo          # com.apple.CoreSimulator.SimDeviceType.iPhone-Duo
xcrun simctl list devices available | grep -i duo    # existing devices and UDIDs
xcrun simctl create "iPhone Duo" \
    com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
    com.apple.CoreSimulator.SimRuntime.iOS-27-1       # if none exists
xcrun simctl boot "iPhone Duo"
open -a Simulator
xcodebuild -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone Duo' build
xcrun simctl install booted <path/to/App.app>
xcrun simctl launch booted <bundle.id>
```

In Device Hub, the control strip at the bottom of the simulated device opens,
closes, rotates, and folds it. Walk this matrix and screenshot each cell
(`xcrun simctl io booted screenshot duo-<pose>.png`):

| Pose | Display | Check |
|---|---|---|
| Closed, portrait | Outer | Vertical bar on the camera side; nothing under the camera; compact layout identical in function to before |
| Closed, landscape | Outer | Compact-compact; vertical bar; full-bleed media not cropped badly |
| Open, portrait | Inner | Horizontal bars; regular-regular layout; split views show both columns |
| Open, landscape | Inner | Vertical bar; content fills to the edge; nothing assumes the bar is trailing |
| Partially folded (book) | Inner | Alerts and sheets move off the fold; two-pane layouts split at the fold; nothing interactive sits on the fold |
| Propped on a table (tabletop) | Inner | Top region shows content, bottom region shows controls; media controls reachable |
| Fold → unfold → fold | Both | App stays on the same screen, state preserved, no re-launch of flows, no stale sizes |
| Inner camera on (FaceTime, capture) | Inner | Occlusion region respected; UI moves aside |
| Split View, left side | Inner | Bar on the left; layout still correct |
| Split View, right side | Inner | Bar on the right; layout still correct |
| Rotate in every pose | Both | No layout driven by device orientation |

To enter Split View in the simulator, drag the app up from the home indicator
to one side of the display, then to the other.

## 2. iPhone Mirroring on macOS 27

Mirror a real iPhone (any model running iOS 27) and resize the window to
extremes in both directions. This exercises every size-class combination
without Duo hardware. Watch for:

- Layouts that pick "iPad" at regular width and then need 1024 pt.
- Text and images that stretch rather than reflow.
- `UIScreen.main` sizing (the window stops matching the screen immediately).

## 3. iOS resizable simulator (Device Hub)

The resizable simulator drags between sizes continuously. Use it for the
general resizing bugs (1a to 1b in fix-patterns) before the Duo simulator.

## What "ready" looks like

- Same functionality and state on both displays; nothing is iPad-only or
  iPhone-only.
- No layout change is triggered by rotation alone.
- No clipped, stretched, letterboxed, or off-screen content in any cell of the
  matrix.
- Bars are vertical where the system wants them, with every item present (a
  missing item usually means it lacked a symbol).
- Nothing interactive on the fold or under a camera.
- Fold and unfold keep the user's place.

## Automated checks

- A UI test that runs on the iPhone Duo simulator can assert layout after
  rotation with `XCUIDevice.shared.orientation`; pose changes are not yet
  scriptable, so keep a manual pass for folding.
- Add `scan.sh` to CI and fail on new hits in categories A, B, C, E, F, G.
  Categories D, H, I, J, L need a human read.
