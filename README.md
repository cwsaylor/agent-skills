# agent-skills

Agent skills for [Claude Code](https://claude.com/claude-code) focused on iOS app modernization. Each skill is a folder containing a `SKILL.md` with frontmatter (`name`, `description`) that Claude reads to decide when the skill applies, plus supporting reference files and scripts.

## Skills

| Skill | Use it when |
|-------|-------------|
| [`iphone-duo-readiness`](iphone-duo-readiness/) | You want to audit, prepare, or optimize an app for iPhone Duo (Apple's foldable iPhone) end to end: scan, fix, adopt vertical bars, lay out around the fold, test in the simulator, and submit App Store screenshots. |
| [`app-resizability`](app-resizability/) | You want targeted, API-by-API modernization of a UIKit codebase so it behaves correctly in resizable windows: Split View, Stage Manager, iPhone Mirroring, and iPhone Duo. |

The two overlap on purpose. `iphone-duo-readiness` is the broad "get my app ready for the foldable iPhone" workflow and covers SwiftUI as well as UIKit. `app-resizability` is a stricter, surgical tool that replaces specific deprecated APIs with precise rules about what may and may not change in a diff.

### iphone-duo-readiness

Based on Apple's "Three steps to make your app shine on iPhone Duo", the iPhone Duo technology overview, the Human Interface Guidelines, and the iPhone Duo Tech Talks. API names were checked against the iOS 27.1 SDK.

Workflow:

0. **Baseline.** Confirm Xcode 27.1+, record the deployment target, and report (without changing) `Info.plist` keys that block resizing.
1. **Scan.** Run `scripts/scan.sh` to grep Swift and Objective-C sources for resizability anti-patterns, grouped by category.
2. **Fix.** Apply the patterns in `references/fix-patterns.md` for both UIKit and SwiftUI.
3. **Vertical bars.** Adopt the iOS 27.1 vertical toolbars and tab bars (`references/vertical-bars.md`).
4. **Fold and cameras.** Optionally lay out around reserved regions, arrangement views, and the hinge (`references/adaptive-layout.md`).
5. **Test.** Exercise resizing in the iPhone Duo simulator and other tools (`references/testing.md`).
6. **App Store.** Prepare iPhone Duo screenshots and previews (`references/app-store.md`).

The scanner can also be run on its own:

```bash
bash ~/.claude/skills/iphone-duo-readiness/scripts/scan.sh [path] [--include-pods]
```

Hits are leads, not verdicts. Read the surrounding code before changing anything.

### app-resizability

Performs specific, targeted modernizations in Swift and Objective-C. Each task has its own reference file with the detection patterns, replacement rules, and gotchas:

| Task | Reference | Replaces |
|------|-----------|----------|
| UIScreen.main | `references/uiscreen-task.md` | `UIScreen.main` / `mainScreen` with trait-collection and window-scene values |
| Orientation | `references/orientation-task.md` | Layout branches on `interfaceOrientation` with size classes or window bounds |
| Idiom | `references/idiom-task.md` | Layout branches on `userInterfaceIdiom` with size classes |
| Safe area | `references/safe-area-task.md` | `topLayoutGuide`, `bottomLayoutGuide`, and hard-coded bar heights with safe area references that tolerate asymmetric, changing insets |
| Scene lifecycle | `references/scene-lifecycle-task.md` | `UIApplicationDelegate` lifecycle with `UISceneDelegate` |

The skill enforces a strict set of principles: never substitute literals for dynamic values, never walk global state like `UIApplication.shared` as a replacement, preserve control flow and unrelated guards, stay in scope with no opportunistic cleanup, and never leave a silent empty diff for a file that contains the target API.

## Installation

Copy (or symlink) a skill folder into your Claude Code skills directory.

User-wide, available in every project:

```bash
cp -R iphone-duo-readiness app-resizability ~/.claude/skills/
```

Per project:

```bash
cp -R iphone-duo-readiness app-resizability /path/to/project/.claude/skills/
```

`iphone-duo-readiness` references its scanner at `~/.claude/skills/iphone-duo-readiness/scripts/scan.sh`, so the user-wide install is the one that works without edits.

## Usage

Skills trigger automatically from the request. Any of these will do:

- "Get my app ready for iPhone Duo"
- "Make this app resize properly"
- "Fix the `UIScreen.main` usages in this target"
- "Migrate this AppDelegate to a SceneDelegate"
- "Adopt the vertical tab bar on iOS 27.1"

You can also invoke one directly with `/iphone-duo-readiness` or `/app-resizability`.

## Layout

```
agent-skills/
├── app-resizability/
│   ├── SKILL.md
│   └── references/
│       ├── idiom-task.md
│       ├── orientation-task.md
│       ├── safe-area-task.md
│       ├── scene-lifecycle-task.md
│       └── uiscreen-task.md
└── iphone-duo-readiness/
    ├── SKILL.md
    ├── references/
    │   ├── adaptive-layout.md
    │   ├── app-store.md
    │   ├── fix-patterns.md
    │   ├── testing.md
    │   └── vertical-bars.md
    └── scripts/
        └── scan.sh
```
