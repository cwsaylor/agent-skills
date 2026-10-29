#!/usr/bin/env bash
# scan.sh - find iPhone Duo resizability anti-patterns in an iOS project.
#
# Usage: scan.sh [path] [--include-pods]
#
# Greps Swift and Objective-C sources for the patterns in Apple's
# "Three steps to make your app shine on iPhone Duo", then reads Info.plist
# and project build settings for keys that block resizing. Hits are leads,
# not verdicts: read the surrounding code before changing anything.

set -uo pipefail

ROOT="."
INCLUDE_PODS=0
for arg in "$@"; do
  case "$arg" in
    --include-pods) INCLUDE_PODS=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) ROOT="$arg" ;;
  esac
done

if [ ! -d "$ROOT" ]; then
  echo "error: '$ROOT' is not a directory" >&2
  exit 1
fi

EXCL=(--exclude-dir=.build --exclude-dir=DerivedData --exclude-dir=.git
      --exclude-dir=Carthage --exclude-dir=node_modules --exclude-dir=.swiftpm
      --exclude-dir=xcuserdata)
if [ "$INCLUDE_PODS" -eq 0 ]; then
  EXCL+=(--exclude-dir=Pods)
fi
SRC=(--include='*.swift' --include='*.m' --include='*.mm' --include='*.h')

TOTAL=0
declare -a SUMMARY

section() {
  # $1 = id, $2 = title, $3 = regex, $4 = advice
  local id="$1" title="$2" regex="$3" advice="$4"
  local hits
  hits=$(grep -rnE "$regex" "${SRC[@]}" "${EXCL[@]}" "$ROOT" 2>/dev/null | grep -vE '^[^:]+:[0-9]+:\s*(//|\*|/\*)' || true)
  local count=0
  if [ -n "$hits" ]; then
    count=$(printf '%s\n' "$hits" | wc -l | tr -d ' ')
  fi
  TOTAL=$((TOTAL + count))
  SUMMARY+=("$(printf '%-3s %-46s %5d' "$id" "$title" "$count")")
  echo
  echo "== [$id] $title ($count)"
  echo "   fix: $advice"
  if [ "$count" -gt 0 ]; then
    printf '%s\n' "$hits" | sed "s#^$ROOT/##" | head -200
    if [ "$count" -gt 200 ]; then
      echo "   ... $((count - 200)) more (narrow the path to see them)"
    fi
  fi
}

echo "iPhone Duo readiness scan: $ROOT"
echo "(comment-only lines are dropped; everything else needs a human read)"

section A "Main screen sizing" \
  'UIScreen\.main\b|\[UIScreen mainScreen\]|UIScreen\.screens\b|\[UIScreen screens\]' \
  'size from view/window/scene bounds; scale from traitCollection.displayScale; UIWindow(windowScene:)'

section B "Orientation used for layout" \
  'UIDevice\.current\.orientation|\[UIDevice currentDevice\]\.orientation|statusBarOrientation|\binterfaceOrientation\b|effectiveGeometry\.interfaceOrientation|orientationDidChangeNotification|UIDeviceOrientationDidChangeNotification|UIInterfaceOrientationIs(Landscape|Portrait)|UIDeviceOrientationIs(Landscape|Portrait)|\.isLandscape\b|\.isPortrait\b|didUpdateCoordinateSpace' \
  'compare width vs height of the bounds you have, or use size classes; orientation *locking* is fine, layout from orientation is not'

section C "Idiom used for layout" \
  'userInterfaceIdiom|UI_USER_INTERFACE_IDIOM\(\)|UIUserInterfaceIdiom(Pad|Phone)|isPad\b|isPhone\b|isiPad\b|isIPad\b' \
  'base layout on size classes or available space; read a genuinely-needed idiom from the local trait collection, never UIDevice'

section D "Size class treated as device (review)" \
  'horizontalSizeClass *== *\.regular|horizontalSizeClass *!= *\.compact|UIUserInterfaceSizeClassRegular|verticalSizeClass *== *\.regular' \
  'not wrong by itself: confirm the regular layout works on an iPhone-sized regular window and is an extension of the compact one'

section E "Hard-coded device dimensions" \
  '(bounds|frame|size|Size)\.(width|height) *(==|<=|>=|<|>|!=) *(320|375|390|393|402|414|428|430|440|568|667|736|812|844|852|874|896|926|932|956)(\.0)?\b|CGSize\(width: *(320|375|390|393|402|414|428|430|440)(\.0)?, *height: *(568|667|736|812|844|852|874|896|926|932|956)(\.0)?\)|CGSizeMake\((320|375|390|393|402|414|428|430|440)' \
  'delete device-size branches; lay out from available space'

section F "Fixed-frame windows" \
  'UIWindow\(frame:|\[\[UIWindow alloc\] initWithFrame:|UIWindow\(\)\.frame *=' \
  'UIWindow(windowScene:) from the scene delegate'

section G "Stored screen references" \
  '(var|let) +[A-Za-z_]+ *: *UIScreen[?!]?\b|@property[^;]*\bUIScreen *\*' \
  'do not store a UIScreen; read view.window?.windowScene?.screen when needed'

section H "Full-bleed media (review)" \
  'scaleAspectFill|contentMode: *\.fill\b|aspectRatio\([^)]*contentMode: *\.fill|resizeAspectFill|AVLayerVideoGravityResizeAspectFill|videoGravity *= *\.resizeAspectFill' \
  'hero images/video can crop badly on a wide window: choose fill vs fit from size class or aspect ratio, or set a focal point'

section I "Legacy or symmetric safe-area math" \
  'topLayoutGuide|bottomLayoutGuide|safeAreaInsets\.(left|right|top|bottom) *\* *2|statusBarFrame|statusBarManager\?*\.statusBarFrame|UIApplication\.shared\.statusBarFrame' \
  'safeAreaLayoutGuide / safeAreaInsets per edge; bounds.inset(by: safeAreaInsets); insets are asymmetric on Duo'

section J "Hand-built bars (will not go vertical on 27.1)" \
  'UIToolbar\(|\[UIToolbar alloc\]|UITabBar\(|\[UITabBar alloc\]|UINavigationBar\(|\[UINavigationBar alloc\]|: *UIToolbar\b|: *UITabBar\b|: *UINavigationBar\b' \
  'use UINavigationController / UITabBarController bars, or NavigationStack / TabView toolbar(content:) in SwiftUI'

section K "Device model sniffing" \
  'UIDevice\.current\.model|UIDevice\.current\.name|utsname\(\)|sysctlbyname\("hw\.machine"|machineIdentifier|modelIdentifier|deviceModel\b' \
  'never choose layout by hardware model; iPhone Duo will not be in your list'

section L "Application lifecycle only (review)" \
  'UIApplicationDelegate\b|didFinishLaunchingWithOptions|applicationDidBecomeActive\(|applicationWillResignActive\(|applicationDidEnterBackground\(|applicationWillEnterForeground\(' \
  'if there is no SceneDelegate / UIApplicationSceneManifest, migrate to the scene lifecycle (Apple app-resizability skill: scene-lifecycle-task.md)'

# ---------------------------------------------------------------------------
# Info.plist and build settings
# ---------------------------------------------------------------------------
echo
echo "== [P] Info.plist / build-setting keys (read-only report)"
PLISTS=$(find "$ROOT" -name 'Info.plist' -not -path '*/Pods/*' -not -path '*/DerivedData/*' -not -path '*/.build/*' -not -path '*/xcuserdata/*' 2>/dev/null)
PBX=$(find "$ROOT" -name 'project.pbxproj' -not -path '*/Pods/*' -not -path '*/DerivedData/*' 2>/dev/null)
XCC=$(find "$ROOT" -name '*.xcconfig' -not -path '*/Pods/*' -not -path '*/DerivedData/*' 2>/dev/null)
KEYS='UIRequiresFullScreen|UIRequiresFullScreenIgnoredStartingWithVersion|UISupportedInterfaceOrientations|UIApplicationSceneManifest|UILaunchScreen|UILaunchStoryboardName|UILaunchScreens|UILaunchStoryboards|UIApplicationSupportsMultipleScenes|IPHONEOS_DEPLOYMENT_TARGET|INFOPLIST_KEY_UILaunchScreen_Generation|INFOPLIST_KEY_UISupportedInterfaceOrientations|INFOPLIST_KEY_UIRequiresFullScreen|INFOPLIST_KEY_UIApplicationSceneManifest'
FOUND=0
for f in $PLISTS $PBX $XCC; do
  hits=$(grep -nE "$KEYS" "$f" 2>/dev/null | sort -u || true)
  if [ -n "$hits" ]; then
    FOUND=1
    echo "-- ${f#$ROOT/}"
    printf '%s\n' "$hits" | sed 's/^/   /' | head -40
  fi
done
[ "$FOUND" -eq 0 ] && echo "   (no relevant keys found; check that the project path is right)"
cat <<'EOF'
   what to look for:
   - UIRequiresFullScreen=YES: see TN3192; do not delete until layouts are fixed and tested
   - UISupportedInterfaceOrientations~ipad missing orientations: inner display ignores locks; iPad declaration should list all four
   - no UIApplicationSceneManifest: still on application lifecycle; UIWindow(windowScene:) needs scenes
   - no launch screen key: iOS 27 rejects upload (ITMS-90870, TN3208)
   - IPHONEOS_DEPLOYMENT_TARGET < 27.1: gate every 27.1 API with #available
EOF

# ---------------------------------------------------------------------------
echo
echo "== Summary (source hits by category)"
printf '%s\n' "${SUMMARY[@]}"
printf '%-50s %5d\n' "total" "$TOTAL"
echo
echo "Next: read references/fix-patterns.md for each non-zero category."
