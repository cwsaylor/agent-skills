# Vertical bars (iOS 27.1 SDK)

All names below were checked against the iOS 27.1 SDK (`UIKit` headers and the
`SwiftUI` / `SwiftUICore` Swift interfaces). Availability is iOS 27.1 unless
noted. Gate with `if #available(iOS 27.1, *)` when the deployment target is
lower.

## What the system does

When an app is built with the iOS 27.1 SDK, the status bar, Dynamic Island,
navigation controls, toolbar, and tab bar share one **vertical bar** on the side
of the display:

- Outer display (closed): always vertical, on the camera side. The bar keeps
  the same side in right-to-left languages because it tracks the hardware.
- Inner display, landscape: vertical, so controls stay where they were when the
  device opened.
- Inner display, portrait: enough vertical space, so bars stay horizontal.
- Split View multitasking: each app puts its bar on its own outer edge, so the
  left app has its bar on the left. Your content must work with the bar on
  either side.
- Inspectors: horizontal. Split views: horizontal for sidebar and content
  columns, vertical for the detail column.
- Sheets: vertical by default on the outer display; on the inner display,
  horizontal for centered or leading placement and vertical for trailing
  placement.

Items overflow from bottom to top. Flexible spacers are zero size in a vertical
bar; fixed spacers keep their minimum. Vertical bars have no scroll-edge effect
by default but gain a background under Reduce Transparency.

## Opt-in requirements

1. Build with the iOS 27.1 SDK.
2. Use bars that a navigation container owns:
   - SwiftUI: `.toolbar { }` on a view inside `NavigationStack`,
     `NavigationSplitView`, or `TabView`.
   - UIKit: `navigationItem` / `toolbarItems` on a view controller inside a
     `UINavigationController`, tabs in a `UITabBarController`.
   - Content from a hand-built `UIToolbar`, `UINavigationBar`, or `UITabBar`
     is **not** considered. Replace it or accept horizontal bars.
3. Give every item a symbol **and** a title:
   - Vertical presentation shows the icon.
   - Horizontal presentation shows icon or title, preferring the icon.
   - Overflow shows both.
   - Title-only items and custom-view items are never shown vertically unless
     you opt them in with `axisBehavior`.

## API table

| Purpose | SwiftUI | UIKit |
|---|---|---|
| Back / Close at the top | `ToolbarItem(placement: .cancellationAction)` | `navigationItem.leadingItemGroups`, `leftItemsSupplementBackButton = false` (iOS 16) |
| Prominent action (Done) | `ToolbarItem(placement: .topBarPinnedTrailing)` (iOS 27) | `navigationItem.pinnedTrailingGroup` (iOS 16) |
| Let a custom view go vertical | `.axisBehavior(.verticalPreferred)` on the `ToolbarItem` | `UIBarButtonItem.axisBehavior = .verticalPreferred` |
| Keep an item horizontal only | `.axisBehavior(.horizontalOnly)` | `UIBarButtonItem.axisBehavior = .horizontalOnly` |
| Detect the vertical bar and its side | `@Environment(\.toolbarVerticalEdge)` → `HorizontalEdge?` (`nil` = not vertical) | `traitCollection.verticalBarEdge` → `.unspecified` / `.leading` / `.trailing` |
| Tab bar vs toolbar under compression | `.toolbarVerticalCompressionBehavior(.prefersTabBar \| .prefersToolbarItems \| .automatic)` | `navigationItem.verticalBarCompressionBehavior = .prefersTabBar \| .prefersBarItems \| .automatic` |
| Keep an item visible longer | `.visibilityPriority(.high)` (iOS 27) | `UIBarButtonItem.visibilityPriority = .high` (iOS 27) |
| Always-overflow items | `ToolbarOverflowMenu { }` (iOS 27) | `navigationItem.additionalOverflowItems = UIDeferredMenuElement(...)` (iOS 16) |
| Badge instead of text | `.badge(7)` | `item.badge = .count(7)` |
| Hero image under the bar | `.backgroundExtensionEffect()` (iOS 26) | `UIBackgroundExtensionView` (iOS 26) |
| Opt out of vertical bars | `.toolbarVerticalBehavior(.disabled)` | `override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }` |
| Sheet placement on inner display | `.presentationPlacement(_:)` (iOS 27) | `UISheetPresentationController.preferredPlacement` (iOS 27) |
| Tab bar as sidebar on inner display | `.defaultTabBarPlacement(.sidebar)` | `tabBarController.sidebar.preferredPlacement = .sidebar` (iOS 27) |

`toolbarVerticalBehavior` is read from the topmost view of a `NavigationStack`,
the selected tab of a `TabView`, or the trailing column of a
`NavigationSplitView`. Keep it consistent; do not flip it during navigation.
Inside a sheet it controls that sheet independently.

## SwiftUI examples

```swift
NavigationStack {
    MailboxList()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close", systemImage: "xmark") { dismiss() }
            }
            ToolbarItem(placement: .topBarPinnedTrailing) {
                Button("Done", systemImage: "checkmark") { save() }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Compose", systemImage: "square.and.pencil") { compose() }
                Button("Inbox", systemImage: "tray") { showInbox() }
                    .badge(unreadCount)
            }
            .visibilityPriority(.high)
            ToolbarItem {
                ProfileView()           // custom view
            }
            .axisBehavior(.verticalPreferred)
            ToolbarItem(placement: .bottomBar) {
                Slider(value: $lineWidth, in: 2...6)
                    .frame(width: 180)
            }
            .axisBehavior(.horizontalOnly)
            ToolbarOverflowMenu {
                Button("Scan", systemImage: "doc.viewfinder") { scan() }
                Button("Connect", systemImage: "link") { connect() }
            }
        }
}
```

Custom view that adapts to the bar's axis:

```swift
struct ProfileView: View {
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    var body: some View {
        let layout = verticalEdge == nil ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
        layout {
            Avatar()
            if verticalEdge == nil { Text(name) }   // drop text when narrow
        }
    }
}
```

Tab app that keeps its tabs when space is tight:

```swift
TabView {
    Tab("Library", systemImage: "photo.on.rectangle") {
        NavigationStack {
            PhotoEditor()
                .toolbarVerticalCompressionBehavior(.prefersTabBar)
        }
    }
}
```

Opt out for a bottom-heavy single screen or a tiny sheet:

```swift
.sheet(isPresented: $showsHelp) {
    HelpView()
        .toolbarVerticalBehavior(.disabled)
}
```

Deployment target below 27.1:

```swift
struct DuoBars: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbarVerticalCompressionBehavior(.prefersTabBar)
        } else {
            content
        }
    }
}
```

## UIKit examples

```swift
// Placement
navigationItem.leftItemsSupplementBackButton = false
navigationItem.leadingItemGroups = [UIBarButtonItemGroup(barButtonItems: [closeItem], representativeItem: nil)]
navigationItem.pinnedTrailingGroup = UIBarButtonItemGroup(barButtonItems: [doneItem], representativeItem: nil)

// Axis
let profile = UIBarButtonItem(customView: ProfileView())
profile.axisBehavior = .verticalPreferred
let slider = UIBarButtonItem(customView: sliderView)
slider.axisBehavior = .horizontalOnly

// Priority, badge, overflow
composeItem.visibilityPriority = .high
inboxItem.badge = .count(unread)
navigationItem.additionalOverflowItems = UIDeferredMenuElement { provider in
    provider(self.persistentOverflowItems())
}

// Compression
navigationItem.verticalBarCompressionBehavior = .prefersBarItems

// Detect
switch traitCollection.verticalBarEdge {
case .leading:  layoutForBar(on: .leading)
case .trailing: layoutForBar(on: .trailing)
default:        layoutHorizontal()
}

// Opt out
override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }
```

`verticalBarEdge` is a trait, so automatic trait tracking re-runs
`layoutSubviews` / `updateConstraints` when it changes. Register with
`registerForTraitChanges` elsewhere.

## Review checklist for an existing toolbar

- [ ] Bars come from a navigation container, not a hand-built `UIToolbar` /
      `UITabBar` / `UINavigationBar`.
- [ ] Every item has a symbol and a title (title-only items are the most
      common reason an item is missing from the vertical bar).
- [ ] Top-of-bar order: Back/Close, then Done-type actions, then the rest.
- [ ] No manual spacing items or hard-coded gaps. Use groups.
- [ ] Custom views either fit a fixed narrow width or read the edge and adapt.
- [ ] Text-and-symbol pairs replaced with badges where the text was a count.
- [ ] Ellipsis symbol reserved for the system overflow menu; other menus use
      distinct symbols.
- [ ] Frequently used actions and badged items have higher visibility
      priority.
- [ ] Controls sit near the content they act on (for a split view, the list's
      actions stay above the list column).
- [ ] Hero or background artwork extends under the bar.
- [ ] Opt-out used only where the HIG allows (bottom-heavy single screens such
      as Calculator, or sheets with a lone Close button).
